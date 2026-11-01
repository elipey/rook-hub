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
