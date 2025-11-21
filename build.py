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
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from PIL import Image
from psd_tools import PSDImage

try:
    import rblxopencloud
    ROBLOX_CLOUD_AVAILABLE = True
except ImportError:
    ROBLOX_CLOUD_AVAILABLE = False

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
                self.roblox_user = rblxopencloud.User(int(user_id), api_key=api_key)
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
    
    def update_properties_surgical(self, original_text: str, updated_data: dict) -> str:
        """Surgically update Image/ImageContent properties while preserving original formatting."""
        text = original_text
        
        def update_property_in_text(text: str, prop_name: str, new_value: str) -> str:
            # Match the property and its value: "PropName": "old_value"
            # This handles various whitespace/formatting
            pattern = rf'("{re.escape(prop_name)}"\s*:\s*)"([^"]*)"'
            
            def replacer(match):
                return f'{match.group(1)}"{new_value}"'
            
            # Check if property exists
            if re.search(pattern, text):
                # Replace existing value
                text = re.sub(pattern, replacer, text, count=1)
            else:
                # Property doesn't exist, need to add it
                # Find the Image property and add ImageContent after it
                if prop_name == "ImageContent":
                    image_pattern = r'("Image"\s*:\s*"[^"]*")'
                    match = re.search(image_pattern, text)
                    if match:
                        # Insert ImageContent after Image with same indentation
                        insert_pos = match.end()
                        # Add comma and newline with same indentation as Image line
                        line_start = text.rfind('\n', 0, match.start()) + 1
                        indent = text[line_start:match.start()]
                        insertion = f',\n{indent}"ImageContent": "{new_value}"'
                        text = text[:insert_pos] + insertion + text[insert_pos:]
            
            return text
        
        # Recursively find all properties that need updating
        def find_and_update(node, text):
            if isinstance(node, dict):
                if 'properties' in node and isinstance(node['properties'], dict):
                    props = node['properties']
                    if 'Image' in props:
                        text = update_property_in_text(text, 'Image', props['Image'])
                    if 'ImageContent' in props:
                        text = update_property_in_text(text, 'ImageContent', props['ImageContent'])
                
                # Recursively process children
                if 'children' in node and isinstance(node['children'], list):
                    for child in node['children']:
                        text = find_and_update(child, text)
            
            return text
        
        return find_and_update(updated_data, text)
    
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
        
        upload_pattern = r'upload\((\d+)px,\s*(\d+)px\)'
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
    
    def upload_to_roblox_cloud(self, image_path: Path, display_name: str) -> Optional[str]:
        """Upload an image to Roblox Cloud and return rbxassetid://"""
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
                    file,
                    rblxopencloud.AssetType.Decal,
                    display_name,
                    f"Auto-uploaded by build system"
                )
                
                # Wait for upload to complete (simple blocking wait)
                asset = operation.wait()
                
                if asset and hasattr(asset, 'id'):
                    asset_id = asset.id
                    print(f"✓ Uploaded successfully! Asset ID: {asset_id}")
                    return f"rbxassetid://{asset_id}"
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
