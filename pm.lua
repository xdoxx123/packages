local internet = require("internet")
local baseurl = "https://raw.githubusercontent.com/xdoxx123/packages/refs/heads/"
local packagesdata = "/etc/packages.data"
local packages = "https://raw.githubusercontent.com/xdoxx123/packages/refs/heads/main/packages.lua"
local filesystem = require("filesystem")
local shell = require("shell")
local gpu = require("component").gpu
local serialization = require("serialization")
local args = {...}

function split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end



function getpackages(url)
    local code = ""
    for chunk in internet.request(packages) do code=code..chunk end

    return code
end

function getfile(path)
    local url = baseurl..path
    local file = ""
    for chunk in internet.request(url) do file=file..chunk end
    return file
end

function quickwrite(path,data)
    local file = io.open(path,"w")
        file:write(data)
        file:flush()
        file:close()
end


function warn(str)
    local foreground = gpu.getForeground()
    gpu.setForeground(0x00FFFF)
    print(str)
    gpu.setForeground(foreground)
end
local function readfile(path)
    local file =  io.open(path,"r")
    if file == nil then return end
    local dump = file:read("a")
    return dump
end


local chunk, err = load(getpackages(packages))
if not chunk then
    warn("Load error: " .. tostring(err))
    return
end

local packagestable = chunk()
local installedpackages = {}
if filesystem.exists(packagesdata) then
   local file = readfile(packagesdata)
   if file == "" or file == "{}" then
        
    else
        local deserial = serialization.unserialize(file)
   installedpackages = deserial
   end
   
end

function getrealname(name)
    
    return packagestable[name].name
end
function packagedownloaded(name)

    return installedpackages[name] ~= nil
end

function downloadpackage(name)
    local tablevalue = packagestable[name]
    for path,loc in pairs(tablevalue.files) do
        
        local data = getfile(path)
        local split = split(path,"/")
        local filename = split[#split]
        
        local realpath = loc.."/"..filename
        if tablevalue.depends ~= nil then
            print("program has depends downloading now!")
            for index, value in ipairs(tablevalue.depends) do
                if packagedownloaded(value) then
                    warn("[!] "..value.." is already installed skipping")
                    goto con
                else
                    downloadpackage(value)
                end

                ::con::
            end
        end
        
        
        
        
        print("downloading "..tablevalue.name)
        if filesystem.exists(realpath) then
            warn("package already exists reinstalling")
            filesystem.remove(realpath)
        end

        quickwrite(realpath,data)
        installedpackages[name] = installedpackages[name] or {}
        table.insert(installedpackages[name], realpath)
        quickwrite(packagesdata,serialization.serialize(installedpackages))
        print("saved "..filename.." to "..loc)

    end
end



function deletepackage(name,silent)
    if packagedownloaded(name) == false then
        warn("package isnt installed?")
        return
    end
    local files = installedpackages[name]
    if silent == false or silent == nil then print("[!] deleting ".. name) end
    for index, value in ipairs(files) do
        if filesystem.exists(value) then
            print("[!] uninstalling "..value)
            filesystem.remove(value)
        end
    end
    installedpackages[name] = nil
    quickwrite(packagesdata,serialization.serialize(installedpackages))
end

function downloadedpackages()
    local tabls = {}
    for key, value in pairs(installedpackages) do
        table.insert(tabls,key)
    end
    return tabls
end
function updatepackage(name)
    
    print("[!] updating "..name)
    deletepackage(name,true)
    downloadpackage(name)
end

if not filesystem.exists(packagesdata) then
    filesystem.open(packagesdata,"w"):close()
end

if args[1] == "install" then
    
    if args[2] == nil then print("lacking name!") return end
    local name = args[2]
    if packagestable[name] == nil then print("not found!") return end
    print("found "..name)
    downloadpackage(name)
    
end

if args[1] == "list" then
    
    print("listing")
    for name,data in pairs(packagestable) do
        print("\t"..name)
    end
    
end
if args[1] == "uninstall" then
   if args[2] == nil then print("lacking name!") return end
    local name = args[2]
    deletepackage(name)
end

if args[1] == "update" then
   if args[2] == nil then print("lacking name!") return end
    local name = args[2]
    updatepackage(name)
end

if args[1] == "updateall" then
    
    for key, value in ipairs(downloadedpackages()) do
        updatepackage(value)
    end
end

if args[1] == "uninstallall" then
    print("are you sure you want to uninstall everything? Y\\n")
    local respond = io.read()
    if string.lower(respond) == "y" then
        for key, value in ipairs(downloadedpackages()) do
        deletepackage(value)
    end
    end
end

if args[1] == "listinstalled" then
    print("listing installed")
        for key, value in ipairs(downloadedpackages()) do
        print(value)
        end
end
if #args == 0 then

    print("Usage : pm install [-i] <package> \n\tpm list\n\tpm uninstall package\n\tpm update package\n\tpm updateall\n\tpm uninstallall\n\tpm listinstalled")
end