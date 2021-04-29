local component = require("component")
local internet = require("internet")
local term = require ("term")
local json = require("json")
local world = component.world_link
local TcpIP = "84.65.32.30"
local TcpSendPort = 6668
local wait = 10
 
function sendtcp(tosend)
    if (con) then                
        con:write("#04,"..tosend.."\r\n")
        con:flush()
        end
end
 
function recvtcp()
    data = nil
    local decoded = nil
    if (con) then 
        index = con:read(10)
        length = tonumber(index)
        data = con:read(length)
        if data ~= nil then
            decoded = json:decode(data)
            end
        con:write("#0Q,\r\n")
        con:flush()
        end
    return decoded
end
 
function changeRed(data)
    for i, redbox in pairs(data) do
        x = redbox.posit_array.x
        y = redbox.posit_array.y
        z = redbox.posit_array.z
        location = world.getLocationByCoordinates(x,y,z)
        a = location.getTileEntities().whereProperty("type", "automation:redstone_box").asList()
        if a ~= nil then
            b = a[1]
            c = b.getAPI("automation:redstone_box")
            c.setPowerLevel(redbox.output)
            print("Set: ",x,y,z,"To: ",output)
            end
        end
    end
 
function overArray()
    local b = {}
    local data = nil
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
            a["posit_array"] = c
            a["output"] = output
            table.insert(b,1,a)
            count = count + 1
            os.sleep(0.1)
            end
        end
    data = json:encode(b)
    if data == "" then
        data = nil
        end
    return data
end
 
-- MAIN --
 
while true do
    xdata = overArray()
    if xdata ~= nil then
        con = internet.open(TcpIP,TcpSendPort)
        sendtcp(xdata)
        response = recvtcp()
        end
    if response ~= nil then
        changeRed(response)
        end
    print(os.date(" %I:%M %p"))
    print("Redboxes sent: ", count)
    print("-----")
    os.sleep(wait)
end