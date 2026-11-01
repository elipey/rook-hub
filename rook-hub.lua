-- Luau / rook-hub.lua / Roblox client PC / Blox Fruits - compatibilidade ao vivo nao verificada

-- ===== MODULO: Core =====
local Core = (function()
-- Luau / Core.luau / Luau 0.7+ e Roblox / Rook Hub
-- Regras puras: nao acessam jogo, rede, arquivos ou interfaces.
local Core = {}
Core.version = "2.0.0"
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

end)()

-- ===== MODULO: Runtime =====
local Runtime = (function()
-- Luau / Runtime.luau / Roblox client / Rook Hub
-- Ciclo de vida, agendamento, preferencias e chamadas com limite de frequencia.
return function(Core)
    local C={Core=Core, alive=true, links={}, jobs={}, logs={}, disposers={}, threads={}, epoch=0}
    for _,name in ipairs({"Players","RunService","UserInputService","ReplicatedStorage","HttpService","TeleportService","Lighting","CollectionService"}) do C[name]=game:GetService(name) end
    C.player=C.Players.LocalPlayer
    assert(C.player,"Rook Hub precisa ser executado no cliente.")
    C.playerGui=C.player:WaitForChild("PlayerGui",15)
    assert(C.playerGui,"PlayerGui indisponivel.")
    local previous=C.playerGui:FindFirstChild("RookHub")
    if previous then
        local event=previous:FindFirstChild("Shutdown")
        if event then event:Fire(); task.wait() else previous:Destroy() end
    end
    C.config=Core.config()
    C.state={status="Pronto",mode="Off",emptySince=os.clock(),fps=60,started=os.clock(),requests=0,errors=0}
    C.gui=Instance.new("ScreenGui")
    C.gui.Name="RookHub"; C.gui.ResetOnSpawn=false; C.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    C.gui.DisplayOrder=50; C.gui.Parent=C.playerGui
    local shutdown=Instance.new("BindableEvent"); shutdown.Name="Shutdown"; shutdown.Parent=C.gui
    function C:connect(signal,callback)
        local link=signal:Connect(callback); table.insert(self.links,link); return link
    end
    function C:log(message)
        message=tostring(message):sub(1,500)
        if self.logs[#self.logs] and self.logs[#self.logs].message==message then return end
        table.insert(self.logs,{time=os.date("%H:%M:%S"),message=message})
        if #self.logs>80 then table.remove(self.logs,1) end
    end
    function C:status(message) self.state.status=message end
    function C:notify(message) self:status(message); self:log(message) end
    function C:character()
        local model=self.player.Character
        return model,model and model:FindFirstChild("HumanoidRootPart"),model and model:FindFirstChildOfClass("Humanoid")
    end
    function C:level()
        local data=self.player:FindFirstChild("Data"); local value=data and data:FindFirstChild("Level")
        return value and tonumber(value.Value) or 0
    end
    function C:sea() return Core.world(game.PlaceId,self.config.sea) end
    function C:set(key,value)
        local previousValue=self.config[key]
        local updated=table.clone(self.config); updated[key]=value; self.config=Core.config(updated)
        if key=="mode" and previousValue~=self.config.mode then
            self.state.mode=self.config.mode; self.state.target=nil; self.state.destination=nil
            self.state.quest=nil; self.state.emptySince=os.clock(); self.epoch=self.epoch+1
            if self.config.mode~="Off" then self.config.fly=false end
        end
        if key=="fly" and self.config.fly then
            self.config.mode="Off"; self.state.destination=nil; self.state.target=nil; self.epoch=self.epoch+1
        end
        if self.refresh then self.refresh() end
    end
    function C:stop()
        for key,value in pairs(self.config) do if type(value)=="boolean" then self.config[key]=false end end
        self.config.mode="Off"; self.state.mode="Off"; self.state.target=nil; self.state.destination=nil
        self.state.quest=nil; self.epoch=self.epoch+1
        for _,reset in ipairs(self.disposers) do pcall(reset) end
        if self.refresh then self.refresh() end
        self:notify("Tudo parado. Chamadas ja enviadas ao servidor nao podem ser desfeitas.")
    end
    function C:destroy()
        if not self.alive then return end
        self:stop(); self.alive=false
        for _,link in ipairs(self.links) do link:Disconnect() end
        for thread in pairs(self.threads) do pcall(task.cancel,thread) end
        self.gui:Destroy()
    end
    function C:spawn(callback)
        local thread
        thread=task.defer(function()
            local ok,problem=pcall(callback)
            if not ok and self.alive then self:log(problem) end
            if thread then self.threads[thread]=nil end
        end)
        self.threads[thread]=true
        return thread
    end
    function C:job(name,interval,callback)
        table.insert(self.jobs,{name=name,interval=interval,next=0,callback=callback,failures=0})
    end
    -- Nao existe uma coroutine infinita por botao; todos os trabalhos usam este relogio.
    C:connect(C.RunService.Heartbeat,function(dt)
        if not C.alive then return end
        C.state.fps=C.state.fps*0.9+math.min(240,1/math.max(dt,0.001))*0.1
        local now=os.clock()
        for _,job in ipairs(C.jobs) do
            if now>=job.next then
                job.next=now+job.interval
                local ok,problem=pcall(job.callback,now,dt)
                if not ok then
                    job.failures=job.failures+1; C.state.errors=C.state.errors+1
                    C:log(job.name..": "..tostring(problem))
                    if job.failures>=3 then
                        job.next=math.huge; C:stop(); C:notify("Modulo interrompido apos 3 falhas: "..job.name)
                    end
                else job.failures=0 end
            end
        end
    end)
    C:connect(shutdown.Event,function() C:destroy() end)
    C:connect(C.gui.Destroying,function() C:destroy() end)
    C:connect(C.player.CharacterAdded,function()
        C.state.target=nil; C.state.destination=nil; C.epoch=C.epoch+1
        for _,reset in ipairs(C.disposers) do pcall(reset) end
    end)
    C:connect(C.UserInputService.InputBegan,function(input,processed)
        if processed or C.UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode.Name==C.config.toggleKey and C.panel then C.panel.Visible=not C.panel.Visible end
        if input.KeyCode==Enum.KeyCode.End then C:stop() end
    end)
    local remoteState={busy=false,last={},blocked=false}
    C.remoteState=remoteState
    local allowed={StartQuest=3,AbandonQuest=3,Buso=8,GetFruits=30,PurchaseRawFruit=15,Cousin=60,StoreFruit=4,
        TravelMain=10,TravelDressrosa=10,TravelZou=10,RaidsNpc=15}
    function C:remote(command,args,callback)
        local gap=allowed[command]
        if not gap then self:log("Comando nao permitido pelo adaptador: "..tostring(command)); return false end
        if remoteState.busy or remoteState.blocked then return false end
        local now=os.clock()
        if now-(remoteState.last[command] or -math.huge)<gap then return false end
        local folder=self.ReplicatedStorage:FindFirstChild("Remotes")
        local remote=folder and folder:FindFirstChild("CommF_")
        if not remote or not remote:IsA("RemoteFunction") then self:notify("Remotes.CommF_ nao encontrado."); return false end
        remoteState.busy=true; remoteState.since=now; remoteState.last[command]=now
        local epoch=self.epoch
        remoteState.thread=self:spawn(function()
            local ok,result=pcall(function() return remote:InvokeServer(command,table.unpack(args or {})) end)
            remoteState.busy=false; remoteState.thread=nil
            self.state.requests=self.state.requests+1
            if not self.alive then return end
            if not ok then self:log(command..": "..tostring(result)) end
            if callback and epoch==self.epoch then callback(ok,result) end
        end)
        return true
    end
    C:job("remote-watchdog",1,function(now)
        if remoteState.busy and now-remoteState.since>15 then
            remoteState.blocked=true; remoteState.busy=false
            if remoteState.thread then pcall(task.cancel,remoteState.thread); C.threads[remoteState.thread]=nil end
            C:stop(); C:notify("Servidor sem resposta ha 15s. Canal bloqueado; reexecute para reconectar.")
        end
    end)
    function C:save()
        if type(writefile)~="function" or type(makefolder)~="function" then self:notify("Executor sem escrita de arquivos."); return end
        local ok,problem=pcall(function()
            if type(isfolder)~="function" or not isfolder("RookHub") then pcall(makefolder,"RookHub") end
            writefile("RookHub/profile-v2.json",self.HttpService:JSONEncode({version=2,config=self.config}))
        end)
        self:notify(ok and "Preferencias salvas." or "Falha ao salvar: "..tostring(problem))
    end
    function C:load()
        if type(readfile)~="function" then self:notify("Executor sem leitura de arquivos."); return end
        local ok,result=pcall(function() return self.HttpService:JSONDecode(readfile("RookHub/profile-v2.json")) end)
        if not ok or type(result)~="table" or result.version~=2 then self:notify("Perfil ausente ou incompativel."); return end
        self:stop(); self.config=Core.config(result.config,true)
        if self.refresh then self.refresh() end
        self:notify("Preferencias carregadas; automacoes permanecem desligadas.")
    end
    function C:diagnostic()
        local lines={"Rook Hub "..Core.version,"Place: "..game.PlaceId,"Sea: "..tostring(self:sea()),
            "Level: "..self:level(),"Modo: "..self.config.mode,"FPS: "..math.floor(self.state.fps),
            "Requests: "..self.state.requests,"Remote bloqueado: "..tostring(remoteState.blocked)}
        for _,entry in ipairs(self.logs) do table.insert(lines,entry.time.." "..entry.message) end
        local text=table.concat(lines,"\n")
        if type(setclipboard)=="function" then
            local ok=pcall(setclipboard,text); self:notify(ok and "Diagnostico copiado." or "Clipboard indisponivel.")
        else print(text); self:notify("Diagnostico enviado ao console F9.") end
    end
    C:log("Sessao iniciada. Integracoes de jogo exigem validacao nesta versao.")
    return C
end

end)()

-- ===== MODULO: World =====
local World = (function()
-- Luau / World.luau / Roblox client / Blox Fruits
-- Adaptador isolado: nomes e formatos internos do jogo podem mudar.
return function(C)
    local Core=C.Core
    local W={index={fruits={},chests={},events={},locations={},race={},spawns={}},quests={},ready=false,guide=nil}
    C.world=W
    function W:part(object)
        if not object or not object.Parent then return nil end
        if object:IsA("BasePart") then return object end
        if object:IsA("Model") then return object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart",true) end
        if object:IsA("Tool") then return object:FindFirstChild("Handle") end
        return nil
    end
    function W:position(value)
        if typeof(value)=="CFrame" then return value.Position end
        if typeof(value)=="Vector3" then return value end
        if typeof(value)=="Instance" then local part=self:part(value); return part and part.Position end
        return nil
    end
    local function classify(object)
        if not object.Parent then return end
        local name=object.Name:lower()
        local physical=object:IsA("BasePart") or object:IsA("Model")
        if object:IsA("Tool") and name:find("fruit",1,true) and object:IsDescendantOf(workspace) then
            if not object.Parent:FindFirstChildOfClass("Humanoid") then W.index.fruits[object]=true end
        end
        if not physical then return end
        local parentIsChest=(object.Parent:IsA("Model") or object.Parent:IsA("BasePart"))
            and object.Parent.Name:lower():match("^chest") and object.Parent.Name:lower()~="chestmodels"
        if name:match("^chest") and name~="chestmodels" and not parentIsChest then W.index.chests[object]=true end
        if object:IsA("Model") then
            local compact=name:gsub("[%s_%-]","")
            if compact:find("seabeast",1,true) then W.index.events[object]="Sea Beast"
            elseif compact:find("ghostship",1,true) or compact:find("piratebrigade",1,true) then W.index.events[object]="Ghost Ship"
            elseif compact:find("leviathan",1,true) then W.index.events[object]="Leviathan" end
        end
        if object.Parent.Name=="Locations" or object.Parent==workspace:FindFirstChild("Map") then W.index.locations[object]=true end
        if name:find("mirage",1,true) or name:find("temple",1,true) or name:find("gear",1,true) or name:find("trial",1,true) then W.index.race[object]=true end
        if object.Parent.Name=="EnemySpawns" or object.Parent.Name=="FortBuilderReplicatedSpawnPositionsFolder" then W.index.spawns[object]=true end
    end
    C:connect(workspace.DescendantAdded,classify)
    C:connect(workspace.DescendantRemoving,function(object)
        for _,bucket in pairs(W.index) do bucket[object]=nil end
    end)
    -- Uma descoberta inicial, processada em lotes. Depois, apenas sinais incrementais.
    local initial=workspace:GetDescendants()
    local scanCursor=1
    C:job("index-initial",0.03,function()
        if not initial then return end
        for _=1,250 do
            local object=initial[scanCursor]
            if not object then initial=nil; C:log("Indice inicial concluido."); break end
            classify(object); scanCursor=scanCursor+1
        end
    end)
    local spawnFolder=C.ReplicatedStorage:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
    if spawnFolder then
        for _,object in ipairs(spawnFolder:GetChildren()) do classify(object) end
        C:connect(spawnFolder.ChildAdded,classify)
        C:connect(spawnFolder.ChildRemoved,function(object) W.index.spawns[object]=nil end)
    end
    function W:loadModules()
        if self.loading then return end
        self.loading=true; self.loadStarted=os.clock()
        self.loadThread=C:spawn(function()
            local questModule=C.ReplicatedStorage:FindFirstChild("Quests")
            local guideModule=C.ReplicatedStorage:FindFirstChild("GuideModule")
            if not questModule or not guideModule or not questModule:IsA("ModuleScript") or not guideModule:IsA("ModuleScript") then
                self.loading=false; C:notify("Modulos Quests/GuideModule indisponiveis. Farm por nivel bloqueado."); return
            end
            local ok,quests=pcall(require,questModule)
            local guideOk,guide=pcall(require,guideModule)
            self.loading=false
            if not ok or not guideOk or type(guide)~="table" then C:notify("Executor nao conseguiu ler os modulos de quests."); return end
            self.quests=Core.questRecords(quests); self.guide=guide
            self.ready=#self.quests>0
            C:notify("Quests detectadas: "..#self.quests..". Formato ainda requer teste no jogo.")
        end)
    end
    C:job("module-watchdog",1,function(now)
        if W.loading and now-W.loadStarted>10 then
            pcall(task.cancel,W.loadThread); C.threads[W.loadThread]=nil; W.loading=false
            C:notify("Leitura de modulos excedeu 10s. Use Recarregar adaptador para tentar novamente.")
        end
    end)
    function W:questPosition(quest)
        local data=self.guide and self.guide.Data
        local list=data and data.NPCList
        if type(list)~="table" then return nil end
        local positions={}
        for key,npc in pairs(list) do
            if type(npc)=="table" then
                local pos=self:position(npc.Position) or self:position(npc.CFrame) or self:position(key)
                if type(key)=="table" then pos=pos or self:position(key.CFrame) end
                local matched=false
                for _,value in pairs(npc) do if value==quest.id then matched=true end end
                if matched and pos then return pos end
                if pos and type(npc.Levels)=="table" then
                    for _,level in pairs(npc.Levels) do if level==quest.level then table.insert(positions,pos); break end end
                end
            end
        end
        -- Nao adivinhar entre dois NPCs com o mesmo nivel em locais diferentes.
        if #positions>0 then
            for i=2,#positions do if (positions[i]-positions[1]).Magnitude>30 then return nil end end
            return positions[1]
        end
        return nil
    end
    function W:questState(quest)
        local main=C.playerGui:FindFirstChild("Main")
        local panel=main and main:FindFirstChild("Quest")
        if not panel or not panel:IsA("GuiObject") then return "unknown" end
        if not panel.Visible then return "none" end
        local data=self.guide and self.guide.Data
        local taskData=data and data.QuestData and data.QuestData.Task
        if type(taskData)=="table" then
            for name in pairs(taskData) do if Core.cleanName(name)==Core.cleanName(quest.enemy) then return "match" end end
        end
        for _,label in ipairs(panel:GetDescendants()) do
            if label:IsA("TextLabel") and Core.contains(label.Text,quest.enemy) then return "match" end
        end
        return "other"
    end
    function W:enemies()
        local folder=workspace:FindFirstChild("Enemies")
        return folder and folder:GetChildren() or {}
    end
    function W:isBoss(enemy)
        if Core.contains(enemy.Name,"boss") then return true end
        for _,quest in ipairs(self.quests) do
            if quest.amount==1 and Core.cleanName(quest.enemy)==Core.cleanName(enemy.Name) then return true end
        end
        return enemy:GetAttribute("Boss")==true
    end
    function W:alive(object)
        if not object or not object.Parent then return false end
        local humanoid=object:FindFirstChildOfClass("Humanoid")
        if humanoid then return humanoid.Health>0 end
        local health=object:FindFirstChild("Health")
        if health and (health:IsA("NumberValue") or health:IsA("IntValue")) then return health.Value>0 end
        local attribute=object:GetAttribute("Health")
        if Core.finite(attribute) then return attribute>0 end
        return false
    end
    function W:nearest(bucket,position,predicate,range)
        local best,bestDistance=nil,range or math.huge
        for key,value in pairs(bucket) do
            local object=typeof(key)=="Instance" and key or value
            local part=self:part(object)
            if part and (not predicate or predicate(object,value)) then
                local distance=(part.Position-position).Magnitude
                if distance<bestDistance then best,bestDistance=object,distance end
            end
        end
        return best,bestDistance
    end
    function W:spawnFor(name,position)
        local object=self:nearest(self.index.spawns,position,function(item) return Core.cleanName(item.Name)==Core.cleanName(name) end)
        local part=self:part(object)
        return part and part.Position
    end
    function W:tools()
        local result={}
        local backpack=C.player:FindFirstChildOfClass("Backpack")
        for _,folder in pairs({C.player.Character,backpack}) do
            for _,tool in ipairs(folder:GetChildren()) do if tool:IsA("Tool") then table.insert(result,tool) end end
        end
        return result
    end
    function W:locationNames(kind)
        local names={}
        for object in pairs(self.index[kind]) do if object.Parent then table.insert(names,object.Name) end end
        table.sort(names)
        return table.concat(names,", ")
    end
    W:loadModules()
    return W
end

end)()

-- ===== MODULO: MotionCombat =====
local MotionCombat = (function()
-- Luau / MotionCombat.luau / Roblox client / Rook Hub
-- Movimento com um unico proprietario; ataques respeitam Tool.Enabled e intervalo.
return function(C)
    local W,Core=C.world,C.Core
    local M={collisions={},originals={},keys={},skillTimes={},lastAttack=0,skillCursor=1}
    C.motion=M
    local inputOk,virtualInput=pcall(game.GetService,game,"VirtualInputManager")
    if not inputOk then virtualInput=nil end
    local function releaseKeys()
        if virtualInput then
            for key in pairs(M.keys) do pcall(function() virtualInput:SendKeyEvent(false,Enum.KeyCode[key],false,game) end) end
        end
        table.clear(M.keys)
    end
    local function restore()
        releaseKeys()
        for part,collidable in pairs(M.collisions) do if part.Parent then part.CanCollide=collidable end end
        table.clear(M.collisions)
        for humanoid,values in pairs(M.originals) do
            if humanoid.Parent then humanoid.WalkSpeed=values.speed; humanoid.AutoRotate=values.rotate end
        end
        table.clear(M.originals)
        if M.velocity then M.velocity:Destroy(); M.velocity=nil end
        if M.attachment then M.attachment:Destroy(); M.attachment=nil end
        M.lastPosition=nil; M.corrections=0; M.aimTarget=nil
    end
    table.insert(C.disposers,restore)
    function M:go(position,owner,lookAt,radius)
        if typeof(position)~="Vector3" then return end
        C.state.destination={position=position,owner=owner,lookAt=lookAt,radius=radius or 3}
    end
    function M:travelTo(position)
        C:set("mode","Off"); C:set("fly",false); C.state.target=nil
        self:go(position,"manual"); C:notify("Navegando para o destino selecionado.")
    end
    function M:equip(name)
        local model,_,humanoid=C:character()
        if not humanoid then return nil end
        if not name or name=="" then return model:FindFirstChildOfClass("Tool") end
        for _,tool in ipairs(W:tools()) do
            if tool.Name==name or tool.ToolTip==name then
                if tool.Parent~=model then humanoid:EquipTool(tool) end
                return tool
            end
        end
        return nil
    end
    function M:playerTarget()
        local _,root=C:character()
        if not root then return nil end
        local wanted=C.config.player:lower()
        local matches={}
        for _,player in ipairs(C.Players:GetPlayers()) do
            if player~=C.player and W:alive(player.Character) then
                if wanted=="" or player.Name:lower()==wanted or player.DisplayName:lower()==wanted then table.insert(matches,player.Character) end
            end
        end
        if wanted~="" and #matches>1 then C:status("Nickname ambiguo; informe o username exato."); return nil end
        return W:nearest(matches,root.Position,nil,C.config.searchRadius)
    end
    local function pulse(key,now)
        if not virtualInput or M.keys[key] then return false end
        local ok=pcall(function() virtualInput:SendKeyEvent(true,Enum.KeyCode[key],false,game) end)
        if not ok then C:set("skills",false); C:notify("Executor bloqueou entrada virtual de habilidades."); return false end
        M.keys[key]=now+0.06
        return true
    end
    C:connect(C.RunService.PreSimulation,function(dt)
        if not C.alive then return end
        local ok,problem=pcall(function()
            local model,root,humanoid=C:character()
            if not root or not humanoid or humanoid.Health<=0 then return end
            local config=C.config
            if not M.originals[humanoid] and (config.speed or config.fly) then
                M.originals[humanoid]={speed=humanoid.WalkSpeed,rotate=humanoid.AutoRotate}
            end
            local original=M.originals[humanoid]
            if config.speed then humanoid.WalkSpeed=config.walkSpeed
            elseif original then humanoid.WalkSpeed=original.speed end
            if config.noclip then
                for _,part in ipairs(model:GetChildren()) do
                    if part:IsA("BasePart") then
                        if M.collisions[part]==nil then M.collisions[part]=part.CanCollide end
                        part.CanCollide=false
                    end
                end
            elseif next(M.collisions) then
                for part,collidable in pairs(M.collisions) do if part.Parent then part.CanCollide=collidable end end
                table.clear(M.collisions)
            end
            if config.fly then
                if not M.attachment or M.attachment.Parent~=root then
                    if M.velocity then M.velocity:Destroy() end
                    if M.attachment then M.attachment:Destroy() end
                    M.attachment=Instance.new("Attachment"); M.attachment.Parent=root
                    M.velocity=Instance.new("LinearVelocity"); M.velocity.Attachment0=M.attachment
                    M.velocity.RelativeTo=Enum.ActuatorRelativeTo.World; M.velocity.MaxForce=1000000; M.velocity.Parent=root
                end
                humanoid.AutoRotate=false
                local vector=Vector3.zero
                local camera=workspace.CurrentCamera
                if camera and not C.UserInputService:GetFocusedTextBox() then
                    local function down(key) return C.UserInputService:IsKeyDown(Enum.KeyCode[key]) and 1 or 0 end
                    vector=camera.CFrame.LookVector*(down("W")-down("S"))+camera.CFrame.RightVector*(down("D")-down("A"))+Vector3.yAxis*(down("E")-down("Q"))
                end
                M.velocity.VectorVelocity=vector.Magnitude>0 and vector.Unit*config.flySpeed or Vector3.zero
                return
            elseif M.velocity then
                M.velocity:Destroy(); M.velocity=nil; M.attachment:Destroy(); M.attachment=nil
                if original then humanoid.AutoRotate=original.rotate end
            end
            local destination=C.state.destination
            if not destination or C.state.paused then M.lastPosition=nil; return end
            if M.lastPosition and (root.Position-M.lastPosition).Magnitude>math.max(80,config.moveSpeed*dt*3) then
                M.corrections=(M.corrections or 0)+1
                if M.corrections>=3 then C:stop(); C:notify("Movimento corrigido repetidamente pelo servidor. Navegacao interrompida."); return end
            end
            local delta=destination.position-root.Position
            if delta.Magnitude<=destination.radius then C.state.destination=nil; M.lastPosition=nil; return end
            local position=root.Position+delta.Unit*math.min(delta.Magnitude,config.moveSpeed*math.min(dt,0.05))
            local look=destination.lookAt or position+root.CFrame.LookVector
            if (look-position).Magnitude<0.01 then look=position+Vector3.zAxis end
            root.CFrame=CFrame.lookAt(position,look); root.AssemblyLinearVelocity=Vector3.zero
            M.lastPosition=position
        end)
        if not ok then C:stop(); C:notify("Movimento interrompido: "..tostring(problem)) end
    end)
    C:job("combat",0.05,function(now)
        for key,deadline in pairs(M.keys) do
            if now>=deadline then
                pcall(function() virtualInput:SendKeyEvent(false,Enum.KeyCode[key],false,game) end); M.keys[key]=nil
            end
        end
        local _,root,humanoid=C:character()
        if not root or not humanoid or humanoid.Health<=0 or C.state.paused or C.UserInputService:GetFocusedTextBox() then return end
        local config=C.config
        local target=C.state.target
        if config.aura and not W:alive(target) then target=W:nearest(W:enemies(),root.Position,function(object) return W:alive(object) end,30) end
        local targetPart=W:part(target)
        if not targetPart or not W:alive(target) or (targetPart.Position-root.Position).Magnitude>math.max(35,config.distance+config.height+10) then return end
        if not config.attack and not config.skills and not config.aura then return end
        local weapon=config.weapon
        local targetHumanoid=target:FindFirstChildOfClass("Humanoid")
        if config.mastery and targetHumanoid and targetHumanoid.MaxHealth>0 and targetHumanoid.Health/targetHumanoid.MaxHealth*100<=config.masteryHealth then weapon=config.masteryWeapon end
        local tool=M:equip(weapon)
        if not tool then C:status("Arma nao encontrada. Equipe ou informe o nome exato."); return end
        if (config.attack or config.aura) and now-M.lastAttack>=config.attackInterval and tool.Enabled then
            M.lastAttack=now; tool:Activate()
        end
        if config.skills then
            local keys=Core.keys(config.skillKeys)
            if #keys>0 then
                M.skillCursor=((M.skillCursor-1)%#keys)+1
                local key=keys[M.skillCursor]
                if now-(M.skillTimes[key] or -math.huge)>=config.skillInterval and pulse(key,now) then
                    M.skillTimes[key]=now; M.skillCursor=M.skillCursor+1
                end
            end
        end
    end)
    C:job("aim-target",0.1,function()
        M.aimTarget=C.config.aim and M:playerTarget() or nil
    end)
    -- O frame so orienta a camera; selecao de jogador ocorre a 10 Hz.
    C:connect(C.RunService.RenderStepped,function()
        if not C.config.aim or not C.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or C.UserInputService:GetFocusedTextBox() then return end
        local camera=workspace.CurrentCamera
        local object=M.aimTarget; local part=W:part(object)
        if not camera or not part then return end
        local point,visible=camera:WorldToViewportPoint(part.Position)
        local center=camera.ViewportSize/2
        if not visible or (Vector2.new(point.X,point.Y)-center).Magnitude>C.config.aimRadius then return end
        local lead=math.min(C.config.predictionLimit,(part.Position-camera.CFrame.Position).Magnitude/C.config.projectileSpeed)
        local predicted=part.Position+part.AssemblyLinearVelocity*lead
        if (predicted-camera.CFrame.Position).Magnitude>0.01 then camera.CFrame=CFrame.lookAt(camera.CFrame.Position,predicted) end
    end)
    C:job("haki",2,function()
        local model=C.player.Character
        if C.config.haki and model and not model:FindFirstChild("HasBuso") then C:remote("Buso",{}) end
    end)
    return M
end

end)()

-- ===== MODULO: Farm =====
local Farm = (function()
-- Luau / Farm.luau / Roblox client / Blox Fruits
-- Maquina de estados: somente um modo pode escolher o destino e o alvo.
return function(C)
    local W,M,Core=C.world,C.motion,C.Core
    local F={questAttempts={},lootAttempts={},skip={},lastMode="Off",nextQuest=0}
    C.farm=F
    local resources={
        Bones={"reborn skeleton","living zombie","demonic soul","possessed mummy","posessed mummy"},
        Ectoplasm={"ship deckhand","ship engineer","ship steward","ship officer","cursed captain"},
    }
    local function state(text) C:status(text) end
    local function noTarget(text)
        C.state.target=nil; state(text)
        if C.config.autoHop and os.clock()-C.state.emptySince>=C.config.hopAfter and C.server then C.server:hop(false) end
    end
    local function fight(object)
        local part=W:part(object)
        if not part then return end
        C.state.target=object; C.state.emptySince=os.clock()
        local destination=(part.CFrame*CFrame.new(0,C.config.height,C.config.distance)).Position
        M:go(destination,"farm",part.Position,1)
        state("Alvo: "..object.Name)
    end
    local function ensureQuest(quest,root)
        local questState=W:questState(quest)
        if questState=="match" then F.questAttempts[quest.id..quest.index]=0; return true end
        if questState=="unknown" then state("Painel de quest nao reconhecido; auto quest pausado."); return false end
        if questState=="other" then
            if C.config.replaceQuest then C:remote("AbandonQuest",{}); state("Solicitando abandono da quest atual.")
            else state("Outra quest ativa. Conclua-a ou habilite Substituir quest.") end
            return false
        end
        local position=W:questPosition(quest)
        if not position then state("Posicao do NPC de "..quest.id.." nao foi identificada."); return false end
        if (root.Position-position).Magnitude>8 then M:go(position+Vector3.new(0,2,0),"quest",nil,5); state("Indo ao NPC: "..quest.id); return false end
        local key=quest.id..quest.index
        local attempts=F.questAttempts[key] or 0
        if attempts>=3 then C:set("mode","Off"); C:notify("Quest sem confirmacao apos 3 tentativas: "..quest.id); return false end
        if os.clock()>=F.nextQuest and C:remote("StartQuest",{quest.id,quest.index},function(ok,result)
            C:log("StartQuest "..quest.id..": "..tostring(ok).." / "..tostring(result))
        end) then F.questAttempts[key]=attempts+1; F.nextQuest=os.clock()+5 end
        state("Aguardando confirmacao de quest: "..quest.enemy)
        return false
    end
    local function loot(kind,root,now)
        C.state.target=nil
        local object=W:nearest(W.index[kind],root.Position,function(item)
            return (F.skip[item] or 0)<now and (kind~="fruits" or item.Parent and not item.Parent:FindFirstChildOfClass("Humanoid"))
        end,C.config.searchRadius)
        if not object then noTarget("Nenhum "..kind.." carregado no alcance."); return end
        local part=W:part(object)
        if not part then return end
        C.state.emptySince=now
        M:go(part.Position,"loot",nil,1.5); state("Coletando: "..object.Name)
        if (part.Position-root.Position).Magnitude<=5 then
            local attempt=F.lootAttempts[object]
            if not attempt then
                F.lootAttempts[object]=now
                local prompt=object:FindFirstChildWhichIsA("ProximityPrompt",true)
                if prompt and prompt.Enabled and type(fireproximityprompt)=="function" then
                    C:spawn(function() pcall(fireproximityprompt,prompt,prompt.HoldDuration) end)
                end
                if type(firetouchinterest)=="function" then
                    pcall(function() firetouchinterest(root,part,0); firetouchinterest(root,part,1) end)
                end
            elseif now-attempt>8 then
                F.skip[object]=now+30; F.lootAttempts[object]=nil
                C:log("Coleta nao confirmada; ignorando por 30s: "..object.Name)
            end
        end
    end
    C:job("farm",0.2,function(now)
        local mode=C.config.mode
        local _,root,humanoid=C:character()
        if mode~=F.lastMode then
            F.lastMode=mode; table.clear(F.questAttempts); C.state.quest=nil
        end
        if not root or not humanoid or humanoid.Health<=0 then C.state.target=nil; return end
        local health=humanoid.Health/math.max(humanoid.MaxHealth,1)*100
        if C.state.paused then C.state.paused=health<math.min(100,C.config.pauseHealth+15)
        else C.state.paused=health<C.config.pauseHealth end
        if C.state.paused then C.state.target=nil; C.state.destination=nil; state("Pausado: vida baixa. Aguardando recuperacao."); return end
        if mode=="Off" then return end
        C.state.destination=nil; C.state.target=nil
        if mode=="Fruit" then loot("fruits",root,now); return end
        if mode=="Chest" then loot("chests",root,now); return end
        if mode=="Player" then
            local object=M:playerTarget()
            if object then fight(object) else noTarget("Jogador elegivel nao encontrado.") end
            return
        end
        if mode=="Event" then
            local object=W:nearest(W.index.events,root.Position,function(item,kind) return kind==C.config.event and W:alive(item) end,C.config.searchRadius)
            if object then fight(object) else noTarget("Evento sem alvo carregado: "..C.config.event) end
            return
        end
        if mode=="Raid" then
            local main=C.playerGui:FindFirstChild("Main"); local timer=main and main:FindFirstChild("Timer")
            if not timer or not timer:IsA("GuiObject") or not timer.Visible then noTarget("Nenhuma raid ativa detectada."); return end
            local island,index=nil,0
            for object in pairs(W.index.locations) do
                local number=tonumber(object.Name:match("^Island (%d+)$"))
                if number and number>index then island,index=object,number end
            end
            local islandPart=W:part(island)
            local center=islandPart and islandPart.Position or root.Position
            local object=W:nearest(W:enemies(),root.Position,function(item)
                local part=W:part(item)
                return W:alive(item) and part and (part.Position-center).Magnitude<1200
            end,C.config.searchRadius)
            if object then fight(object)
            elseif islandPart then M:go(center+Vector3.new(0,20,0),"raid"); state("Raid: aguardando alvos na ilha "..index)
            else noTarget("Ilhas de raid ainda nao carregadas.") end
            return
        end
        local quest
        if mode=="Level" or mode=="Material" and C.config.material=="Candy" then
            if not W.ready then state("Aguardando adaptador de quests."); return end
            quest=Core.chooseQuest(W.quests,C:level(),C:sea())
            if not quest then state("Quest compativel nao encontrada. Confira o Sea nas configuracoes."); return end
            C.state.quest=quest
            if not ensureQuest(quest,root) then return end
        end
        local function matches(item)
            if not W:alive(item) then return false end
            local name=Core.cleanName(item.Name)
            if quest then return name==Core.cleanName(quest.enemy) end
            if mode=="Boss" then return W:isBoss(item) and (C.config.enemy=="" or Core.contains(name,C.config.enemy)) end
            if mode=="Material" then
                local names=resources[C.config.material]
                if names then return table.find(names,name)~=nil end
                return C.config.enemy~="" and Core.contains(name,C.config.enemy)
            end
            return C.config.enemy=="" or Core.contains(name,C.config.enemy)
        end
        local object=W:nearest(W:enemies(),root.Position,matches,C.config.searchRadius)
        if object then
            if mode=="Boss" and C.config.bossQuest then
                local bossQuest=Core.chooseQuest(W.quests,C:level(),C:sea(),object.Name)
                if bossQuest and not ensureQuest(bossQuest,root) then return end
            end
            fight(object)
        else
            local name=quest and quest.enemy or C.config.enemy
            local spawn=name~="" and W:spawnFor(name,root.Position)
            if spawn then M:go(spawn+Vector3.new(0,5,0),"spawn") end
            noTarget("Aguardando spawn: "..(name~="" and name or mode))
        end
    end)
    C:job("loot-cleanup",10,function(now)
        for object,deadline in pairs(F.skip) do if not object.Parent or deadline<now then F.skip[object]=nil end end
        for object in pairs(F.lootAttempts) do if not object:IsDescendantOf(workspace) then F.lootAttempts[object]=nil end end
    end)
    return F
end

end)()

-- ===== MODULO: Services =====
local Services = (function()
-- Luau / Services.luau / Roblox client / Blox Fruits
-- Loja, inventario e servidores. Compras so existem apos ativacao explicita na GUI.
return function(C)
    local Core,W=C.Core,C.world
    local S={catalog={},lastCatalog=-math.huge,buyAttempts=0,budgetReserved=0,nextRandom=0,storeAt={}}
    C.shop=S
    function S:refresh()
        if C:remote("GetFruits",{},function(ok,result)
            if not ok or type(result)~="table" then C:notify("Catalogo nao reconhecido."); return end
            local clean={}
            for _,item in pairs(result) do
                if type(item)=="table" and type(item.Name)=="string" then
                    table.insert(clean,{Name=item.Name,OnSale=item.OnSale==true,Price=tonumber(item.Price)})
                end
            end
            self.catalog=clean; C:log("Catalogo atualizado: "..#clean.." frutas.")
            if C.refresh then C.refresh() end
        end) then self.lastCatalog=os.clock() end
    end
    function S:fruitId(tool)
        local original=tool:GetAttribute("OriginalName")
        if type(original)=="string" then
            for _,item in ipairs(self.catalog) do if item.Name==original then return original end end
        end
        local physical=Core.cleanName(tool.Name:gsub(" Fruit$",""))
        for _,item in ipairs(self.catalog) do
            local name=item.Name:match(":%s*(.+)$") or item.Name
            local left,right=name:match("^([^-]+)%-([^-]+)$")
            if left and left==right then name=left end
            if Core.cleanName(name)==physical then return item.Name end
        end
        return nil
    end
    C:job("shop",2,function(now)
        local config=C.config
        if not config.autoBuy and not config.autoRandom and not config.autoStore then return end
        if (config.autoBuy or config.autoStore) and now-S.lastCatalog>120 then S:refresh(); return end
        if config.autoStore then
            for _,tool in ipairs(W:tools()) do
                if tool.Name:match(" Fruit$") and tool:FindFirstChild("Handle") and now-(S.storeAt[tool] or -math.huge)>30 then
                    local id=S:fruitId(tool)
                    if id and C:remote("StoreFruit",{id,tool},function(ok,result)
                        C:log("StoreFruit "..id..": "..tostring(ok).." / "..tostring(result))
                    end) then S.storeAt[tool]=now; return end
                end
            end
        end
        if config.autoBuy and config.fruit~="" then
            if S.buyAttempts>=config.buyLimit then C:set("autoBuy",false); C:notify("Limite de tentativas de compra atingido nesta sessao."); return end
            local data=C.player:FindFirstChild("Data"); local cash=data and data:FindFirstChild("Beli")
            local equipped=data and data:FindFirstChild("DevilFruit")
            if equipped and equipped.Value==config.fruit then C:set("autoBuy",false); C:notify("Fruta desejada ja equipada."); return end
            for _,item in ipairs(S.catalog) do
                if item.Name==config.fruit and item.OnSale and Core.finite(item.Price) and item.Price>=0
                    and item.Price<=config.buyBudget-S.budgetReserved and cash and cash.Value>=item.Price then
                    if C:remote("PurchaseRawFruit",{item.Name},function(ok,result)
                        C:log("Compra solicitada: "..item.Name.." / "..tostring(ok).." / "..tostring(result))
                    end) then S.buyAttempts=S.buyAttempts+1; S.budgetReserved=S.budgetReserved+item.Price; return end
                end
            end
        end
        if config.autoRandom and now>=S.nextRandom then
            if C:remote("Cousin",{"Buy"},function(ok,result) C:log("Giro solicitado: "..tostring(ok).." / "..tostring(result)) end) then
                S.nextRandom=now+config.randomInterval
                C:notify("Giro solicitado. Proxima tentativa em "..math.floor(config.randomInterval/60).." minutos.")
            end
        end
        for tool in pairs(S.storeAt) do if not tool.Parent then S.storeAt[tool]=nil end end
    end)
    local server={busy=false,last=-math.huge,visited={[game.JobId]=true}}
    C.server=server
    function server:hop(low)
        if self.busy or os.clock()-self.last<60 then return end
        self.busy=true; self.last=os.clock(); self.started=os.clock()
        local epoch=C.epoch
        self.thread=C:spawn(function()
            local cursor,chosen=nil,nil
            for _=1,3 do
                if not C.alive or epoch~=C.epoch then self.busy=false; return end
                local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder="..(low and "Asc" or "Desc").."&limit=100"
                if cursor then url=url.."&cursor="..C.HttpService:UrlEncode(cursor) end
                local ok,body=pcall(function()
                    local requestFunction=type(request)=="function" and request or type(http_request)=="function" and http_request
                    if requestFunction then
                        local response=requestFunction({Url=url,Method="GET"})
                        assert(response.StatusCode==200,"HTTP "..tostring(response.StatusCode))
                        return response.Body
                    end
                    return game:HttpGet(url)
                end)
                if not ok then C:notify("Listagem de servidores falhou: "..tostring(body)); self.busy=false; return end
                local decodedOk,data=pcall(C.HttpService.JSONDecode,C.HttpService,body)
                if not decodedOk or type(data)~="table" then C:notify("Resposta de servidores invalida."); self.busy=false; return end
                chosen=Core.pickServer(data.data,game.JobId,self.visited,low)
                if chosen then break end
                cursor=data.nextPageCursor
                if type(cursor)~="string" or cursor=="" then break end
            end
            if not C.alive or epoch~=C.epoch then self.busy=false; return end
            if not chosen then C:notify("Nenhum servidor elegivel nas 3 paginas consultadas."); self.busy=false; return end
            self.visited[chosen.id]=true
            C:stop(); C:notify("Entrando em servidor com "..chosen.playing.." jogadores.")
            local ok,problem=pcall(function() C.TeleportService:TeleportToPlaceInstance(game.PlaceId,chosen.id,C.player) end)
            if not ok then self.busy=false; C:notify("Teleport falhou: "..tostring(problem)) end
        end)
    end
    C:connect(C.TeleportService.TeleportInitFailed,function(player,_,message)
        if player==C.player then server.busy=false; C:notify("Entrada no servidor falhou: "..tostring(message)) end
    end)
    C:job("server-watchdog",1,function(now)
        if server.busy and now-server.started>20 then
            if server.thread then pcall(task.cancel,server.thread); C.threads[server.thread]=nil end
            server.busy=false; C:notify("Troca de servidor excedeu 20s. Aguarde o intervalo para tentar novamente.")
        end
    end)
    local virtualUser
    C:connect(C.player.Idled,function()
        if not C.config.antiAfk then return end
        local ok,problem=pcall(function()
            virtualUser=virtualUser or game:GetService("VirtualUser")
            virtualUser:CaptureController(); virtualUser:ClickButton2(Vector2.zero)
        end)
        if not ok then C:set("antiAfk",false); C:notify("Anti-AFK indisponivel: "..tostring(problem)) end
    end)
    return S
end

end)()

-- ===== MODULO: Visuals =====
local Visuals = (function()
-- Luau / Visuals.luau / Roblox client / Rook Hub
-- ESP limitado aos objetos replicados; sem varrer o mapa por frame.
return function(C)
    local W=C.world
    local V={entries={},lighting=nil,seenFruits=setmetatable({},{__mode="k"})}
    C.visuals=V
    local folder=Instance.new("Folder"); folder.Name="RookVisuals"; folder.Parent=C.gui
    local function clear()
        for object,entry in pairs(V.entries) do entry.highlight:Destroy(); entry.billboard:Destroy(); V.entries[object]=nil end
        if V.lighting then
            for key,value in pairs(V.lighting) do C.Lighting[key]=value end
            V.lighting=nil
        end
    end
    table.insert(C.disposers,clear)
    C:job("visuals",0.5,function()
        local _,root=C:character()
        if not root then return end
        local wanted={}
        local function add(object,color,title)
            local part=W:part(object)
            if not part then return end
            table.insert(wanted,{object=object,part=part,color=color,title=title or object.Name,distance=(part.Position-root.Position).Magnitude})
        end
        if C.config.espPlayers then
            for _,player in ipairs(C.Players:GetPlayers()) do
                if player~=C.player and W:alive(player.Character) then add(player.Character,Color3.fromRGB(255,154,105),player.DisplayName.." (@"..player.Name..")") end
            end
        end
        if C.config.espEnemies then for _,enemy in ipairs(W:enemies()) do if W:alive(enemy) then add(enemy,Color3.fromRGB(245,108,130)) end end end
        if C.config.espFruits then
            for object in pairs(W.index.fruits) do
                if object:IsDescendantOf(workspace) and object.Parent and not object.Parent:FindFirstChildOfClass("Humanoid") then
                    add(object,Color3.fromRGB(110,245,175))
                    if not V.seenFruits[object] then V.seenFruits[object]=true; C:log("Fruta detectada: "..object.Name) end
                end
            end
        end
        if C.config.espChests then for object in pairs(W.index.chests) do add(object,Color3.fromRGB(255,215,95)) end end
        table.sort(wanted,function(a,b) return a.distance<b.distance end)
        local retained={}
        for i=1,math.min(#wanted,math.floor(C.config.espLimit)) do
            local item=wanted[i]; local object=item.object; local entry=V.entries[object]
            retained[object]=true
            if not entry then
                local highlight=Instance.new("Highlight")
                highlight.Adornee=object:IsA("Tool") and item.part or object
                highlight.FillTransparency=0.8; highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent=folder
                local billboard=Instance.new("BillboardGui")
                billboard.Size=UDim2.fromOffset(210,45); billboard.StudsOffset=Vector3.new(0,4,0)
                billboard.AlwaysOnTop=true; billboard.Parent=folder
                local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1
                label.TextSize=12; label.Font=Enum.Font.GothamSemibold; label.TextStrokeTransparency=0.4; label.TextWrapped=true; label.Parent=billboard
                entry={highlight=highlight,billboard=billboard,label=label}; V.entries[object]=entry
            end
            entry.billboard.Adornee=item.part; entry.highlight.FillColor=item.color; entry.highlight.OutlineColor=item.color
            entry.label.TextColor3=item.color
            local humanoid=object:FindFirstChildOfClass("Humanoid")
            local health=humanoid and (" | HP "..math.ceil(humanoid.Health).."/"..math.ceil(humanoid.MaxHealth)) or ""
            entry.label.Text=item.title.."\n"..math.floor(item.distance).." studs"..health
        end
        for object,entry in pairs(V.entries) do
            if not retained[object] then entry.highlight:Destroy(); entry.billboard:Destroy(); V.entries[object]=nil end
        end
        if C.config.fullbright then
            if not V.lighting then V.lighting={Brightness=C.Lighting.Brightness,Ambient=C.Lighting.Ambient,OutdoorAmbient=C.Lighting.OutdoorAmbient} end
            C.Lighting.Brightness=2; C.Lighting.Ambient=Color3.fromRGB(170,170,170); C.Lighting.OutdoorAmbient=Color3.fromRGB(170,170,170)
        elseif V.lighting then
            for key,value in pairs(V.lighting) do C.Lighting[key]=value end
            V.lighting=nil
        end
    end)
    function V:moon()
        local camera=workspace.CurrentCamera
        if camera then camera.CFrame=CFrame.lookAt(camera.CFrame.Position,camera.CFrame.Position+C.Lighting:GetMoonDirection()*1000) end
        C:notify("Camera direcionada para a lua. Isso nao conclui o requisito da Mirage.")
    end
    return V
end

end)()

-- ===== MODULO: Interface =====
local Interface = (function()
-- Luau / Interface.luau / Roblox client / Rook Hub
-- GUI nativa, sem baixar ou executar bibliotecas externas.
return function(C)
    local UI={refreshers={},pages={},tabButtons={}}
    local color={bg=Color3.fromRGB(17,20,28),side=Color3.fromRGB(23,27,37),card=Color3.fromRGB(32,38,51),text=Color3.fromRGB(231,237,247),muted=Color3.fromRGB(153,167,187),accent=Color3.fromRGB(92,224,179)}
    local function make(class,properties,parent)
        local object=Instance.new(class)
        for key,value in pairs(properties) do object[key]=value end
        object.Parent=parent; return object
    end
    local function round(object,radius) make("UICorner",{CornerRadius=UDim.new(0,radius or 8)},object) end
    local function label(parent,text,size)
        return make("TextLabel",{BackgroundTransparency=1,Text=text,TextColor3=color.text,Font=Enum.Font.Gotham,TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent)
    end
    local camera=workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
    local width,height=math.min(880,viewport.X-32),math.min(610,viewport.Y-65)
    local panel=make("Frame",{Size=UDim2.fromOffset(width,height),Position=UDim2.new(0.5,-width/2,0.5,-height/2),BackgroundColor3=color.bg,BorderSizePixel=0},C.gui)
    round(panel,14); C.panel=panel
    make("UIStroke",{Color=Color3.fromRGB(55,67,83),Thickness=1},panel)
    local title=label(panel,"ROOK  /  BLOX FRUITS",18); title.Font=Enum.Font.GothamBold
    title.Position=UDim2.fromOffset(20,8); title.Size=UDim2.new(1,-130,0,38); title.Active=true
    local subtitle=label(panel,"v"..C.Core.version.."   •   CLIENTE PC   •   COMPATIBILIDADE EM VALIDACAO",10)
    subtitle.TextColor3=color.muted; subtitle.Position=UDim2.fromOffset(20,43); subtitle.Size=UDim2.new(1,-30,0,20)
    local minimize=make("TextButton",{Text="—",Size=UDim2.fromOffset(36,30),Position=UDim2.new(1,-88,0,13),BackgroundColor3=color.card,TextColor3=color.text,TextSize=20,BorderSizePixel=0},panel); round(minimize)
    local close=make("TextButton",{Text="×",Size=UDim2.fromOffset(36,30),Position=UDim2.new(1,-45,0,13),BackgroundColor3=color.card,TextColor3=color.text,TextSize=20,BorderSizePixel=0},panel); round(close)
    C:connect(minimize.Activated,function() panel.Visible=false end); C:connect(close.Activated,function() C:destroy() end)
    local sidebar=make("Frame",{Position=UDim2.fromOffset(12,80),Size=UDim2.new(0,180,1,-150),BackgroundColor3=color.side,BorderSizePixel=0},panel); round(sidebar)
    make("UIPadding",{PaddingTop=UDim.new(0,9),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},sidebar)
    make("UIListLayout",{Padding=UDim.new(0,7)},sidebar)
    local content=make("Frame",{Position=UDim2.fromOffset(207,80),Size=UDim2.new(1,-222,1,-150),BackgroundTransparency=1},panel)
    local footer=label(panel,"",12); footer.Position=UDim2.new(0,20,1,-60); footer.Size=UDim2.new(1,-40,0,42); footer.TextColor3=color.accent
    local reopen=make("TextButton",{Text="ROOK",Position=UDim2.new(0,12,1,-45),Size=UDim2.fromOffset(72,30),BackgroundColor3=color.card,TextColor3=color.accent,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0},C.gui); round(reopen)
    C:connect(reopen.Activated,function() panel.Visible=not panel.Visible end)
    local dragging,dragStart,origin
    C:connect(title.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=input.Position; origin=panel.Position end
    end)
    C:connect(C.UserInputService.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    C:connect(C.UserInputService.InputChanged,function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=input.Position-dragStart
            local screen=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or viewport
            local x=origin.X.Scale*screen.X+origin.X.Offset+delta.X
            local y=origin.Y.Scale*screen.Y+origin.Y.Offset+delta.Y
            panel.Position=UDim2.fromOffset(math.clamp(x,-width+100,screen.X-100),math.clamp(y,0,math.max(0,screen.Y-60)))
        end
    end)
    function UI:tab(name)
        local page=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=color.accent,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
        make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page)
        make("UIPadding",{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,12)},page)
        local tab=make("TextButton",{Size=UDim2.new(1,0,0,40),Text=name,BackgroundColor3=color.side,TextColor3=color.muted,BorderSizePixel=0,TextSize=12,Font=Enum.Font.GothamSemibold},sidebar); round(tab)
        self.pages[name]=page; self.tabButtons[name]=tab
        C:connect(tab.Activated,function()
            for key,item in pairs(self.pages) do item.Visible=key==name; self.tabButtons[key].TextColor3=key==name and color.accent or color.muted; self.tabButtons[key].BackgroundColor3=key==name and color.card or color.side end
        end)
        return page
    end
    function UI:note(page,text)
        local item=label(page,text,12); item.TextColor3=color.muted; item.Size=UDim2.new(1,0,0,0); item.AutomaticSize=Enum.AutomaticSize.Y
        return item
    end
    function UI:heading(page,text)
        local item=label(page,text,15); item.Font=Enum.Font.GothamBold; item.Size=UDim2.new(1,0,0,30); return item
    end
    local function row(page,text)
        local container=make("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=color.card,BorderSizePixel=0},page); round(container)
        local caption=label(container,text,12); caption.Position=UDim2.fromOffset(12,0); caption.Size=UDim2.new(0.48,-15,0,44)
        return container
    end
    function UI:button(page,text,callback)
        local button=make("TextButton",{Size=UDim2.new(1,0,0,38),Text=text,BackgroundColor3=color.card,TextColor3=color.accent,BorderSizePixel=0,TextSize=12,Font=Enum.Font.GothamSemibold},page); round(button)
        C:connect(button.Activated,function()
            local ok,problem=pcall(callback)
            if not ok then C:notify("Acao falhou: "..tostring(problem)) end
        end)
        return button
    end
    function UI:toggle(page,text,key)
        local container=row(page,text)
        local button=make("TextButton",{Size=UDim2.fromOffset(70,28),Position=UDim2.new(1,-82,0,8),BorderSizePixel=0,TextSize=11,Font=Enum.Font.GothamBold},container); round(button,14)
        local function refresh() button.Text=C.config[key] and "LIGADO" or "DESLIG."; button.BackgroundColor3=C.config[key] and color.accent or color.side; button.TextColor3=C.config[key] and color.bg or color.muted end
        table.insert(self.refreshers,refresh); refresh()
        C:connect(button.Activated,function() C:set(key,not C.config[key]) end)
    end
    function UI:field(page,text,key,numeric)
        local container=row(page,text)
        local box=make("TextBox",{Position=UDim2.new(0.48,0,0,8),Size=UDim2.new(0.52,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,BorderSizePixel=0,Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false},container); round(box,5)
        local function refresh() if not box:IsFocused() then box.Text=tostring(C.config[key]) end end
        table.insert(self.refreshers,refresh); refresh()
        C:connect(box.FocusLost,function()
            local value=numeric and tonumber(box.Text) or box.Text
            if numeric and not C.Core.finite(value) then refresh(); C:notify("Informe um numero valido."); return end
            if key=="toggleKey" then
                local ok,valid=pcall(function() return Enum.KeyCode[value] end)
                if not ok or not valid or value=="Unknown" or value=="End" then refresh(); C:notify("Tecla invalida ou reservada. Ex.: RightShift, F8."); return end
            end
            C:set(key,value); refresh()
        end)
    end
    function UI:dropdown(page,text,key,source,callback)
        local container=row(page,text)
        local button=make("TextButton",{Position=UDim2.new(0.48,0,0,8),Size=UDim2.new(0.52,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0},container); round(button,5)
        local options=make("ScrollingFrame",{Position=UDim2.fromOffset(8,82),Size=UDim2.new(1,-16,0,140),BackgroundColor3=color.side,BorderSizePixel=0,Visible=false,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3},container)
        make("UIListLayout",{Padding=UDim.new(0,3)},options)
        local search=make("TextBox",{Position=UDim2.fromOffset(8,47),Size=UDim2.new(1,-16,0,28),Text="",PlaceholderText="Filtrar opcoes...",TextColor3=color.text,BackgroundColor3=color.side,BorderSizePixel=0,TextSize=12,Visible=false,ClearTextOnFocus=false},container)
        local open=false
        local function refresh() button.Text=(C.config[key]~="" and tostring(C.config[key]) or "Automatico / equipada").."  ▾" end
        local function populate()
            for _,child in ipairs(options:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
            local values=type(source)=="function" and source() or source
            local seen={}
            for _,value in ipairs(values) do
                if not seen[value] and C.Core.contains(value,search.Text) then
                    seen[value]=true
                    local entry=make("TextButton",{Size=UDim2.new(1,-5,0,28),Text=value=="" and "Automatico / equipada" or value,BackgroundTransparency=1,TextColor3=color.text,TextSize=12},options)
                    entry.Activated:Connect(function()
                        C:set(key,value); if callback then callback(value) end
                        open=false; options.Visible=false; search.Visible=false; container.Size=UDim2.new(1,0,0,44)
                    end)
                end
            end
        end
        C:connect(button.Activated,function() open=not open; options.Visible=open; search.Visible=open; container.Size=UDim2.new(1,0,0,open and 230 or 44); if open then populate() end end)
        C:connect(search:GetPropertyChangedSignal("Text"),function() if open then populate() end end)
        table.insert(self.refreshers,refresh); refresh()
    end
    local farm=UI:tab("Auto Farm")
    local combat=UI:tab("Player / Combat")
    local fruits=UI:tab("Fruits / Shop")
    local travel=UI:tab("Teleports / Sea")
    local misc=UI:tab("Misc / Settings")
    local function weapons()
        local names={"","Melee","Sword","Gun","Blox Fruit"}
        for _,tool in ipairs(C.world:tools()) do table.insert(names,tool.Name) end
        return names
    end
    UI:heading(farm,"Progressao e recursos")
    UI:note(farm,"Um modo controla o movimento. Level usa as quests detectadas no jogo. Boss aguarda spawn; Candy depende do evento sazonal ativo.")
    UI:dropdown(farm,"Modo de farm","mode",C.Core.enums.mode,function(mode)
        if mode~="Off" and mode~="Fruit" and mode~="Chest" then C:set("attack",true) end
    end)
    UI:dropdown(farm,"Arma principal","weapon",weapons)
    UI:field(farm,"Filtro de NPC / boss","enemy")
    UI:dropdown(farm,"Selecionar boss","enemy",function()
        local names={""}
        for _,quest in ipairs(C.world.quests) do if quest.amount==1 and C.Core.inSea(quest.level,C:sea()) then table.insert(names,quest.enemy) end end
        for _,enemy in ipairs(C.world:enemies()) do if C.world:isBoss(enemy) then table.insert(names,enemy.Name) end end
        return names
    end)
    UI:toggle(farm,"Aceitar quest de boss","bossQuest")
    UI:toggle(farm,"Substituir quest atual","replaceQuest")
    UI:dropdown(farm,"Material","material",C.Core.enums.material)
    UI:note(farm,"Custom usa o filtro de NPC. Bones e Ectoplasm selecionam grupos conhecidos; o servidor decide os drops.")
    UI:heading(farm,"Maestria e posicionamento")
    UI:toggle(farm,"Trocar arma para finalizar","mastery")
    UI:dropdown(farm,"Arma / fruta de maestria","masteryWeapon",weapons)
    UI:field(farm,"Trocar com HP do alvo (%)","masteryHealth",true)
    UI:field(farm,"Distancia do alvo","distance",true)
    UI:field(farm,"Altura sobre o alvo","height",true)
    UI:field(farm,"Alcance de busca","searchRadius",true)
    UI:field(farm,"Pausar com vida abaixo (%)","pauseHealth",true)
    UI:heading(farm,"Eventos e raids")
    UI:dropdown(farm,"Evento selecionado","event",C.Core.enums.event)
    UI:note(farm,"Event aproxima e tenta combater alvos carregados com vida reconhecida. Nao navega barcos, invoca Leviathan, quebra segmentos nem coleta o coracao. Raid atua numa raid ja iniciada.")
    UI:button(farm,"Iniciar modo Event",function() C:set("mode","Event"); C:set("attack",true) end)
    UI:button(farm,"Iniciar modo Raid",function() C:set("mode","Raid"); C:set("attack",true) end)
    UI:heading(combat,"Ataques e habilidades")
    UI:toggle(combat,"Ataque automatico","attack")
    UI:field(combat,"Intervalo de ataque (s)","attackInterval",true)
    UI:note(combat,"Ataque temporizado via Tool:Activate(). Respeita Tool.Enabled. Nao remove cooldown do servidor nem garante fast attack na versao atual.")
    UI:toggle(combat,"Aura em NPCs proximos","aura")
    UI:toggle(combat,"Habilidades automaticas","skills")
    UI:field(combat,"Teclas de habilidade","skillKeys")
    UI:field(combat,"Intervalo por tecla (s)","skillInterval",true)
    UI:toggle(combat,"Auto Aura / Buso","haki")
    UI:heading(combat,"Jogadores e mira")
    UI:dropdown(combat,"Alvo por username","player",function()
        local names={""}; for _,player in ipairs(C.Players:GetPlayers()) do if player~=C.player then table.insert(names,player.Name) end end; return names
    end)
    UI:field(combat,"Username / nickname exato","player")
    UI:button(combat,"Seguir e atacar jogador selecionado",function() C:set("mode","Player"); C:set("attack",true) end)
    UI:note(combat,"Alvo vazio escolhe outro jogador vivo mais proximo. O servidor decide se o PvP e permitido. Mira atua na camera com botao direito pressionado; habilidades com mira propria podem ignora-la.")
    UI:toggle(combat,"Mira preditiva de camera","aim")
    UI:field(combat,"Raio da mira (pixels)","aimRadius",true)
    UI:field(combat,"Velocidade do projetil","projectileSpeed",true)
    UI:field(combat,"Previsao maxima (s)","predictionLimit",true)
    UI:toggle(combat,"ESP jogadores / HP / distancia","espPlayers")
    UI:toggle(combat,"ESP NPCs","espEnemies")
    UI:heading(fruits,"Frutas no mapa")
    UI:toggle(fruits,"Fruit ESP e deteccao","espFruits")
    UI:button(fruits,"Coletar frutas carregadas",function() C:set("mode","Fruit") end)
    UI:toggle(fruits,"Guardar frutas fisicas","autoStore")
    UI:note(fruits,"ESP e coleta so enxergam objetos replicados para este cliente. Guardar exige que o nome da fruta seja reconhecido no catalogo.")
    UI:heading(fruits,"Loja e giro")
    UI:button(fruits,"Atualizar catalogo",function() C.shop:refresh() end)
    UI:dropdown(fruits,"Fruta exata da loja","fruit",function() local values={""}; for _,item in ipairs(C.shop.catalog) do table.insert(values,item.Name) end; return values end)
    UI:field(fruits,"Orcamento da sessao (Beli)","buyBudget",true)
    UI:field(fruits,"Limite de tentativas de compra","buyLimit",true)
    UI:note(fruits,"Comprar na loja pode substituir a fruta equipada e gastar Beli. O orcamento e o limite contam solicitacoes, inclusive recusadas. Nao compra produtos em Robux.")
    UI:toggle(fruits,"Comprar fruta quando em estoque","autoBuy")
    UI:toggle(fruits,"Girar fruta automaticamente","autoRandom")
    UI:field(fruits,"Intervalo do giro (s)","randomInterval",true)
    UI:note(fruits,"Auto Random usa Beli, tenta ao ativar e respeita intervalo minimo de 2h. O servidor valida preco, acesso e cooldown. O orcamento acima pertence apenas a compra do catalogo.")
    UI:heading(travel,"Mobilidade")
    UI:field(travel,"Velocidade de navegacao","moveSpeed",true)
    UI:toggle(travel,"Fly: WASD + Q/E","fly")
    UI:field(travel,"Velocidade de voo","flySpeed",true)
    UI:toggle(travel,"Noclip local","noclip")
    UI:toggle(travel,"Alterar WalkSpeed","speed")
    UI:field(travel,"WalkSpeed","walkSpeed",true)
    UI:note(travel,"Navegacao e alteracoes locais podem ser corrigidas pelo servidor. Nao ha bypass de anti-cheat implementado.")
    -- Destinos sao resolvidos por nome apenas quando o usuario pressiona Ir.
    local destinationRow=row(travel,"Ilha / local (filtro)")
    local destinationBox=make("TextBox",{Position=UDim2.new(0.48,0,0,8),Size=UDim2.new(0.52,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,Text="",PlaceholderText="Nome do local",ClearTextOnFocus=false,TextSize=12,BorderSizePixel=0},destinationRow)
    local locationList=UI:note(travel,"")
    UI:button(travel,"Listar ilhas e locais detectados",function() locationList.Text=C.world:locationNames("locations") end)
    local function navigate(bucket,filter)
        local _,root=C:character(); if not root then return end
        if filter=="" then C:notify("Informe um filtro de destino."); return end
        local object=C.world:nearest(C.world.index[bucket],root.Position,function(item) return C.Core.contains(item.Name,filter) end)
        local part=C.world:part(object)
        if part then C.motion:travelTo(part.Position+Vector3.new(0,6,0)) else C:notify("Destino nao carregado: "..filter) end
    end
    UI:button(travel,"Ir para ilha / local",function() navigate("locations",destinationBox.Text) end)
    for sea,command in ipairs({"TravelMain","TravelDressrosa","TravelZou"}) do
        UI:button(travel,"Solicitar viagem para Sea "..sea,function() C:stop(); C:remote(command,{}) end)
    end
    UI:heading(travel,"Mirage e Race V4 — assistencia")
    local events=UI:note(travel,"")
    UI:button(travel,"Detectar Mirage / templo / engrenagens",function()
        events.Text="Lua: "..C.Lighting:GetMoonPhase().." | Objetos: "..C.world:locationNames("race")
    end)
    UI:button(travel,"Ir para Mirage detectada",function() navigate("race","mirage") end)
    UI:button(travel,"Ir para templo detectado",function() navigate("race","temple") end)
    UI:button(travel,"Ir para engrenagem detectada",function() navigate("race","gear") end)
    UI:button(travel,"Olhar para a lua",function() C.visuals:moon() end)
    UI:toggle(travel,"Iluminacao local","fullbright")
    UI:note(travel,"Estas rotas nao automatizam Race V4, sincronizacao entre racas, provas, portas ou requisito lunar. So mostram e acessam objetos identificados no cliente.")
    UI:heading(misc,"Sessao e preferencias")
    UI:field(misc,"Tecla de abrir / minimizar","toggleKey")
    UI:dropdown(misc,"Sea / adaptacao manual","sea",C.Core.enums.sea)
    UI:toggle(misc,"Anti-AFK","antiAfk")
    UI:toggle(misc,"ESP de baus","espChests")
    UI:button(misc,"Iniciar coleta de baus",function() C:set("mode","Chest") end)
    UI:field(misc,"Limite de objetos com ESP","espLimit",true)
    UI:toggle(misc,"Server Hop sem alvos","autoHop")
    UI:field(misc,"Espera antes do Hop (s)","hopAfter",true)
    UI:button(misc,"Trocar servidor",function() C.server:hop(false) end)
    UI:button(misc,"Entrar em servidor com pouca gente",function() C.server:hop(true) end)
    UI:note(misc,"Hop consulta ate 3 paginas da API oficial. Sem proxy. Reexecute o script apos trocar de servidor; nao ha reinjecao automatica.")
    UI:button(misc,"Salvar preferencias",function() C:save() end)
    UI:button(misc,"Carregar preferencias",function() C:load() end)
    UI:button(misc,"Recarregar adaptador de quests",function() C.world:loadModules() end)
    UI:button(misc,"Copiar diagnostico",function() C:diagnostic() end)
    UI:button(misc,"PARAR TUDO  [End]",function() C:stop() end)
    UI:button(misc,"Encerrar e restaurar alteracoes locais",function() C:destroy() end)
    C.refresh=function() for _,refresh in ipairs(UI.refreshers) do refresh() end end
    UI.pages["Auto Farm"].Visible=true; UI.tabButtons["Auto Farm"].TextColor3=color.accent
    C:job("ui-status",0.5,function()
        footer.Text=string.format("Sea %s  ·  Lv %d  ·  %d FPS  ·  %s\n%s",tostring(C:sea() or "?"),C:level(),math.floor(C.state.fps),C.config.mode,C.state.status)
    end)
    return UI
end

end)()

-- Inicializacao atomica: falha de modulo encerra conexoes e restaura alteracoes.
local context = Runtime(Core)
local ok, problem = pcall(function()
    World(context)
    MotionCombat(context)
    Farm(context)
    Services(context)
    Visuals(context)
    Interface(context)
end)
if not ok then
    context:destroy()
    error("Rook Hub: " .. tostring(problem))
end
