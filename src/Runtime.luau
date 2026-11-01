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
