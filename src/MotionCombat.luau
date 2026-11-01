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
