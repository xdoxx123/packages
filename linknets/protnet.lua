local wdp = {}
local component = require("component")
local modem = component.modem
local thread = require("thread")
wdp.buffers = {}
local acceptidenttx = "WDPTX"
local acceptidentrx = "WDPRX"
wdp.seedport = 11502
wdp.cancel = false
local wdpthread = nil
local event = require("event")
local animationframes = {
	"|",
	"/",
	"-",
	"\\",
	"|",
	"/",
	"-",
	"\\",
}

function math.round(number)
	if (number - (number % 0.1)) - (number - (number % 1)) < 0.5 then
		number = number - (number % 1)
	else
		number = (number - (number % 1)) + 1
	end
	return number
end
local function findBuffer(id)
	for i, v in pairs(wdp.buffers) do
		if v.id == id then
			return v
		end
	end
end
local function seed()
	modem.open(wdp.seedport)
	while true do
		local _, _, from, port, _, ident, buffer, segment = event.pull("modem_message")
		if ident == acceptidenttx and findBuffer(buffer) and findBuffer(buffer).segments[tonumber(segment)] then
			modem.send(
				from,
				port,
				acceptidentrx,
				findBuffer(buffer).head,
				#findBuffer(buffer).segments,
				findBuffer(buffer).segments[tonumber(segment)],
				segment
			)
		end
	end
end

local function splitByChunk(text, chunkSize)
	local s = {}
	for i = 1, #text, chunkSize do
		s[#s + 1] = text:sub(i, i + chunkSize - 1)
	end
	return s
end

function wdp.buffer(id, headsup, data, size)
	local buffer = {
		id = id,
		head = headsup,
		segments = splitByChunk(data, size),
	}
	table.insert(wdp.buffers, buffer)
	return buffer
end

function wdp.startseed()
	if wdpthread == nil then
		wdpthread = thread.create(seed)
	end
end
function wdp.stopseed()
	if wdpthread ~= nil then
		modem.close(wdp.seedport)
		wdpthread:kill()
		wdpthread = nil
	end
end
function wdp.get(addr, portF, buffer)
	modem.open(portF)
	repeat
		modem.send(addr, portF, acceptidenttx, buffer, 1)
		_, _, from, port, _, ident, csheader, segments, segment, index = event.pull(1, "modem_message")
	until (ident == acceptidentrx and from == addr) or wdp.cancel == true
	if wdp.cancel == false then
		local completedSegments = {}
		print(segments .. " segments in data")
		length = 0
		pass = 1
		local frame = 1
		repeat
			for i = 1, segments do
				if completedSegments["Seg" .. tostring(i)] then
				else
					modem.send(addr, port, acceptidenttx, buffer, i)
					local _, _, from, port, _, ident, csheader, segments, segment, index =
						event.pull(0.1, "modem_message")
					if index == i then
						io.stdout:write(
							"Receiving... "
								.. animationframes[frame]
								.. " pass: "
								.. pass
								.. ", packet size: "
								.. #segment
								.. ", scanning: "
								.. i
								.. "..."
								.. "\r"
						)
						frame = frame + 1
						if frame > #animationframes then
							frame = 1
						end
						completedSegments["Seg" .. tostring(index)] = segment
					end
				end
			end
			length = 0
			for i, v in pairs(completedSegments) do
				length = length + 1
			end
			pass = pass + 1
			io.stdout:write("\n" .. length .. " out of " .. segments .. ", pass: " .. (pass - 1) .. "\n")
		until length == segments or wdp.cancel == true
		if wdp.cancel == false then
			local completedResult = ""
			for i = 1, segments do
				completedResult = completedResult .. completedSegments["Seg" .. i]
			end
		else
			return nil, nil
		end
		return completedResult, csheader
	else
		return nil, nil
	end
end

local component = require("component")
local modem = component.modem
local fs = require("filesystem")
local event = require("event")
local term = require("term")
args = { ... }
local root = "/home/"

local members = {}
local netname = "untitled linknet"
if modem.isWireless() then
modem.setStrength(10000000)
end
modem.open(11501)
local function decimalRandom(minimum, maximum)
	return math.random() * (maximum - minimum) + minimum
end
function split(s, delimiter)
	result = {}
	for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end
if fs.exists(args[1]) then
	root = args[1] .. "/"
end

function tcpsend(adr, port, stuff)
	returnthat = nil
	tries = 0
	repeat
		tries = tries + 1
		print("[TCPSEND]  " .. stuff .. " TO " .. adr)
		modem.send(adr, port, stuff)
		local t1, t2, from, port, _, response = event.pull(1, "modem_message")
		returnthat = response
		if response then
			print("[TCPRESPONSE]  " .. response .. " FROM " .. from)
		end
	until returnthat == "OK" or tries == 5
	return returnthat or "GregTech"
end

function tcpget()
	returnthat = nil
	local tries = 0
	repeat
		tries = tries + 1
		local t1, t2, from, port, _, response = event.pull(1, "modem_message")
		returnthat = response
		if response then
			print("[TCPGET]  " .. response .. " FROM " .. from)
		end
	until returnthat ~= nil or tries == 5
	return returnthat or "GregTech"
end

function checkRoot(path)
	local successw = false

	pcall(function()
		local parsedRoot = fs.canonical(root)
		local segmentedRoot = split(parsedRoot, "/")
		local segmentedPath = split(fs.canonical(path), "/")
		successw = true

		if fs.canonical(path) == "/" then
			successw = false
		end
		for i = 1, #segmentedRoot do
			if segmentedRoot[i] == segmentedPath[i] then
			else
				successw = false
			end
		end
	end)

	return successw
end

local netname = args[2] or "untitled linknet"

print("Multithreaded Protnet WDP (Wireless Distribution Protocol) PRELIMINARY VERSION (" .. netname .. ")")

if fs.exists("/linknet/members") then
	local userlist = io.open("/linknet/members")
	for line in (userlist:read(math.huge) .. "\n"):gmatch("(.-)\r?\n") do
		local member = split(line, "=")
		table.insert(members, member)
		print("registered user: " .. member[1])
	end
	print("Restart your computer if server failure. DO NOT run this program more than one time.")
	wdp.startseed()
	function protnet()
		local success,reason = pcall(function()
		
		while true do
			local t1, t2, from, port, _, message = event.pull("modem_message")
			if message then
				
			end
			local splitmessage = split(tostring(message), " ")
			if message == "arp:ARPrequest" then
				os.sleep(0.5)
				
				modem.send(from, 11501, "arp:" .. netname)
			elseif message == "ROOTrequest" then
				os.sleep(1)
				
				modem.send(from, 11501, root)
			elseif message == "GETwelcomemsg" then
				os.sleep(1)
				
				local welcm = io.open("/linknet/welcome.msg", "r")
				if welcm then
					modem.send(from, 11501, welcm:read(math.huge))
				end
				welcm:close()
			elseif splitmessage[1] == "dir" then
				success23 = false
				os.sleep(0.5)
				for i, v in pairs(members) do
					if splitmessage[2] == v[1] and splitmessage[3] == v[2] then
						success23 = true
						if fs.exists(splitmessage[4]) then
							modem.send(from, 11501, "You are in directory " .. fs.canonical(splitmessage[4]))
							local stuff = ""
							for i, v in fs.list(splitmessage[4]) do
								os.sleep(0.2)

								stuff = stuff .. i .. "\n"
							end
							
							modem.send(from, 11501, stuff)
						else
							
							modem.send(from, 11501, "Incorrect path")
						end
					else
					end
				end
				if success23 == false then
					
					modem.send(from, 11501, "Incorrect credentials")
				end
			elseif splitmessage[1] == "creds" then
				local success = false
				os.sleep(0.5)
				for i, v in pairs(members) do
					if splitmessage[2] == v[1] and splitmessage[3] == v[2] then
						success = true
					end
				end
				if success == true then
					
					modem.send(from, 11501, "Your user credentials are valid.")
				else
					
					modem.send(from, 11501, "Your user credentials are not valid. Reconnect to the server.")
				end
			elseif splitmessage[1] == "cd" then
				local success = false
				os.sleep(0.5)
				for i, v in pairs(members) do
					if splitmessage[2] == v[1] and splitmessage[3] == v[2] then
						success = true
					end
				end
				if string.sub(splitmessage[4], 1, 1) == "/" then
					if
						fs.exists(splitmessage[4] .. "/")
						and success == true
						and fs.isDirectory(splitmessage[4]) == true
						and checkRoot(splitmessage[4]) == true
					then
						
						modem.send(from, 11501, splitmessage[4] .. "/")
					else
						
						modem.send(from, 11501, "Cannot perform operation")
					end
				else
					if
						fs.exists(splitmessage[5] .. splitmessage[4] .. "/")
						and success == true
						and fs.isDirectory(splitmessage[5] .. splitmessage[4]) == true
						and checkRoot(splitmessage[5] .. splitmessage[4]) == true
					then
						
						modem.send(from, 11501, splitmessage[5] .. splitmessage[4] .. "/")
					else
						
						modem.send(from, 11501, "Cannot perform operation")
					end
				end
			elseif splitmessage[1] == "see" then
				local success = false
				os.sleep(0.5)
				for i, v in pairs(members) do
					if splitmessage[2] == v[1] and splitmessage[3] == v[2] then
						success = true
					end
				end
				if string.sub(splitmessage[4], 1, 1) == "/" then
					if
						fs.exists(splitmessage[4])
						and success == true
						and fs.isDirectory(splitmessage[4]) == false
						and checkRoot(splitmessage[4]) == true
					then
						local file = io.open(splitmessage[4], "r")
						local text = file.read(math.huge)
						file:close()
						
						modem.send(from, 11501, text)
					else
						
						modem.send(from, 11501, "Cannot perform operation")
					end
				else
					if
						fs.exists(splitmessage[5] .. splitmessage[4])
						and success == true
						and fs.isDirectory(splitmessage[5] .. splitmessage[4]) == false
						and checkRoot(splitmessage[5] .. splitmessage[4]) == true
					then
						local file = io.open(splitmessage[5] .. splitmessage[4], "r")
						local text = file:read(math.huge)
						file:close()
						
						modem.send(from, 11501, text)
					else
						
						modem.send(from, 11501, "Cannot perform operation")
					end
				end
			elseif splitmessage[1] == "get" then
				local success = false
				os.sleep(0.5)
				for i, v in pairs(members) do
					if splitmessage[2] == v[1] and splitmessage[3] == v[2] then
						success = true
					end
				end
				if success == true then
					if
						fs.exists(splitmessage[4])
						and fs.isDirectory(splitmessage[4]) == false
						and checkRoot(splitmessage[4])
					then
						local file = io.open(splitmessage[4], "r")
						local stuff = file:read(math.huge)
						file:close()
						if wdp.buffers[splitmessage[4] .. " " .. splitmessage[2] .. " " .. splitmessage[3]] then
						else
							
							wdp.buffer(
								splitmessage[4] .. " " .. splitmessage[2] .. " " .. splitmessage[3],
								fs.name(splitmessage[4]),
								stuff,
								1024
							)
						end
					end
				end
			else
				
			end
		end

		end)
		if success == false then
			print(reason)
			protnet()
		end
	end
else
	print("Create a user account for clients to log on to use Linknet (/linknet/members)")
	print("example: name=password")
end

local protnetthread = thread.create(protnet)
protnetthread:detach()
wdpthread:detach()

-- how linknet messages are formatted: test hi = "test" (1), "hi" (2)
--endoffile
