local component = require("component")
local internet = require("internet")
local serial = require("serialization")
local fs = require("filesystem")
local term = require ("term")
local keyboard = require("keyboard") 
local json = require("json")
local event = require("event")
local thread = require("thread")
local CONFIG_FILE = "/home/settings.cfg"
local SWITCH_TABLE = "/home/switchtable.tbl"
local CONFIG = {ip = "localhost",port = "12080", wait = 1}
local DEFAULT_CONFIG = {ip = "84.65.32.30",port = "12080", wait = 1}
local getip = "http://"..CONFIG.ip..":"..CONFIG.port.."/json"
local world = component.world_link
local wait = 1
local chunkLoad = true
local RUNNING = true
local flagReset = false

-- Decode
function decode(x)
    for chunk in x do result = result .. chunk end
    decoded = json:decode(result)
    return decoded
end

-- General HTTP GET
local function httpGET(ip)
    local atable = {}
    local decoded = ""
    local result = ""
    local handle = internet.request(ip,"",{},"GET")
    if handle == nil then
        print("failed to connect")
    else
        value, data = pcall(decode(handle))
        if value then
            return value
        else
            return nil
        end
    end
end

-- General HTTPS GET -- required for a list of objects (i.e all turnouts)
local function httpsGET(ip)
    local atable = {}
    local decoded = ""
    local result = ""
    local handle = internet.request(ip)
    if handle == nil then
        print("failed to connect")
    else
        for chunk in handle do result = result .. chunk end
        decoded = json:decode(result)
    end
    return decoded
end

-- General HTTP PUT
function httpPUT(ip, data)
    local encoded = json:encode(data)
    local header = {["Content-Type"] = "application/json;charset=utf-8"}
    local result = ""
    local handle = internet.request(ip, encoded, header, "PUT")
    if handle == nil then
        print("failed to connect")
    else
        holdtable = handle()
    end
end

-- General HTTP POST
function httpPOST(ip, data)
    local encoded = json:encode(data)
    local header = {["Content-Type"] = "application/json;charset=utf-8"}
    local handle = internet.request(ip, encoded, header, "POST")
    if handle == nil then
        print("failed to connect")
    end
end
 
-- General save file
function saveFile(file, data)
    local f = io.open(file, "w")
    if f == nil then error("Couldn't open " .. file .. " to write config.") end
    f:write(serial.serialize(data, 100000))
    f:close()
end

-- General load file
function loadFile(file)
    local f = io.open(file, "r")
    if f == nil then 
      print("Could not open " .. CONFIG_FILE .. ".")
      return nil
      else
      local data = serial.unserialize(f:read("*a"))
      f:close()
      return data
      end
end

-- General loadconfig file, loads default if not found
function loadConfig(file)
    local f = io.open(file, "r")
    if f == nil then 
      print("Could not open " .. CONFIG_FILE .. ".")
      print("Loading default config")
      return DEFAULT_CONFIG
      else
      local data = serial.unserialize(f:read("*a"))
      f:close()
      return data
      end
end

-- Compares the Current switches against the JMRI turnouts, adds switch to JMRI if not found
function compareWeb(CurrSwitches, WebSwitches)
    for name, data in pairs(CurrSwitches) do
        if WebSwitches[name] == nil then
            httpPUT(getip.."/turnout", buildTurnout(name,name, data.state))
        end
    end
end

--Compares the states of the Current switches against the JMRI turnouts, if different, changes the state of that switch
function compareWebState(CurrSwitches, WebSwitches)
    for name, data in pairs(CurrSwitches) do
        if WebSwitches[name] ~= nil then
            if WebSwitches[name] ~= data.state then
                x = data.position.x
                y = data.position.y
                z = data.position.z
                location = world.getLocationByCoordinates(x,y,z)
                flagChunk = false
                if chunkLoad then 
                    if location.isLoaded() == false then 
                        location.getChunk().forceLoad() 
                        print("Chunk loading..")
                        os.sleep(0.1)
                        flagChunk = true
                    end
                end
                a = location.getTileEntities().whereProperty("type", "automation:redstone_box").asList()
                if a ~= nil then
                    b = a[1]
                    c = b.getAPI("automation:redstone_box")
                    out = 0
                    if WebSwitches[name] then out = 15 end
                    c.setPowerLevel(out)
                    if flagChunk then 
                        os.sleep(0.1)
                        location.getChunk().unforceLoad()
                    end
                    print("Set: ",x,y,z,"To: ",out)
                    CurrSwitches[name].state = WebSwitches[name]
                else
                    print("Error locating rebox: ", name)
                end
            end    
        end
    end
end

-- Compares the current switches against the previously saved switches
function compareTables(compare)
    against = loadFile(SWITCH_TABLE)
    if against ~= nil then
        for name, data in pairs(compare) do
            if against[name] == nil then
                against[name] = data
            end
        end
        saveFile(SWITCH_TABLE, against)
        return against
    else
        saveFile(SWITCH_TABLE, compare)
        return compare
    end   
end

-- Searches for all loaded Redstone_box, returns the list of found switches
function FindSwitches()
    data = {}
    count = 0
    Allredboxes = world.getLoadedTileEntities().whereProperty("type", "automation:redstone_box").asList()
    if Allredboxes then
        for i, redbox in pairs(Allredboxes) do
            position = redbox.getLocation()
            xpos = position.getX()
            ypos = position.getY()
            zpos = position.getZ() 
            c = {["x"] = xpos, ["y"] = ypos, ["z"] = zpos}
            output = redbox.getAPI("automation:redstone_box").getPowerLevel()
            a = {}
            a["position"] = c
            a["state"] = Rstate(output)
            name = tostring(xpos)..","..tostring(ypos)..","..tostring(zpos)
            data[name] = a
            count = count + 1
            os.sleep(0.1)
            end
        end
    if data == {} then
        data = nil
        end
    print("Redboxes found: ",count)
    return data
end
 
-- Turns JMRI light to a readable table
function ParseLight(x)
    name = x["data"]["name"]
    state = x["data"]["state"]
    return JLstate(state)
end

-- Turns JMRI turnout to a readable table
function ParseTurnout(x)
    xtable = {}
    for i,v in pairs(x) do
        name = v["data"]["name"]
        name = string.sub( name, 3 )
        username = v["data"]["userName"]
        comment = v["data"]["comment"]
        inverted = v["data"]["inverted"]
        state = JTstate(v["data"]["state"])
        if name ~= nil then
            xtable[name] = state
        end
    end
    return xtable
end

-- Builds JMRI Turnout to send
function buildTurnout(name, comment, state)
    setstate = 2
    if state == true then setstate = 4 end
    out = {
        type="turnout",
        data= {name="IT"..name,state=setstate}
    }
    return out
end

-- Builds JMRI Light to send
function buildLight(name, state)
    setstate = 4
    if state == true then setstate = 2 end
    out = {
        type="light",
        data={name=name,state=setstate},
      }
    return out
end

-- JMRI Turnout state converts to true or false
function JTstate(x) 
    local out = false
    if x == 4 then
        out = true
    end
    return out
end

-- JMRI Light state converts to true or false, they are backwards...
function JLstate(x) 
    local out = false
    if x == 2 then
        out = true
    end
    return out
end

-- Redstone state convert to true or false
function Rstate(x) 
    local out = false
    if x == 15 then
        out = true
    end
    return out
end

-- Gets user config information
function getSettings()
    print("What is the IP address of the JMRI server?")
    local ip = nil
    repeat
      ip = io.read()
    until ip ~= nil

    print("What is the port number of the JMRI server?")
    local port = nil
    repeat
      port = tonumber(io.read())
      if port == nil or port <= 0 then
        print("Invalid port number. Please enter a positive number.")
      end
    until port ~= nil and port > 0
    
    print("How fast do you want the update rate in seconds (standard is 1) ?")
    local wait = nil
    repeat
        wait = tonumber(io.read())
        if wait == nil or wait <= 0 then
        print("Invalid number. Please enter a positive number.")
        end
    until wait ~= nil and wait > 0
    
    print("Entered information:")
    print("  JMRI IP: \""..ip.."\"")
    print("  JMRI port: \""..port.."\"")
    print("  Update rate (s): \""..wait.."\"")
    print("Is this information correct? [y/n]")
    local choice = io.read()
      
    if choice == "y" or choice == "yes" then
        CONFIG = {
            ip = ip,
            port = port,
            wait = wait
        }
        return CONFIG
    else
        return nil
    end
end

-- Checks for config file and loads, if not found, asks user for input
function startup()
    local CONFIG = nil
    local f = io.open(CONFIG_FILE, "r")
    if f == nil then 
        CONFIG = getSettings()
        if CONFIG == nil then
            CONFIG = loadConfig(CONFIG_FILE)
            saveFile(CONFIG_FILE,CONFIG)
        else
            print("Saving to "..CONFIG_FILE..".")
            saveFile(CONFIG_FILE,CONFIG)
        end
    else
        CONFIG = loadConfig(CONFIG_FILE)
    end
    return CONFIG
end

-- What to do when the user has typed some keys.
local function onKeyDown(code)
    local key = keyboard.keys[code]
    if (keyboard.isControlDown()) then
        if (key == "r") then
            flagReset = true
        elseif (key == "q") then
            print("Quitting.")
            RUNNING = false
        end
    end
end

-- General purpose event handler that delegates different events to their own functions.
function handleEvents()
    while RUNNING do
        local event_name, p1, p2, p3, p4, p5 = event.pull()
        if event_name == "key_down" then
            local key_code = p3
            onKeyDown(key_code)
        end
    end
end

-- INIT --
-- Setup of config and switch table
CONFIG = startup()
getip = "http://"..CONFIG.ip..":"..CONFIG.port.."/json"
CurrSwitches = loadFile(SWITCH_TABLE)
if CurrSwitches == nil then
    CurrSwitches = FindSwitches()
    saveFile(SWITCH_TABLE, CurrSwitches)
end
term.clear()

-- MAIN --

-- Create event handle for user keyboard
thread.create(handleEvents)

-- While running, checks in order; User reset, Build mode, Find switches, Update switches
while RUNNING do
    if flagReset then
        flagReset = false
        CONFIG = getSettings()
        if CONFIG == nil then
            CONFIG = loadConfig(CONFIG_FILE)
            saveFile(CONFIG_FILE,CONFIG)
        else
            print("Saving to "..CONFIG_FILE..".")
            saveFile(CONFIG_FILE,CONFIG)
        end
        term.clear()
        getip = "http://"..CONFIG.ip..":"..CONFIG.port.."/json"
    end
    print("JMRI Switches")
    print(os.date(" %I:%M %p"))
    print("Reset: Cntl + r")
    print("Exit: Cntl + q")
    if ParseLight(httpGET(getip.."/light/ILBuildMode")) then -- Constantly finds switches
        print("In Build Mode")
        CurrSwitches = compareTables(FindSwitches())
        compareWeb(CurrSwitches, (ParseTurnout(httpsGET(getip.."/turnout"))))
    elseif ParseLight(httpGET(getip.."/light/ILFindSwitches")) then -- One off Find switches
        httpPOST(getip.."/light/ILFindSwitches", buildLight("ILFindSwitches", false))-- Set Web FindSwitches to false
        print("Finding Switches")
        CurrSwitches = compareTables(FindSwitches())
        compareWeb(CurrSwitches, (ParseTurnout(httpsGET(getip.."/turnout"))))
    elseif ParseLight(httpGET(getip.."/light/ILUpdateSwitches")) then -- Only updates current switches
        compareWebState(CurrSwitches, (ParseTurnout(httpsGET(getip.."/turnout"))))
    end
    os.sleep(CONFIG.wait)
    term.clear()
end