for i,v in script.Parent:GetChildren()do
     if v:IsA("ModuleScript") then
         require(v)
    end
end
