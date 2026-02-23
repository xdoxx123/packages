local thread = require("thread")
local fs = require("filesystem")
local shell = require("shell")
local args,options = shell.parse({...})

if args[1] and options["P"] == true then
    args[1] = fs.canonical(args[1])
    local dookie = thread.create(function ()
        pcall(function (...)
            dofile(args[1])
        end)
    end)
    dookie:detach()
elseif args[1] then
    args[1] = fs.canonical(args[1])
    local dookie = thread.create(function ()
        
            dofile(args[1])
     
    end)
    dookie:detach()
end

