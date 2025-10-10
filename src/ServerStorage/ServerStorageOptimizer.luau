for i,v in script.Parent:GetChildren()do
     if v:IsA("ModuleScript") then
         require(v)
    end
end


print('Hello world')
for x = 1, 10 
do
    print(x)
end