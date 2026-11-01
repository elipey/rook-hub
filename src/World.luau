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
    -- Descoberta explicita: abrir o painel nao enumera todo o Workspace.
    local pending={}
    function W:startIndex()
        if self.indexStarted then C:notify("Deteccao do mapa ja iniciada."); return end
        self.indexStarted=true
        print("[Rook] index:start")
        C:connect(workspace.DescendantAdded,classify)
        C:connect(workspace.DescendantRemoving,function(object)
            for _,bucket in pairs(self.index) do bucket[object]=nil end
        end)
        table.insert(pending,workspace)
        local folder=C.ReplicatedStorage:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
        if folder then
            table.insert(pending,folder)
            C:connect(folder.ChildAdded,classify)
            C:connect(folder.ChildRemoved,function(object) self.index.spawns[object]=nil end)
        end
        C:notify("Deteccao incremental do mapa iniciada.")
    end
    C:job("index-initial",0.03,function()
        if #pending==0 then return end
        local deadline=os.clock()+0.002
        for _=1,100 do
            local object=table.remove(pending)
            if not object then break end
            if object==workspace or object.Parent then
                classify(object)
                for _,child in ipairs(object:GetChildren()) do table.insert(pending,child) end
            end
            if os.clock()>=deadline then break end
        end
        if #pending==0 then C:log("Indice inicial concluido."); print("[Rook] index:complete") end
    end)
    function W:loadModules()
        if self.loading then return end
        self.loading=true; self.loadStarted=os.clock()
        self.loadThread=C:spawn(function()
            local questModule=C.ReplicatedStorage:FindFirstChild("Quests")
            local guideModule=C.ReplicatedStorage:FindFirstChild("GuideModule")
            if not questModule or not guideModule or not questModule:IsA("ModuleScript") or not guideModule:IsA("ModuleScript") then
                self.loading=false; C:notify("Modulos Quests/GuideModule indisponiveis. Farm por nivel bloqueado."); return
            end
            print("[Rook] require:Quests:start")
            local ok,quests=pcall(require,questModule)
            print("[Rook] require:Quests:returned",ok)
            print("[Rook] require:GuideModule:start")
            local guideOk,guide=pcall(require,guideModule)
            print("[Rook] require:GuideModule:returned",guideOk)
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
    C:log("Inicializacao leve: deteccao do mapa e leitura de quests aguardam ativacao manual.")
    return W
end
