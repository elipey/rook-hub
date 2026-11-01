-- Luau / Core.luau / Luau 0.7+ e Roblox / Rook Hub
-- Regras puras: nao acessam jogo, rede, arquivos ou interfaces.
local Core = {}
Core.version = "2.0.1"
Core.defaults = {
    mode = "Off", sea = "Auto", weapon = "", masteryWeapon = "", enemy = "",
    material = "Bones", event = "Sea Beast", player = "", fruit = "",
    toggleKey = "RightShift", moveSpeed = 100, walkSpeed = 32, flySpeed = 70,
    distance = 6, height = 2, attackInterval = 0.25, searchRadius = 2500,
    masteryHealth = 25, pauseHealth = 15, projectileSpeed = 160, predictionLimit = 0.8,
    aimRadius = 240, skillInterval = 6, skillKeys = "Z,X,C", hopAfter = 180,
    buyBudget = 1000000, buyLimit = 1, randomInterval = 7200, espLimit = 60,
    attack = false, skills = false, mastery = false, bossQuest = true, replaceQuest = false,
    aura = false, aim = false, espPlayers = false, espFruits = false, espEnemies = false,
    espChests = false, fly = false, noclip = false, speed = false, antiAfk = false,
    fullbright = false, autoBuy = false, autoRandom = false, autoStore = false,
    autoHop = false, haki = false,
}
Core.bounds = {
    moveSpeed={10,250}, walkSpeed={16,100}, flySpeed={10,180}, distance={2,30}, height={0,40},
    attackInterval={0.12,2}, searchRadius={50,20000}, masteryHealth={5,95}, pauseHealth={0,80},
    projectileSpeed={1,3000}, predictionLimit={0,2}, aimRadius={30,1200}, skillInterval={0.5,60},
    hopAfter={60,3600}, buyBudget={0,100000000}, buyLimit={1,20}, randomInterval={7200,86400}, espLimit={5,100},
}
Core.enums = {
    mode={"Off","Level","Nearest","Boss","Material","Fruit","Chest","Player","Event","Raid"},
    sea={"Auto","1","2","3"}, material={"Bones","Ectoplasm","Candy","Custom"},
    event={"Sea Beast","Ghost Ship","Leviathan"},
}
function Core.finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
function Core.cleanName(value)
    return tostring(value):gsub("%b[]", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end
function Core.contains(text, needle)
    return tostring(text):lower():find(tostring(needle):lower(),1,true) ~= nil
end
function Core.config(input, restore)
    local output = {}
    input = type(input)=="table" and input or {}
    for key, default in pairs(Core.defaults) do
        local value = input[key]
        if type(value) ~= type(default) then value = default end
        if type(default)=="number" then
            if not Core.finite(value) then value=default end
            local bounds=Core.bounds[key]
            if bounds then value=math.clamp(value,bounds[1],bounds[2]) end
        elseif type(default)=="string" then value=value:sub(1,160) end
        if Core.enums[key] and not table.find(Core.enums[key],value) then value=default end
        -- Perfis guardam preferencias, nunca reativam compras/movimento/ataques.
        if restore and type(default)=="boolean" then value=default end
        output[key]=value
    end
    if restore then output.mode="Off" end
    return output
end
function Core.keys(text)
    local result, seen={},{}
    for key in tostring(text):upper():gmatch("[ZXCVF]") do
        if not seen[key] then seen[key]=true; table.insert(result,key) end
    end
    return result
end
function Core.world(placeId, override)
    if override and override~="Auto" then return tonumber(override) end
    return ({[2753915549]=1,[4442272183]=2,[7449423635]=3,[85211729168715]=1})[placeId]
end
function Core.inSea(level, sea)
    if sea==1 then return level>=0 and level<700 end
    if sea==2 then return level>=700 and level<1500 end
    if sea==3 then return level>=1500 end
    return false
end
function Core.questRecords(raw)
    local result={}
    if type(raw)~="table" then return result end
    local excluded={BartiloQuest=true,CitizenQuest=true,MarineQuest=true}
    for id, missions in pairs(raw) do
        if type(id)=="string" and type(missions)=="table" and not excluded[id] then
            for index, mission in pairs(missions) do
                if type(index)=="number" and type(mission)=="table" and Core.finite(mission.LevelReq) and type(mission.Task)=="table" then
                    local count,enemy,amount=0,nil,nil
                    for name,quantity in pairs(mission.Task) do
                        count=count+1
                        if type(name)=="string" and Core.finite(quantity) and quantity>0 then enemy,amount=name,quantity end
                    end
                    if count==1 and enemy then
                        table.insert(result,{id=id,index=index,level=mission.LevelReq,enemy=enemy,amount=amount})
                    end
                end
            end
        end
    end
    table.sort(result,function(a,b)
        if a.level~=b.level then return a.level<b.level end
        if a.id~=b.id then return a.id<b.id end
        return a.index<b.index
    end)
    return result
end
function Core.chooseQuest(records, level, sea, bossName)
    local chosen
    for _,quest in ipairs(records) do
        local wanted = bossName and Core.cleanName(quest.enemy)==Core.cleanName(bossName) or not bossName and quest.amount>1
        if wanted and quest.level<=level and Core.inSea(quest.level,sea) then
            if not chosen or quest.level>chosen.level then chosen=quest end
        end
    end
    return chosen
end
function Core.pickServer(data, current, visited, low)
    local choices={}
    for _,server in ipairs(type(data)=="table" and data or {}) do
        if type(server)=="table" and type(server.id)=="string" and server.id~=current and not visited[server.id]
            and Core.finite(server.playing) and Core.finite(server.maxPlayers)
            and server.playing>=0 and server.playing<server.maxPlayers then
            table.insert(choices,server)
        end
    end
    table.sort(choices,function(a,b)
        if low and a.playing~=b.playing then return a.playing<b.playing end
        return a.id<b.id
    end)
    return choices[1]
end
return Core
