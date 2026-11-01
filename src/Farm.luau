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
