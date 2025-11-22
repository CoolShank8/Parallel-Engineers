#!/usr/bin/env python3
"""
Roblox Build System - Processes model.json files to extract and sync images
from PSD layers and PNG files to local Roblox content.
"""

import os
import re
import json
import hashlib
import time
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from PIL import Image
from psd_tools import PSDImage

try:
    import rblxopencloud
    ROBLOX_CLOUD_AVAILABLE = True
except ImportError:
    ROBLOX_CLOUD_AVAILABLE = False
    rblxopencloud = None  # type: ignore

class RobloxBuildSystem:
    def __init__(self, project_root: str = ".", api_key: Optional[str] = None, user_id: Optional[str] = None):
        self.project_root = Path(project_root).resolve()
        self.roblox_artifact_path = None
        self.cache = {}
        self.cache_file = self.project_root / ".build_cache.json"
        self.roblox_user = None
        self.load_cache()
        self.init_roblox_cloud(api_key, user_id)
        
    def init_roblox_cloud(self, api_key: Optional[str] = None, user_id: Optional[str] = None):
        """Initialize Roblox Open Cloud API client."""
        if not ROBLOX_CLOUD_AVAILABLE:
            return
        
        # Try command-line args first, then environment variables
        api_key = api_key or os.environ.get('ROBLOX_API_KEY')
        user_id = user_id or os.environ.get('ROBLOX_USER_ID')
        
        if api_key and user_id:
            try:
                self.roblox_user = rblxopencloud.User(int(user_id), api_key=api_key)  # type: ignore
                print(f"✓ Roblox Cloud API initialized (User ID: {user_id})")
            except Exception as e:
                print(f"Warning: Could not initialize Roblox Cloud API: {e}")
    
    def load_cache(self):
        """Load build cache from disk."""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r') as f:
                    self.cache = json.load(f)
            except Exception as e:
                print(f"Warning: Could not load cache: {e}")
                self.cache = {}
    
    def save_cache(self):
        """Save build cache to disk."""
        try:
            with open(self.cache_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save cache: {e}")
    
    def update_properties_simple(self, original_text: str, properties: dict) -> str:
        """Simple property update for single-element JSON files (hierarchical mode).
        
        Updates Image/ImageContent properties directly without needing to search by Name.
        Used for hierarchical files where each file contains just one element.
        """
        text = original_text
        
        for prop_name, new_value in properties.items():
            if prop_name not in ['Image', 'ImageContent']:
                continue
            
            # Try to update existing property
            pattern = rf'("{re.escape(prop_name)}"\s*:\s*)"([^"]*)"'
            if re.search(pattern, text):
                text = re.sub(pattern, lambda m: f'{m.group(1)}"{new_value}"', text, count=1)
            else:
                # Property doesn't exist - add it to the properties section
                # Find the properties object
                props_match = re.search(r'"properties"\s*:\s*\{', text)
                if props_match:
                    insert_pos = props_match.end()
                    # Find indentation of next line
                    next_newline = text.find('\n', insert_pos)
                    if next_newline != -1:
                        next_line_start = next_newline + 1
                        next_line_end = text.find('\n', next_line_start)
                        if next_line_end != -1:
                            indent_match = re.match(r'(\s+)', text[next_line_start:next_line_end])
                            if indent_match:
                                indent = indent_match.group(1)
                            else:
                                indent = '    '
                        else:
                            indent = '    '
                    else:
                        indent = '    '
                    
                    # Add the property
                    insertion = f'\n{indent}"{prop_name}": "{new_value}",'
                    text = text[:insert_pos] + insertion + text[insert_pos:]
                else:
                    # No properties object - create one
                    # Find the closing brace of the root object
                    last_brace = text.rfind('}')
                    if last_brace != -1:
                        insertion = f',\n  "properties": {{\n    "{prop_name}": "{new_value}"\n  }}'
                        text = text[:last_brace] + insertion + '\n' + text[last_brace:]
        
        return text
    
    def update_properties_surgical(self, original_text: str, updated_data: dict) -> str:
        """Surgically update Image/ImageContent properties while preserving original formatting.
        
        This function updates properties node-by-node to avoid overwriting the wrong elements
        when multiple nodes have the same property names.
        """
        text = original_text
        
        def find_node_in_text(text: str, node_name: str, start_pos: int = 0) -> tuple:
            """Find a node by name and return (start, end) positions of its entire block."""
            # Look for: "Name": "node_name"
            name_pattern = rf'"Name"\s*:\s*"{re.escape(node_name)}"'
            match = re.search(name_pattern, text[start_pos:])
            if not match:
                return None, None
            
            name_pos = start_pos + match.start()
            
            # Find the opening brace of this node (go backwards)
            brace_pos = text.rfind('{', 0, name_pos)
            if brace_pos == -1:
                return None, None
            
            # Find the closing brace by counting nested braces
            depth = 1
            i = brace_pos + 1
            while i < len(text) and depth > 0:
                if text[i] == '{':
                    depth += 1
                elif text[i] == '}':
                    depth -= 1
                i += 1
            
            if depth == 0:
                return brace_pos, i
            return None, None
        
        def update_property_in_node_text(node_text: str, prop_name: str, new_value: str) -> str:
            """Update a property within a specific node's text."""
            # Match the property and its value: "PropName": "old_value"
            pattern = rf'("{re.escape(prop_name)}"\s*:\s*)"([^"]*)"'
            
            def replacer(match):
                return f'{match.group(1)}"{new_value}"'
            
            # Check if property exists
            if re.search(pattern, node_text):
                # Replace existing value
                return re.sub(pattern, replacer, node_text, count=1)
            else:
                # Property doesn't exist in this node
                # For ImageContent, try to add it after Image
                if prop_name == "ImageContent":
                    image_pattern = r'("Image"\s*:\s*"[^"]*")'
                    match = re.search(image_pattern, node_text)
                    if match:
                        # Insert ImageContent after Image with same indentation
                        insert_pos = match.end()
                        # Add comma and newline with same indentation as Image line
                        line_start = node_text.rfind('\n', 0, match.start()) + 1
                        indent = node_text[line_start:match.start()]
                        insertion = f',\n{indent}"ImageContent": "{new_value}"'
                        return node_text[:insert_pos] + insertion + node_text[insert_pos:]
            
            return node_text
        
        def update_node_properties(node, text):
            """Recursively update properties for each node."""
            if not isinstance(node, dict):
                return text
            
            node_name = node.get('Name')
            if not node_name:
                # No name, process children only
                if 'children' in node and isinstance(node['children'], list):
                    for child in node['children']:
                        text = update_node_properties(child, text)
                return text
            
            # Find this node in the text
            node_start, node_end = find_node_in_text(text, node_name)
            if node_start is None:
                # Node not found, skip
                if 'children' in node and isinstance(node['children'], list):
                    for child in node['children']:
                        text = update_node_properties(child, text)
                return text
            
            # Extract node text
            node_text = text[node_start:node_end]
            original_node_text = node_text
            
            # Update properties in this node
            if 'properties' in node and isinstance(node['properties'], dict):
                props = node['properties']
                if 'Image' in props:
                    node_text = update_property_in_node_text(node_text, 'Image', props['Image'])
                if 'ImageContent' in props:
                    node_text = update_property_in_node_text(node_text, 'ImageContent', props['ImageContent'])
            
            # Replace node text in the full text
            if node_text != original_node_text:
                text = text[:node_start] + node_text + text[node_end:]
                # Adjust for length change
                length_diff = len(node_text) - len(original_node_text)
                node_end += length_diff
            
            # Process children
            if 'children' in node and isinstance(node['children'], list):
                for child in node['children']:
                    text = update_node_properties(child, text)
            
            return text
        
        return update_node_properties(updated_data, text)
    
    def parse_luau_table(self, luau_content: str) -> Dict:
        """Parse a simple Lua table from .designsource.luau file.
        
        Extracts properties_sync_source and publish_images from a return statement like:
        return {
            publish_images = true,
            ["properties_sync_source"] = {
                ["Image"] = "extract(Test.png).upload(400px, 400px)",
            },
        }
        """
        result = {}
        
        # Check for publish_images flag
        publish_match = re.search(r'publish_images\s*=\s*(true|false)', luau_content)
        if publish_match:
            result['publish_images'] = publish_match.group(1) == 'true'
        
        # Find the properties_sync_source table
        sync_match = re.search(
            r'\["properties_sync_source"\]\s*=\s*\{([^}]+)\}',
            luau_content,
            re.DOTALL
        )
        
        if not sync_match:
            return result
        
        sync_content = sync_match.group(1)
        
        # Extract each property: ["PropertyName"] = "value"
        property_pattern = r'\["([^"]+)"\]\s*=\s*"([^"]+)"'
        properties = {}
        
        for match in re.finditer(property_pattern, sync_content):
            prop_name = match.group(1)
            prop_value = match.group(2)
            properties[prop_name] = prop_value
        
        result['properties_sync_source'] = properties
        return result
    
    def parse_init_designsource_luau(self, luau_content: str) -> Dict:
        """Parse init.designsource.luau with variable assignments and UI path references.
        
        Example:
        local UI = script.Parent
        local TextureSheet = extract("TextureSheet.psd")
        
        return {
            [UI.PromptFrame.PromptImage] = {
                Image = TextureSheet.layer("BG").upload(1000, 1000)
            }
        }
        """
        result = {
            'variables': {},
            'ui_mappings': {},
            'publish_images': False,
            'ui_root_var': 'UI'  # Track what variable is used for UI references
        }
        
        # Check for publish_images flag
        publish_match = re.search(r'publish_images\s*=\s*(true|false)', luau_content)
        if publish_match:
            result['publish_images'] = publish_match.group(1) == 'true'
        
        # Extract ALL variable assignments (not just extract calls)
        # This handles: local UI = script.Parent, local VarName = extract("file")
        # Strip comments first to avoid interference
        lines = []
        for line in luau_content.split('\n'):
            # Remove inline comments (but preserve strings)
            comment_pos = line.find('--')
            if comment_pos != -1:
                # Check if -- is inside a string
                in_string = None
                for i, char in enumerate(line):
                    if char in ('"', "'") and (i == 0 or line[i-1] != '\\'):
                        if in_string == char:
                            in_string = None
                        elif in_string is None:
                            in_string = char
                    if i == comment_pos and in_string is None:
                        line = line[:comment_pos]
                        break
            lines.append(line)
        
        clean_content = '\n'.join(lines)
        
        # Match variable declarations (can span lines for chained calls)
        var_pattern = r'local\s+(\w+)\s*=\s*([^\n]+)'
        for match in re.finditer(var_pattern, clean_content):
            var_name = match.group(1)
            var_value = match.group(2).strip()
            
            # Check if it's an extract call
            extract_match = re.match(r'extract\((["\'])([^"\']+)\1\)', var_value)
            if extract_match:
                source_file = extract_match.group(2)
                result['variables'][var_name] = f'extract("{source_file}")'
            elif 'script.Parent' in var_value or 'script.parent' in var_value.lower():
                # Track UI root variable
                result['ui_root_var'] = var_name
        
        # Extract UI path mappings from return table using a more robust method
        # Find the return statement block
        return_match = re.search(r'return\s*\{(.+)\}(?:\s*$)', luau_content, re.DOTALL)
        if not return_match:
            return result
        
        return_content = return_match.group(1)
        
        # Parse UI path mappings with better brace matching
        # Use a state machine to handle nested braces
        i = 0
        while i < len(return_content):
            # Look for [UI_VAR.path.to.element] pattern
            ui_key_match = re.match(r'\s*\[(\w+)\.([^\]]+)\]\s*=\s*\{', return_content[i:])
            if not ui_key_match:
                i += 1
                continue
            
            ui_var = ui_key_match.group(1)
            if ui_var != result['ui_root_var']:
                i += 1
                continue
            
            ui_path = ui_key_match.group(2)
            i += ui_key_match.end()
            
            # Now extract the properties block with proper brace matching
            brace_depth = 1
            prop_block_start = i
            in_string = None
            escape = False
            
            while i < len(return_content) and brace_depth > 0:
                char = return_content[i]
                
                if escape:
                    escape = False
                elif char == '\\':
                    escape = True
                elif in_string:
                    if char == in_string:
                        in_string = None
                elif char in ('"', "'"):
                    in_string = char
                elif char == '{':
                    brace_depth += 1
                elif char == '}':
                    brace_depth -= 1
                
                i += 1
            
            if brace_depth == 0:
                prop_block = return_content[prop_block_start:i-1]
                result['ui_mappings'][ui_path] = self.parse_property_block(prop_block)
        
        return result
    
    def parse_property_block(self, prop_block: str) -> Dict[str, str]:
        """Parse a property block from init.designsource.luau.
        
        Handles complex values with commas and method chaining.
        Example: "Image = TextureSheet.layer("BG").upload(1000, 1000)"
        """
        properties = {}
        
        # Split by lines and commas, but respect parentheses
        i = 0
        current_prop_name = None
        current_value_chars = []
        paren_depth = 0
        in_string = None
        escape = False
        
        while i < len(prop_block):
            char = prop_block[i]
            
            # Skip whitespace when looking for property name
            if current_prop_name is None and char.isspace():
                i += 1
                continue
            
            # Look for property name (support letters, underscores, numbers after first char)
            if current_prop_name is None and (char.isalpha() or char == '_'):
                # Try to match property name: word characters followed by =
                prop_match = re.match(r'([a-zA-Z_]\w*)\s*=\s*', prop_block[i:])
                if prop_match:
                    current_prop_name = prop_match.group(1)
                    i += prop_match.end()
                    current_value_chars = []
                    continue
            
            # Accumulate value
            if current_prop_name is not None:
                if escape:
                    current_value_chars.append(char)
                    escape = False
                elif char == '\\':
                    escape = True
                    current_value_chars.append(char)
                elif in_string:
                    current_value_chars.append(char)
                    if char == in_string:
                        in_string = None
                elif char in ('"', "'"):
                    in_string = char
                    current_value_chars.append(char)
                elif char == '(':
                    paren_depth += 1
                    current_value_chars.append(char)
                elif char == ')':
                    paren_depth -= 1
                    current_value_chars.append(char)
                elif char == ',' and paren_depth == 0:
                    # End of this property (comma at top level)
                    value = ''.join(current_value_chars).strip()
                    if value:
                        properties[current_prop_name] = value
                    current_prop_name = None
                    current_value_chars = []
                elif char == '\n' and paren_depth == 0:
                    # End of this property (newline at top level)
                    value = ''.join(current_value_chars).strip()
                    # Remove trailing comma if present
                    if value.endswith(','):
                        value = value[:-1].strip()
                    if value:
                        properties[current_prop_name] = value
                    current_prop_name = None
                    current_value_chars = []
                else:
                    current_value_chars.append(char)
            
            i += 1
        
        # Handle final property
        if current_prop_name and current_value_chars:
            value = ''.join(current_value_chars).strip()
            if value.endswith(','):
                value = value[:-1].strip()
            if value:
                properties[current_prop_name] = value
        
        return properties
    
    def add_source_paths_recursively(self, node: dict, source_path: str):
        """Recursively add _source_path to all nodes that don't have one."""
        if not isinstance(node, dict):
            return
        
        # Set source path if not already set
        if '_source_path' not in node:
            node['_source_path'] = source_path
        
        # Recursively process children
        if 'children' in node and isinstance(node['children'], list):
            for child in node['children']:
                self.add_source_paths_recursively(child, source_path)
    
    def normalize_node_fields(self, node: dict, folder_name: Optional[str] = None):
        """Normalize JSON node fields to support different Roblox file formats.
        
        - Adds 'Name' field from folder name if missing
        - Normalizes 'className' to 'ClassName' for consistency
        
        Args:
            node: JSON node to normalize
            folder_name: Folder name to use as default Name (optional)
        """
        if not isinstance(node, dict):
            return
        
        # Auto-derive Name from folder name if missing
        if 'Name' not in node and folder_name:
            node['Name'] = folder_name
        
        # Normalize className -> ClassName (support both formats)
        if 'className' in node and 'ClassName' not in node:
            node['ClassName'] = node['className']
        
        # Recursively normalize children
        if 'children' in node and isinstance(node['children'], list):
            for child in node['children']:
                self.normalize_node_fields(child)
    
    def build_hierarchical_tree(self, root_path: Path) -> Optional[dict]:
        """Recursively build a UI tree from init.meta.json files in folder hierarchy.
        
        Supports two modes:
        1. Single-file: All UI elements defined in one init.meta.json (assigns same source path to all nodes)
        2. Hierarchical: UI elements in separate init.meta.json files across folders (each node has its own source path)
        
        Args:
            root_path: Starting folder (e.g., WeaponInventoryUIDesign/)
        
        Returns:
            Virtual tree node with source_path tracking
        """
        # Load the root init.meta.json
        root_json_path = root_path / "init.meta.json"
        if not root_json_path.exists():
            return None
        
        with open(root_json_path, 'r', encoding='utf-8') as f:
            root_node = json.load(f)
        
        # Normalize fields (auto-derive Name from folder, normalize className)
        folder_name = root_path.name if root_path else None
        self.normalize_node_fields(root_node, folder_name)
        
        # Add source path tracking to root
        root_node['_source_path'] = str(root_json_path)
        
        # Look for child folders that might contain init.meta.json files (hierarchical mode)
        hierarchical_children = []
        if root_path.is_dir():
            for child_folder in root_path.iterdir():
                if not child_folder.is_dir():
                    continue
                
                child_json_path = child_folder / "init.meta.json"
                if not child_json_path.exists():
                    continue
                
                # Recursively load this child
                child_node = self.build_hierarchical_tree(child_folder)
                if child_node:
                    hierarchical_children.append(child_node)
        
        # If we found hierarchical children, merge them
        if hierarchical_children:
            if 'children' not in root_node:
                root_node['children'] = []
            
            # Add source paths to inline children (they stay in the root file)
            if 'children' in root_node:
                for child in root_node['children']:
                    if isinstance(child, dict) and '_source_path' not in child:
                        self.add_source_paths_recursively(child, str(root_json_path))
            
            # Merge hierarchical children with inline children
            # If a hierarchical child has the same Name as an inline child, merge their children
            for hierarchical_child in hierarchical_children:
                h_name = hierarchical_child.get('Name')
                matched = False
                
                # Look for matching inline child
                for inline_child in root_node['children']:
                    if isinstance(inline_child, dict) and inline_child.get('Name') == h_name:
                        # Found matching inline child - merge children
                        # Merge properties from hierarchical to inline (folder takes precedence for properties)
                        if 'properties' in hierarchical_child:
                            if 'properties' not in inline_child:
                                inline_child['properties'] = {}
                            inline_child['properties'].update(hierarchical_child['properties'])
                        
                        # Merge children from hierarchical into inline
                        if 'children' in hierarchical_child:
                            if 'children' not in inline_child:
                                inline_child['children'] = []
                            inline_child['children'].extend(hierarchical_child['children'])
                        
                        matched = True
                        break
                
                # If no match, add as new child
                if not matched:
                    root_node['children'].append(hierarchical_child)
        else:
            # Single-file mode: all children are in the same file as root
            self.add_source_paths_recursively(root_node, str(root_json_path))
        
        return root_node
    
    def resolve_ui_path(self, root_node: dict, ui_path: str, ui_root_var: str = 'UI') -> Optional[dict]:
        """Resolve a UI path like 'UI.PromptFrame.PromptImage' to a node in the JSON tree.
        
        Args:
            root_node: The root JSON node (typically has 'children')
            ui_path: Dot-separated path like 'UI.PromptFrame.PromptImage' or 'PromptFrame.PromptImage'
            ui_root_var: The variable name used for the root (e.g., 'UI')
        
        Returns:
            The matching node or None if not found
        """
        path_parts = ui_path.split('.')
        
        # Strip UI variable prefix if present (UI.PromptFrame.Title -> PromptFrame.Title)
        if path_parts[0] == ui_root_var:
            path_parts = path_parts[1:]
        
        # If no parts remain after stripping UI, we're targeting the root itself
        if not path_parts:
            return root_node
        
        current_node = root_node
        
        for part_name in path_parts:
            found = False
            
            # Search in children
            if 'children' in current_node and isinstance(current_node['children'], list):
                for child in current_node['children']:
                    if isinstance(child, dict) and child.get('Name') == part_name:
                        current_node = child
                        found = True
                        break
            
            if not found:
                print(f"Warning: Could not find '{part_name}' in path '{ui_path}'")
                return None
        
        return current_node
    
    def expand_variable_reference(self, value: str, variables: Dict[str, str]) -> str:
        """Expand variable references like 'TextureSheet.layer("BG")' to full DSL command.
        
        Args:
            value: The value containing variable reference (e.g., 'TextureSheet.layer("BG").upload(1000, 1000)')
            variables: Dictionary of variable assignments (e.g., {'TextureSheet': 'extract("file.psd")'})
        
        Returns:
            Fully expanded DSL command (e.g., 'extract("file.psd").layer("BG").upload(1000, 1000)')
        """
        # Find variable name at the start
        var_match = re.match(r'^(\w+)\.(.+)', value)
        if not var_match:
            return value
        
        var_name = var_match.group(1)
        rest_of_command = var_match.group(2)
        
        if var_name in variables:
            # Replace variable with its definition
            var_value = variables[var_name]
            return f"{var_value}.{rest_of_command}"
        
        return value
    
    def find_roblox_artifact_path(self) -> Optional[Path]:
        """Find the latest Roblox version folder and return artifact path."""
        if os.name != 'nt':
            print("Warning: Roblox path detection only works on Windows.")
            print("Using fallback: ./roblox_artifacts/")
            fallback = self.project_root / "roblox_artifacts"
            fallback.mkdir(exist_ok=True)
            return fallback
        
        username = os.environ.get('USERNAME', os.environ.get('USER', ''))
        versions_path = Path(f"C:/Users/{username}/AppData/Local/Roblox/Versions")
        
        if not versions_path.exists():
            print(f"Warning: Roblox Versions folder not found at {versions_path}")
            print("Using fallback: ./roblox_artifacts/")
            fallback = self.project_root / "roblox_artifacts"
            fallback.mkdir(exist_ok=True)
            return fallback
        
        latest_version = None
        latest_mtime = 0
        
        for version_dir in versions_path.iterdir():
            if version_dir.is_dir():
                studio_exe = version_dir / "RobloxStudioBeta.exe"
                if studio_exe.exists():
                    mtime = studio_exe.stat().st_mtime
                    if mtime > latest_mtime:
                        latest_mtime = mtime
                        latest_version = version_dir
        
        if latest_version:
            artifact_path = latest_version / "content" / "artifact"
            artifact_path.mkdir(parents=True, exist_ok=True)
            print(f"Found Roblox artifact path: {artifact_path}")
            return artifact_path
        else:
            print("Warning: No Roblox Studio installation found.")
            print("Using fallback: ./roblox_artifacts/")
            fallback = self.project_root / "roblox_artifacts"
            fallback.mkdir(exist_ok=True)
            return fallback
    
    def parse_dsl_command(self, command: str) -> Optional[Dict]:
        """Parse the DSL command string and extract parameters.
        
        Handles quoted and unquoted strings, including special characters.
        """
        def extract_function_arg(text: str, func_name: str) -> Optional[str]:
            """Extract the argument from a function call like func_name(arg)."""
            pattern = f'{re.escape(func_name)}\\('
            match = re.search(pattern, text)
            if not match:
                return None
            
            start_idx = match.end()
            i = start_idx
            depth = 1
            in_quote = None
            escape = False
            arg_chars = []
            
            while i < len(text) and depth > 0:
                char = text[i]
                
                if escape:
                    arg_chars.append(char)
                    escape = False
                elif char == '\\':
                    escape = True
                elif in_quote:
                    if char == in_quote:
                        in_quote = None
                    else:
                        arg_chars.append(char)
                elif char in ('"', "'"):
                    in_quote = char
                elif char == '(':
                    depth += 1
                    arg_chars.append(char)
                elif char == ')':
                    depth -= 1
                    if depth > 0:
                        arg_chars.append(char)
                else:
                    arg_chars.append(char)
                
                i += 1
            
            if depth != 0:
                return None
            
            return ''.join(arg_chars).strip()
        
        # Support both upload(1000px, 1000px) and upload(1000, 1000)
        upload_pattern = r'upload\((\d+)(?:px)?,\s*(\d+)(?:px)?\)'
        upload_match = re.search(upload_pattern, command)
        if not upload_match:
            return None
        
        width = int(upload_match.group(1))
        height = int(upload_match.group(2))
        
        source_file = extract_function_arg(command, 'extract')
        if source_file is None:
            return None
        
        layer_path = extract_function_arg(command, 'layer')
        
        return {
            'source_file': source_file,
            'layer_path': layer_path,
            'width': width,
            'height': height
        }
    
    def get_file_hash(self, file_path: Path) -> str:
        """Calculate MD5 hash of a file."""
        md5 = hashlib.md5()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                md5.update(chunk)
        return md5.hexdigest()
    
    def needs_rebuild(self, source_file: Path, output_file: Path, cache_key: str) -> bool:
        """Check if the output needs to be regenerated."""
        if not output_file.exists():
            return True
        
        source_mtime = source_file.stat().st_mtime
        output_mtime = output_file.stat().st_mtime
        
        if source_mtime > output_mtime:
            return True
        
        current_hash = self.get_file_hash(source_file)
        cached_hash = self.cache.get(cache_key)
        
        if cached_hash != current_hash:
            return True
        
        return False
    
    def decal_id_to_image_id(self, decal_id: int) -> Optional[int]:
        """Convert a Roblox Decal ID to the underlying Image Asset ID by parsing XML metadata."""
        try:
            url = f"https://assetdelivery.roblox.com/v1/asset/?id={decal_id}"
            
            # Create a request that doesn't follow redirects
            class NoRedirect(urllib.request.HTTPRedirectHandler):
                def http_error_302(self, req, fp, code, msg, headers):
                    return fp
                def http_error_301(self, req, fp, code, msg, headers):
                    return fp
            
            opener = urllib.request.build_opener(NoRedirect)
            
            with opener.open(url, timeout=10) as response:
                content = response.read()
                
                # Try to decode as text (XML)
                try:
                    text = content.decode('utf-8')
                except UnicodeDecodeError:
                    # If decoding fails, it's probably binary image data (not a decal)
                    print(f"Error: Asset {decal_id} returned binary data, cannot extract image ID")
                    print("This likely means the decal upload failed or the asset is not a decal.")
                    return None
                
                # Parse XML to find the image ID in the <url> tag inside <Content name="Texture">
                # Format: <url>http://www.roblox.com/asset/?id={imageId}</url>
                match = re.search(r'<url>https?://www\.roblox\.com/asset/\?id=(\d+)</url>', text)
                if match:
                    image_id = int(match.group(1))
                    return image_id
                else:
                    print(f"Error: Could not find image ID in XML metadata for decal {decal_id}")
                    print("XML response:", text[:500])  # Print first 500 chars for debugging
                    return None
            
        except Exception as e:
            print(f"Error converting decal ID to image ID: {e}")
            return None

    def upload_to_roblox_cloud(self, image_path: Path, display_name: str) -> Optional[str]:
        """Upload an image to Roblox Cloud and return rbxassetid:// with the IMAGE asset ID (not decal ID)."""
        if not ROBLOX_CLOUD_AVAILABLE:
            print("Error: rblx-open-cloud package not installed. Run: pip install rblx-open-cloud")
            return None
        
        if not self.roblox_user:
            print("Error: Roblox Cloud API credentials not provided.")
            print("Please provide credentials using one of these methods:")
            print("  1. Command-line: python build.py --api-key YOUR_KEY --user-id YOUR_ID")
            print("  2. Environment variables: ROBLOX_API_KEY and ROBLOX_USER_ID")
            return None
        
        try:
            print(f"Uploading to Roblox Cloud: {display_name}")
            
            with open(image_path, 'rb') as file:
                operation = self.roblox_user.upload_asset(
                    file,  # type: ignore
                    rblxopencloud.AssetType.Image,  # type: ignore (changed from Decal to Image)
                    display_name,
                    f"Auto-uploaded by build system"
                )
                
                # Wait for upload to complete (simple blocking wait)
                asset = operation.wait()
                
                if asset and hasattr(asset, 'id'):
                    image_id = asset.id
                    print(f"✓ Uploaded to Roblox Cloud! Image Asset ID: {image_id}")
                    return f"rbxassetid://{image_id}"
                else:
                    print(f"Error: Upload completed but no asset ID returned")
                    return None
                    
        except Exception as e:
            print(f"Error uploading to Roblox Cloud: {e}")
            return None
    
    def process_png(self, params: Dict, model_json_path: Path, publish_to_cloud: bool = False) -> Optional[str]:
        """Process a PNG file: load, resize, and save to artifact folder or upload to cloud."""
        if self.roblox_artifact_path is None:
            print("Error: Roblox artifact path not initialized")
            return None
        
        source_file = (model_json_path.parent / params['source_file']).resolve()
        
        if not source_file.exists():
            print(f"Error: Source file not found: {source_file}")
            return None
        
        base_name = source_file.stem
        width = params['width']
        height = params['height']
        
        file_hash = self.get_file_hash(source_file)[:8]
        output_filename = f"{base_name}_{width}x{height}_{file_hash}.png"
        output_path = self.roblox_artifact_path / output_filename
        
        pattern = f"{base_name}_{width}x{height}_*.png"
        for old_file in self.roblox_artifact_path.glob(pattern):
            if old_file.name != output_filename:
                print(f"Removing old artifact: {old_file.name}")
                old_file.unlink()
        
        try:
            print(f"Processing PNG: {source_file.name} -> {output_filename}")
            img = Image.open(source_file)
            img = img.resize((width, height), Image.Resampling.LANCZOS)
            img.save(output_path, 'PNG')
            
            # Upload to Roblox Cloud if requested
            if publish_to_cloud:
                cloud_result = self.upload_to_roblox_cloud(output_path, f"{base_name}_{width}x{height}")
                if cloud_result:
                    return cloud_result
            
            return f"rbxasset://artifact/{output_filename}"
        except Exception as e:
            print(f"Error processing PNG {source_file}: {e}")
            return None
    
    def find_psd_layer(self, psd, layer_path: str):
        """Navigate to a specific layer in a PSD using a path like 'MainElements/LeftCorner/Title'."""
        parts = layer_path.split('/')
        current = psd
        
        for part in parts:
            found = False
            for layer in current:
                if layer.name == part:
                    current = layer
                    found = True
                    break
            if not found:
                raise ValueError(f"Layer '{part}' not found in path '{layer_path}'")
        
        return current
    
    def process_psd(self, params: Dict, model_json_path: Path, publish_to_cloud: bool = False) -> Optional[str]:
        """Process a PSD file: extract layer, render, resize, and save."""
        if self.roblox_artifact_path is None:
            print("Error: Roblox artifact path not initialized")
            return None
        
        source_file = (model_json_path.parent / params['source_file']).resolve()
        
        if not source_file.exists():
            print(f"Error: Source file not found: {source_file}")
            return None
        
        layer_path = params.get('layer_path')
        if not layer_path:
            print("Error: PSD processing requires a layer path")
            return None
        
        base_name = source_file.stem
        layer_name = layer_path.split('/')[-1]
        width = params['width']
        height = params['height']
        
        file_hash = self.get_file_hash(source_file)[:8]
        output_filename = f"{base_name}_{layer_name}_{width}x{height}_{file_hash}.png"
        output_path = self.roblox_artifact_path / output_filename
        
        pattern = f"{base_name}_{layer_name}_{width}x{height}_*.png"
        for old_file in self.roblox_artifact_path.glob(pattern):
            if old_file.name != output_filename:
                print(f"Removing old artifact: {old_file.name}")
                old_file.unlink()
        
        try:
            print(f"Processing PSD: {source_file.name} layer '{layer_path}' -> {output_filename}")
            psd = PSDImage.open(source_file)
            layer = self.find_psd_layer(psd, layer_path)
            
            layer_img = layer.topil()
            if layer_img is None:
                print(f"Error: Could not render layer '{layer_path}'")
                return None
            
            layer_img = layer_img.resize((width, height), Image.Resampling.LANCZOS)
            layer_img.save(output_path, 'PNG')
            
            # Upload to Roblox Cloud if requested
            if publish_to_cloud:
                cloud_result = self.upload_to_roblox_cloud(output_path, f"{base_name}_{layer_name}_{width}x{height}")
                if cloud_result:
                    return cloud_result
            
            return f"rbxasset://artifact/{output_filename}"
        except Exception as e:
            print(f"Error processing PSD {source_file}: {e}")
            return None
    
    def process_node(self, node: Dict, model_json_path: Path, keep_sync_source: bool = True, publish_images: bool = False) -> bool:
        """Process a single node in the model.json tree.
        
        Args:
            node: The JSON node to process
            model_json_path: Path to the model/meta file
            keep_sync_source: If True, keep properties_sync_source in the node (for .model.json)
                             If False, remove it (for .meta.json with separate .designsource.luau)
            publish_images: If True, upload images to Roblox Cloud instead of using local artifacts
        """
        modified = False
        
        if 'properties_sync_source' in node:
            sync_source = node['properties_sync_source'].copy()
            
            if not isinstance(node.get('properties'), dict):
                node['properties'] = {}
            
            failed_properties = {}
            
            for prop_name, command in sync_source.items():
                params = self.parse_dsl_command(command)
                if not params:
                    print(f"Warning: Could not parse command: {command}")
                    failed_properties[prop_name] = command
                    continue
                
                source_file = params['source_file']
                
                if source_file.lower().endswith('.png'):
                    result = self.process_png(params, model_json_path, publish_to_cloud=publish_images)
                elif source_file.lower().endswith('.psd'):
                    result = self.process_psd(params, model_json_path, publish_to_cloud=publish_images)
                else:
                    print(f"Warning: Unsupported file type: {source_file}")
                    failed_properties[prop_name] = command
                    continue
                
                if result:
                    # Always sync both Image and ImageContent properties (Roblox ImageLabel compatibility)
                    # Update both properties regardless of which one was specified in properties_sync_source
                    if prop_name == "Image" or prop_name == "ImageContent":
                        node['properties']["Image"] = result
                        node['properties']["ImageContent"] = result
                    else:
                        node['properties'][prop_name] = result
                    
                    modified = True
                else:
                    failed_properties[prop_name] = command
            
            if keep_sync_source:
                if failed_properties:
                    node['properties_sync_source'] = failed_properties
                    if len(failed_properties) < len(sync_source):
                        print(f"Info: {len(sync_source) - len(failed_properties)} properties processed successfully, {len(failed_properties)} kept for retry.")
                    modified = True
            else:
                if 'properties_sync_source' in node:
                    del node['properties_sync_source']
                    modified = True
        
        if 'children' in node and isinstance(node['children'], list):
            for child in node['children']:
                if self.process_node(child, model_json_path, keep_sync_source, publish_images):
                    modified = True
        
        return modified
    
    def process_model_json(self, json_path: Path):
        """Process a single *.model.json or *.meta.json file."""
        print(f"\nProcessing: {json_path.relative_to(self.project_root)}")
        
        try:
            is_meta_file = json_path.suffix == '.json' and json_path.stem.endswith('.meta')
            
            # Check for init.designsource.luau (for complex UIs with path references)
            init_designsource_path = json_path.parent / "init.designsource.luau"
            if init_designsource_path.exists():
                return self.process_with_init_designsource(json_path, init_designsource_path)
            
            if is_meta_file:
                dynamic_path = json_path.parent / f"{json_path.stem.replace('.meta', '.designsource')}.luau"
                
                if not dynamic_path.exists():
                    print(f"No designsource config found: {dynamic_path.name}")
                    return
                
                with open(dynamic_path, 'r', encoding='utf-8') as f:
                    luau_content = f.read()
                    dynamic_data = self.parse_luau_table(luau_content)
                
                with open(json_path, 'r', encoding='utf-8') as f:
                    meta_data = json.load(f)
                
                publish_images = dynamic_data.get('publish_images', False)
                
                if 'properties_sync_source' in dynamic_data:
                    meta_data['properties_sync_source'] = dynamic_data['properties_sync_source']
                
                modified = self.process_node(meta_data, json_path, keep_sync_source=False, publish_images=publish_images)
                
                if modified:
                    # Read original file as text to preserve formatting
                    with open(json_path, 'r', encoding='utf-8') as f:
                        original_text = f.read()
                    
                    # Surgically update only Image and ImageContent properties
                    updated_text = self.update_properties_surgical(original_text, meta_data)
                    
                    with open(json_path, 'w', encoding='utf-8') as f:
                        f.write(updated_text)
                    print(f"Updated: {json_path.name}")
                else:
                    print(f"No changes needed: {json_path.name}")
            else:
                # For .model.json files, check for sibling .designsource.luau
                publish_images = False
                dynamic_path = json_path.parent / f"{json_path.stem}.designsource.luau"
                
                if dynamic_path.exists():
                    with open(dynamic_path, 'r', encoding='utf-8') as f:
                        luau_content = f.read()
                        dynamic_data = self.parse_luau_table(luau_content)
                        publish_images = dynamic_data.get('publish_images', False)
                
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                modified = self.process_node(data, json_path, keep_sync_source=True, publish_images=publish_images)
                
                if modified:
                    # Read original file as text to preserve formatting
                    with open(json_path, 'r', encoding='utf-8') as f:
                        original_text = f.read()
                    
                    # Surgically update only Image and ImageContent properties
                    updated_text = self.update_properties_surgical(original_text, data)
                    
                    with open(json_path, 'w', encoding='utf-8') as f:
                        f.write(updated_text)
                    print(f"Updated: {json_path.name}")
                else:
                    print(f"No changes needed: {json_path.name}")
        
        except Exception as e:
            print(f"Error processing {json_path}: {e}")
    
    def process_with_init_designsource(self, json_path: Path, init_designsource_path: Path):
        """Process a JSON file using init.designsource.luau with UI path references.
        
        Supports both:
        - Single-file structure: All UI elements in one init.meta.json
        - Hierarchical structure: UI elements in separate init.meta.json files across folders
        """
        print(f"Using init.designsource.luau for UI path mappings")
        
        try:
            # Parse the init.designsource.luau file
            with open(init_designsource_path, 'r', encoding='utf-8') as f:
                luau_content = f.read()
            
            config = self.parse_init_designsource_luau(luau_content)
            publish_images = config.get('publish_images', False)
            
            # Build hierarchical tree from folder structure
            root_folder = json_path.parent
            json_data = self.build_hierarchical_tree(root_folder)
            
            if not json_data:
                print(f"Error: Could not load UI tree from {root_folder}")
                return
            
            # Track which files need to be written
            files_to_update = {}  # {file_path: {original_text, modified_data}}
            modified = False
            
            # Process each UI path mapping
            for ui_path, properties in config['ui_mappings'].items():
                # Resolve the UI path to find the target node
                target_node = self.resolve_ui_path(json_data, ui_path, config.get('ui_root_var', 'UI'))
                
                if not target_node:
                    print(f"Skipping unmapped path: {ui_path}")
                    continue
                
                # Get the source file for this node
                source_file_path = target_node.get('_source_path')
                if not source_file_path:
                    print(f"Warning: No source path for {ui_path}")
                    continue
                
                # Ensure the node has a properties dict
                if 'properties' not in target_node:
                    target_node['properties'] = {}
                
                # Process each property for this node
                for prop_name, prop_value in properties.items():
                    # Expand variable references
                    expanded_command = self.expand_variable_reference(prop_value, config['variables'])
                    
                    # Parse the DSL command
                    params = self.parse_dsl_command(expanded_command)
                    if not params:
                        print(f"Warning: Could not parse command for {ui_path}.{prop_name}: {expanded_command}")
                        continue
                    
                    source_file = params['source_file']
                    
                    # Process the image
                    if source_file.lower().endswith('.png'):
                        result = self.process_png(params, json_path, publish_to_cloud=publish_images)
                    elif source_file.lower().endswith('.psd'):
                        result = self.process_psd(params, json_path, publish_to_cloud=publish_images)
                    else:
                        print(f"Warning: Unsupported file type: {source_file}")
                        continue
                    
                    if result:
                        # Always sync both Image and ImageContent properties
                        if prop_name == "Image" or prop_name == "ImageContent":
                            target_node['properties']["Image"] = result
                            target_node['properties']["ImageContent"] = result
                        else:
                            target_node['properties'][prop_name] = result
                        
                        # Track this file for update
                        if source_file_path not in files_to_update:
                            # Load original text for this file
                            with open(source_file_path, 'r', encoding='utf-8') as f:
                                files_to_update[source_file_path] = {
                                    'original_text': f.read(),
                                    'node': target_node
                                }
                        
                        modified = True
                        print(f"✓ Updated {ui_path}.{prop_name}")
            
            # Write updates back to individual files
            if modified:
                for file_path, file_data in files_to_update.items():
                    original_text = file_data['original_text']
                    node = file_data['node']
                    
                    # For hierarchical files (each file = one element), use simple update
                    # For single-file mode, use surgical update with node hierarchy
                    if 'properties' in node and isinstance(node['properties'], dict):
                        # Extract just Image/ImageContent properties
                        props_to_update = {}
                        if 'Image' in node['properties']:
                            props_to_update['Image'] = node['properties']['Image']
                        if 'ImageContent' in node['properties']:
                            props_to_update['ImageContent'] = node['properties']['ImageContent']
                        
                        if props_to_update:
                            updated_text = self.update_properties_simple(original_text, props_to_update)
                        else:
                            updated_text = original_text
                    else:
                        updated_text = original_text
                    
                    if updated_text != original_text:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(updated_text)
                        print(f"Updated: {Path(file_path).name}")
            else:
                print(f"No changes needed")
        
        except Exception as e:
            print(f"Error processing with init.designsource.luau: {e}")
            import traceback
            traceback.print_exc()
    
    def find_model_json_files(self) -> List[Path]:
        """Recursively find all *.model.json and *.meta.json files in the project."""
        model_files = list(self.project_root.rglob('*.model.json'))
        meta_files = list(self.project_root.rglob('*.meta.json'))
        return model_files + meta_files
    
    def build(self):
        """Main build process."""
        print("=" * 60)
        print("Roblox Build System")
        print("=" * 60)
        
        self.roblox_artifact_path = self.find_roblox_artifact_path()
        
        model_files = self.find_model_json_files()
        
        if not model_files:
            print("\nNo *.model.json or *.meta.json files found in project.")
            return
        
        print(f"\nFound {len(model_files)} *.model.json and *.meta.json file(s)")
        
        for model_file in model_files:
            self.process_model_json(model_file)
        
        self.save_cache()
        
        print("\n" + "=" * 60)
        print("Build complete!")
        print("=" * 60)

def main():
    """Entry point for the build system."""
    parser = argparse.ArgumentParser(
        description='Roblox Build System - Process images for Roblox Studio',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic usage (local artifacts only)
  python build.py
  
  # With Roblox Cloud publishing (using command-line)
  python build.py --api-key YOUR_API_KEY --user-id YOUR_USER_ID
  
  # With Roblox Cloud publishing (using environment variables)
  export ROBLOX_API_KEY=your_api_key
  export ROBLOX_USER_ID=your_user_id
  python build.py
        '''
    )
    
    parser.add_argument(
        '--api-key',
        help='Roblox Open Cloud API key (for cloud publishing)',
        default=None
    )
    
    parser.add_argument(
        '--user-id',
        help='Roblox User ID (for cloud publishing)',
        default=None
    )
    
    args = parser.parse_args()
    
    builder = RobloxBuildSystem(api_key=args.api_key, user_id=args.user_id)
    builder.build()

if __name__ == '__main__':
    main()
