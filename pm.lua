local internet = require("internet")
local baseurl = "https://raw.githubusercontent.com/xdoxx123/packages/refs/heads/"
local packages = "https://raw.githubusercontent.com/xdoxx123/packages/refs/heads/main/packages.lua"
local filesystem = require("filesystem")
local shell = require("shell")
local gpu = require("component").gpu
local args,options = shell.parse(...)

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



local packagestable = load(getpackages(packages))()

function downloadpackage(name)
    local tablevalue = packagestable[name]
    for path,loc in pairs(tablevalue.files) do
        local data = getfile(path)
        local split = split(path,"/")
        local filename = split[#split]
        local realpath = loc.."/"..filename
        print("downloading "..tablevalue.name)
        if filesystem.exists(realpath) then
            warn("package already exists reinstalling")
            filesystem.remove(realpath)
        end

        quickwrite(realpath,data)

        print("saved "..filename.." to "..loc)

    end
end

local function readfile(path)
    local file =  filesystem.open(path,"r")
    if file == nil then return end
    local dump = file:read(math.huge)
    return dump
end


if not filesystem.exists("/etc/packages.cfg") then
    filesystem.open("/etc/packages.cfg","w"):close()
end



if options["S"] == true then
    if args[1] == nil then print("lacking name!") return end
    local name = args[1]
    if packagestable[name] == nil then print("not found!") return end
    print("found "..name)
    downloadpackage(name)
    return
end
if args[1] == "list" then
    print("listing")
    for name,data in pairs(packagestable) do
        print("\t"..name)
    end
    return
end

print("usage : pm -S [packagename] \n\tpm list")

