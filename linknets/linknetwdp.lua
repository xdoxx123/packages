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
			completedResult = ""
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






local function cancelDownload(addr,idk,char,code)
    if code == 44 then
        print("Download cancelled")
        wdp.cancel = true
    end
end



local component = require("component")
print("loading 'component'")
local modem = component.modem
if modem then
	print("modem registered")
else
	error("no modem present")
end

local fs = require("filesystem")
print("loading 'filesystem'")
local event = require("event")
print("loading 'event'")
local term = require("term")
print("loading 'term'")

local user = "root"
local host = "me"
local password = nil
local dir = "/"

function split(s, delimiter)
	pcall(function()
		result = {}
		for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
			table.insert(result, match)
		end
	end)
	return result
end
function checkDomain(name)
	modem.broadcast(11501, "arp:ARPrequest")
	while true do
		local returned = nil
		local t1, t2, from, port, _, message = event.pull(5, "modem_message")
		if from then
			if split(message, ":")[2] == name then
				print("DNS: Resolved hostname " .. name)
				returned = from
				return returned
			else
			end
		else
			break
		end
	end
	if returned == nil then
		print("No host with that name exists")
	end
end

function tcpsend(adr, port, stuff)
	repeat
		modem.send(adr, port, stuff)
		local t1, t2, from, port, _, response = event.pull(2, "modem_message")
	until response
	return "OK"
end

function readingMode()
	repeat
		local t1, t2, from, port, _, message = event.pull(3, "modem_message")
		if message ~= nil and split(message, ":")[1] ~= "arp" then
			print(message)
		end

	until from == nil
end


print("")
print("Linknet WDP (Wireless Distribution Protocol) PRELIMINARY VERSION")
while true do
	term.setCursorBlink(false)
	term.write(user .. "@" .. host .. " # ")
	local cmd = io.read()
	if cmd == "logout" then
		break
	end
	if cmd == "connect" then
		term.write("\nconnect to server? > ")
		local TEMP_servername = io.read()
		print("\nConnecting...")
		modem.open(11501)
		modem.broadcast(11501, "arp:ARPrequest")
		local success = false
		while true do
			local t1, t2, from, port, _, message = event.pull(5, "modem_message")
			if from then
				if split(message, ":")[2] == TEMP_servername then
					host = split(message, ":")[2]
					print("DNS: Resolved hostname " .. TEMP_servername)
					success = true
					hostIP = from
					break
				else
				end
			else
				break
			end
		end
		if success == true then
			print("\nConnected to " .. host)
			modem.send(hostIP, 11501, "GETwelcomemsg")
			readingMode()
			print("Getting root directory of host " .. host)

			tries = 0
			repeat
				tries = tries + 1
				print("Attempt #" .. tries)
				pcall(function()
					modem.send(hostIP, 11501, "ROOTrequest")
				end)
				t1, t2, from, port, _, message = event.pull(3, "modem_message")
				print("Server returned " .. tostring(message))
				if message == nil then
					message = "arp:nul"
				end
			until tries == 5 or split(message, ":")[1] ~= "arp"

			if from and split(message, ":")[1] ~= "arp" then
				print("Root directory is " .. message)
				dir = message
			else
				print("Root directory wasnt obtained, using /")
			end
			term.write("\n\n" .. host .. " login: ")
			user = io.read()
			term.write("\npassword: ")
			password = io.read()
			term.clear()
			print(
				"\nYou are now logged in. Keep in mind linknet does not check if the password is valid, so perform a test operation with the server to find out if the credentials are correct."
			)
			print("\n")
		else
			print("\nConnection failed.")
		end
		modem.close(11501)
	end
	if cmd == "list" then
		modem.open(11501)
		pcall(function()
			modem.send(hostIP, 11501, "dir " .. user .. " " .. password .. " " .. dir)
		end)

		readingMode()
		modem.close(11501)
	end
	if cmd == "creds" then
		modem.open(11501)
		pcall(function()
			modem.send(hostIP, 11501, "creds " .. user .. " " .. password)
		end)

		readingMode()
		modem.close(11501)
	end
	if split(cmd, " ")[1] == "see" then
		modem.open(11501)
		pcall(function()
			modem.send(hostIP, 11501, "see " .. user .. " " .. password .. " " .. split(cmd, " ")[2] .. " " .. dir)
		end)

		local t1, t2, from, port, _, message = event.pull(3, "modem_message")
		if from and split(message, ":")[1] ~= "arp" then
			print("Press any key for more text")
			for line in (message .. "\n"):gmatch("(.-)\r?\n") do
				print(line)
				event.pull("key_down")
			end
		end
		modem.close(11501)
	end
	if split(cmd, " ")[1] == "cd" then
		modem.open(11501)
		pcall(function()
			modem.send(hostIP, 11501, "cd " .. user .. " " .. password .. " " .. split(cmd, " ")[2] .. " " .. dir)
		end)

		local t1, t2, from, port, _, message = event.pull(3, "modem_message")
		if from and split(message, ":")[1] ~= "arp" then
			if message ~= "Cannot perform operation" then
				dir = message
			end
		end
		modem.close(11501)
	end
	if split(cmd, " ")[1] == "get" then
        local slop = event.listen("key_down",cancelDownload)
        modem.send(hostIP,11501,"get "..user.." "..password.." "..dir..split(cmd," ")[2])
        os.sleep(0.6)
        print("Hit Z to cancel download!")
		print("Getting segment data from "..hostIP)
		local dwnfield,header = wdp.get(hostIP,11502,dir..split(cmd," ")[2].." "..user.." "..password)
        wdp.cancel = false
        if dwnfield ~= nil then
            if header == "Cannot perform operation" then
                print("Cannot perform operation")
            else
                if header == nil then
                    term.write("\nThe header was corrupted. Type a new filename for the downloaded file. ")
                    header = io.read()
                end
                print("Download completed.")
                print("Writing file to your home directory. (/home/" .. header .. ")")
                local file = io.open("/home/" .. header, "w")
                if file then
                    file:write(tostring(dwnfield))
                    file:close()
                    print("File written.")
                else
                    print("error writing file")
                end
            end
        else
            print("No data was received.")
        end
        event.cancel(slop)
		modem.close(11501)
	end
end
term.setCursorBlink(true)
