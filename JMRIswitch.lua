local component = require("component")
local internet = require("internet")
local serial = require("serialization")
local fs = require("filesystem")
local term = require ("term")
local json = require("json")
local CONFIG_FILE = "/home/settings.cfg"
local SWITCH_TABLE = "/home/switchtable.tbl"
local CONFIG = {}
local DEFAULT_CONFIG = {ip = "84.65.32.30",port = "12080", wait = 1}
local world = component.world_link
local wait = 1
local chunkLoad = true
 
local function httpGET(ip)
    local atable = {}
    local decoded = ""
    local result = ""
    local handle = internet.request(ip,"",{},"GET")
    if handle == nil then
        print("failed to connect")
    else
        local mt = getmetatable(handle)
        local code, message, headers = mt.__index.response()
        --if code == 200 then
        l = json:encode(headers)
        n = "Code: "..(tostring(code))..", message: "..(tostring(message))..", headers: "..l
        --print(n)
        --print("-------")
        for chunk in handle do result = result .. chunk end
        --print(result)
        decoded = json:decode(result)
    end
    return decoded
end

local function httpsGET(ip)
    local atable = {}
    local decoded = ""
    local result = ""
    local handle = internet.request(ip)
    if handle == nil then
        print("failed to connect")
    else
        local mt = getmetatable(handle)
        local code, message, headers = mt.__index.response()
        --if code == 200 then
        l = json:encode(headers)
        n = "Code: "..(tostring(code))..", message: "..(tostring(message))..", headers: "..l
        --print(n)
        --print("-------")
        for chunk in handle do result = result .. chunk end
        --print(result)
        decoded = json:decode(result)
    end
    return decoded
end

function httpPUT(ip, data)
    local encoded = json:encode(data)
    local header = {["Content-Type"] = "application/json;charset=utf-8"}
    local result = ""
    local handle = internet.request(ip, encoded, header, "PUT")
    if handle == nil then
        print("failed to connect")
    end
end

function httpPOST(ip, data)
    local encoded = json:encode(data)
    local header = {["Content-Type"] = "application/json;charset=utf-8"}
    local handle = internet.request(ip, encoded, header, "POST")
    if handle == nil then
        print("failed to connect")
    end
end
 
function saveFile(file, data)
    local f = io.open(file, "w")
    if f == nil then error("Couldn't open " .. file .. " to write config.") end
    f:write(serial.serialize(data, 100000))
    f:close()
end

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

function compareWeb(CurrSwitches, WebSwitches)
    --for i,v in pairs(WebSwitches) do print(i,v) end
    for name, data in pairs(CurrSwitches) do
        if WebSwitches[name] == nil then
            --print(name, data.state)
            --print(buildTurnout(name,name, data.state))
            httpPUT(getip.."/turnout", buildTurnout(name,name, data.state))
        end
    end
end

function compareWebState(CurrSwitches, WebSwitches)
    for name, data in pairs(CurrSwitches) do
        if WebSwitches[name] ~= nil then
            --print(name, data.state)
            if WebSwitches[name] ~= data.state then
                x = data.position.x
                y = data.position.y
                z = data.position.z
                location = world.getLocationByCoordinates(x,y,z)
                flag = false
                if CONFIG.chunkLoad then 
                    if location.isLoaded() == false then 
                        location.getChunk().forceLoad() 
                        os.sleep(0.1)
                        flag = true
                    end
                end
                a = location.getTileEntities().whereProperty("type", "automation:redstone_box").asList()
                if #a == 1 then
                    b = a[1]
                    c = b.getAPI("automation:redstone_box")
                    out = 0
                    if WebSwitches[name] then out = 15 end
                    c.setPowerLevel(out)
                    if flag then 
                        os.sleep(0.1)
                        location.getChunk().unforceLoad()
                    end
                    print("Set: ",x,y,z,"To: ",out)
                    CurrSwitches[name].state = WebSwitches[name]
                end
            end    
        end
    end
end


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
 
function ParseLight(x)
    name = x["data"]["name"]
    state = x["data"]["state"]
    return JLstate(state)
end

function ParseTurnout(x)
    xtable = {}
    for i,v in pairs(x) do
        name = v["data"]["name"]
        name = string.sub( name, 3 )
        username = v["data"]["userName"]
        comment = v["data"]["comment"]
        inverted = v["data"]["inverted"]
        state = JTstate(v["data"]["state"])
        --print("Name: ",name,", Inverted: ", inverted,", State: ", state)
        if name ~= nil then
            xtable[name] = state
        end
    end
    return xtable
end

function buildTurnout(name, comment, state)
    setstate = 2
    if state == true then setstate = 4 end
    out = {
        type="turnout",
        data= {name="IT"..name,state=setstate}
    }
    return out
end

function buildLight(name, state)
    setstate = 4
    if state == true then setstate = 2 end
    out = {
        type="light",
        data={name=name,state=setstate},

      }
    return out
end

function JTstate(x) -- JMRI Turnout state to true or false
    local out = false
    if x == 4 then
        out = true
    end
    return out
end

function JLstate(x) -- JMRI Light state to true or false, they are backwards...
    local out = false
    if x == 2 then
        out = true
    end
    return out
end

function Rstate(x) -- Redstone state to true or false
    local out = false
    if x == 15 then
        out = true
    end
    return out
end

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
        print("Do you want to adjust the settings? [y/n]")
        local choice = io.read()
        if choice == "y" or choice == "yes" then
            CONFIG = getSettings()
        end
        if CONFIG == nil then
            CONFIG = loadConfig(CONFIG_FILE)
            saveFile(CONFIG_FILE,CONFIG)
        else
            print("Saving to "..CONFIG_FILE..".")
            saveFile(CONFIG_FILE,CONFIG)
        end
    end
    return CONFIG
end

-- MAIN --
-- Load swtichtable is found, if not, find switches

CONFIG = startup()

CurrSwitches = loadFile(SWITCH_TABLE)
if CurrSwitches == nil then
    CurrSwitches = FindSwitches()
    saveFile(SWITCH_TABLE, CurrSwitches)
end
local getip = "http://"..CONFIG.ip..":"..CONFIG.port.."/json"
term.clear()

while true do
    print(os.date(" %I:%M %p"))
    if ParseLight(httpGET(getip.."/light/ILFindSwitches")) then
        -- Set Web FindSwitches to false
        httpPOST(getip.."/light/ILFindSwitches", buildLight("ILFindSwitches", false))
        print("Finding Switches")
        CurrSwitches = compareTables(FindSwitches())
        compareWeb(CurrSwitches, (ParseTurnout(httpsGET(getip.."/turnout"))))
    end
    if ParseLight(httpGET(getip.."/light/ILUpdateSwitches")) then
        compareWebState(CurrSwitches, (ParseTurnout(httpsGET(getip.."/turnout"))))
    end
    --print("-----")
    os.sleep(CONFIG.wait)
    term.clear()
end