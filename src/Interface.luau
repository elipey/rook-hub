-- Luau / Interface.luau / Roblox client / Rook Hub
-- GUI nativa, sem baixar ou executar bibliotecas externas.
return function(C)
    local UI={refreshers={},pages={},tabButtons={},markers={}}
    local color={bg=Color3.fromRGB(18,8,12),side=Color3.fromRGB(28,8,14),card=Color3.fromRGB(43,10,19),text=Color3.fromRGB(250,229,234),muted=Color3.fromRGB(190,150,162),accent=Color3.fromRGB(255,30,78),selected=Color3.fromRGB(78,12,30)}
    local order=setmetatable({},{__mode="k"})
    local function make(class,properties,parent)
        local object=Instance.new(class)
        for key,value in pairs(properties) do object[key]=value end
        if parent and object:IsA("GuiObject") then order[parent]=(order[parent] or 0)+1; object.LayoutOrder=order[parent] end
        object.Parent=parent; return object
    end
    local function round(object,radius) make("UICorner",{CornerRadius=UDim.new(0,radius or 8)},object) end
    local function label(parent,text,size)
        return make("TextLabel",{BackgroundTransparency=1,Text=text,TextColor3=color.text,Font=Enum.Font.Gotham,TextSize=size or 13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent)
    end
    local camera=workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
    local width,height=math.min(940,viewport.X-32),math.min(660,viewport.Y-65)
    local panel=make("Frame",{Size=UDim2.fromOffset(width,height),Position=UDim2.new(0.5,-width/2,0.5,-height/2),BackgroundColor3=color.bg,BorderSizePixel=0},C.gui)
    round(panel,9); C.panel=panel
    make("UIStroke",{Color=Color3.fromRGB(89,21,40),Thickness=1},panel)
    local title=label(panel,"ROOK HUB  /  Blox Fruits",18); title.Font=Enum.Font.GothamBold
    title.Position=UDim2.fromOffset(20,8); title.Size=UDim2.new(1,-130,0,38); title.Active=true
    local subtitle=label(panel,"v"..C.Core.version.."   /   PC     •     RightShift: menu     •     End: parar",12)
    subtitle.TextColor3=color.muted; subtitle.Position=UDim2.fromOffset(20,43); subtitle.Size=UDim2.new(1,-30,0,20)
    local minimize=make("TextButton",{Text="—",Size=UDim2.fromOffset(36,30),Position=UDim2.new(1,-88,0,13),BackgroundColor3=color.card,TextColor3=color.text,TextSize=20,BorderSizePixel=0},panel); round(minimize)
    local close=make("TextButton",{Text="×",Size=UDim2.fromOffset(36,30),Position=UDim2.new(1,-45,0,13),BackgroundColor3=color.card,TextColor3=color.text,TextSize=20,BorderSizePixel=0},panel); round(close)
    C:connect(minimize.Activated,function() panel.Visible=false end); C:connect(close.Activated,function() C:destroy() end)
    local sidebar=make("ScrollingFrame",{Position=UDim2.fromOffset(12,80),Size=UDim2.new(0,218,1,-150),BackgroundColor3=color.side,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=color.accent},panel); round(sidebar)
    make("UIPadding",{PaddingTop=UDim.new(0,9),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},sidebar)
    make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},sidebar)
    make("Frame",{Position=UDim2.fromOffset(241,80),Size=UDim2.new(0,2,1,-150),BackgroundColor3=color.selected,BorderSizePixel=0},panel)
    local content=make("Frame",{Position=UDim2.fromOffset(259,80),Size=UDim2.new(1,-274,1,-150),BackgroundTransparency=1},panel)
    local footer=label(panel,"",12); footer.Position=UDim2.new(0,20,1,-60); footer.Size=UDim2.new(1,-40,0,42); footer.TextColor3=color.muted
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
        local tab=make("TextButton",{Size=UDim2.new(1,-3,0,42),Text="    "..name,TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=color.card,TextColor3=color.muted,BorderSizePixel=0,TextSize=13,Font=Enum.Font.GothamSemibold},sidebar); round(tab,6)
        local marker=make("Frame",{Size=UDim2.fromOffset(4,24),Position=UDim2.new(0,0,0.5,-12),BackgroundColor3=color.accent,BorderSizePixel=0,Visible=false},tab); round(marker,2)
        self.markers[name]=marker
        self.pages[name]=page; self.tabButtons[name]=tab
        C:connect(tab.Activated,function()
            for key,item in pairs(self.pages) do item.Visible=key==name; self.markers[key].Visible=key==name; self.tabButtons[key].TextColor3=key==name and color.text or color.muted; self.tabButtons[key].BackgroundColor3=key==name and color.selected or color.card end
        end)
        return page
    end
    function UI:note(page,text)
        local container=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},page)
        make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},container)
        local disclosure=make("TextButton",{Size=UDim2.new(1,0,0,28),Text="+  Como funciona",TextXAlignment=Enum.TextXAlignment.Left,TextColor3=color.muted,BackgroundTransparency=1,TextSize=12,Font=Enum.Font.Gotham},container)
        disclosure.Visible=text~=""
        local item=label(container,text,12); item.TextColor3=color.muted; item.Size=UDim2.new(1,-12,0,0); item.AutomaticSize=Enum.AutomaticSize.Y; item.Visible=false
        C:connect(disclosure.Activated,function() item.Visible=not item.Visible; disclosure.Text=item.Visible and "−  Ocultar detalhes" or "+  Como funciona" end)
        return item
    end
    function UI:heading(page,text)
        local item=label(page,text,20); item.Font=Enum.Font.GothamBold; item.Size=UDim2.new(1,0,0,38); return item
    end
    local function row(page,text)
        local container=make("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=color.card,BorderSizePixel=0},page); round(container)
        local caption=label(container,text,14); caption.Position=UDim2.fromOffset(14,0); caption.Size=UDim2.new(0.52,-20,0,44)
        return container
    end
    function UI:button(page,text,callback)
        local button=make("TextButton",{Size=UDim2.new(1,0,0,42),Text="    "..text,TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=color.selected,TextColor3=color.text,BorderSizePixel=0,TextSize=13,Font=Enum.Font.GothamSemibold},page); round(button,6)
        C:connect(button.Activated,function()
            local ok,problem=pcall(callback)
            if not ok then C:notify("Acao falhou: "..tostring(problem)) end
        end)
        return button
    end
    function UI:toggle(page,text,key,getValue,setValue)
        local container=row(page,text)
        local button=make("TextButton",{Size=UDim2.fromOffset(70,44),Position=UDim2.new(1,-80,0,0),BackgroundTransparency=1,Text="",AutoButtonColor=false},container)
        local track=make("Frame",{Size=UDim2.fromOffset(54,28),Position=UDim2.fromOffset(8,8),BackgroundColor3=color.side,BorderSizePixel=0},button); round(track,14)
        local thumb=make("Frame",{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(4,4),BackgroundColor3=color.muted,BorderSizePixel=0},track); round(thumb,10)
        local function refresh()
            local enabled=getValue and getValue() or (not getValue and C.config[key])
            track.BackgroundColor3=enabled and color.accent or color.selected
            thumb.BackgroundColor3=enabled and color.text or color.muted
            thumb.Position=UDim2.fromOffset(enabled and 30 or 4,4)
        end
        table.insert(self.refreshers,refresh); refresh()
        C:connect(button.Activated,function()
            if setValue then setValue(not getValue()) else C:set(key,not C.config[key]) end
        end)
    end
    function UI:modeToggle(page,text,mode)
        self:toggle(page,text,nil,function() return C.config.mode==mode end,function(enabled)
            C:set("mode",enabled and mode or "Off")
            if enabled and mode~="Fruit" and mode~="Chest" then C:set("attack",true) end
        end)
    end
    function UI:field(page,text,key,numeric)
        local container=row(page,text)
        local box=make("TextBox",{Position=UDim2.new(0.52,0,0,8),Size=UDim2.new(0.48,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,BorderSizePixel=0,Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false},container); round(box,5)
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
        local button=make("TextButton",{Position=UDim2.new(0.52,0,0,8),Size=UDim2.new(0.48,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0},container); round(button,5)
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
    local overview=UI:tab("Inicio / Status")
    local farm=UI:tab("Auto Farm")
    local bosses=UI:tab("Bosses / Materiais")
    local mastery=UI:tab("Maestria")
    local combat=UI:tab("Player / Combat")
    local esp=UI:tab("Visual / ESP")
    local fruits=UI:tab("Fruits / Shop")
    local eventsPage=UI:tab("Sea Events / Raids")
    local travel=UI:tab("Teleports / Sea")
    local misc=UI:tab("Misc / Settings")
    local function weapons()
        local names={"","Melee","Sword","Gun","Blox Fruit"}
        for _,tool in ipairs(C.world:tools()) do table.insert(names,tool.Name) end
        return names
    end
    UI:heading(overview,"Preparar sessao")
    UI:note(overview,"Inicializacao leve: ative a deteccao do mapa para ESP/coleta/destinos. Carregue quests separadamente para Level e quests de bosses.")
    UI:button(overview,"1. Ativar deteccao do mapa",function() C.world:startIndex() end)
    UI:button(overview,"2. Carregar quests do jogo",function() C.world:loadModules() end)
    UI:dropdown(farm,"Arma principal","weapon",weapons)
    UI:heading(farm,"Farming")
    UI:modeToggle(farm,"Auto Farm Level","Level")
    UI:modeToggle(farm,"Auto Farm Nearest","Nearest")
    UI:note(farm,"Um modo controla o movimento. Level usa as quests detectadas no jogo. Boss aguarda spawn; Candy depende do evento sazonal ativo.")
    UI:dropdown(farm,"Modo de farm","mode",C.Core.enums.mode,function(mode)
        if mode~="Off" and mode~="Fruit" and mode~="Chest" then C:set("attack",true) end
    end)
    UI:heading(bosses,"Bosses e recursos")
    UI:modeToggle(bosses,"Auto Farm Boss","Boss")
    UI:modeToggle(bosses,"Auto Farm Material","Material")
    UI:field(bosses,"Filtro de NPC / boss","enemy")
    UI:dropdown(bosses,"Selecionar boss","enemy",function()
        local names={""}
        for _,quest in ipairs(C.world.quests) do if quest.amount==1 and C.Core.inSea(quest.level,C:sea()) then table.insert(names,quest.enemy) end end
        for _,enemy in ipairs(C.world:enemies()) do if C.world:isBoss(enemy) then table.insert(names,enemy.Name) end end
        return names
    end)
    UI:toggle(bosses,"Aceitar quest de boss","bossQuest")
    UI:toggle(bosses,"Substituir quest atual","replaceQuest")
    UI:dropdown(bosses,"Material","material",C.Core.enums.material)
    UI:note(bosses,"Custom usa o filtro de NPC. Bones e Ectoplasm selecionam grupos conhecidos; o servidor decide os drops.")
    UI:heading(mastery,"Maestria e posicionamento")
    UI:toggle(mastery,"Trocar arma para finalizar","mastery")
    UI:dropdown(mastery,"Arma / fruta de maestria","masteryWeapon",weapons)
    UI:field(mastery,"Trocar com HP do alvo (%)","masteryHealth",true)
    UI:field(mastery,"Distancia do alvo","distance",true)
    UI:field(mastery,"Altura sobre o alvo","height",true)
    UI:field(mastery,"Alcance de busca","searchRadius",true)
    UI:field(mastery,"Pausar com vida abaixo (%)","pauseHealth",true)
    UI:heading(eventsPage,"Eventos e raids")
    UI:dropdown(eventsPage,"Evento selecionado","event",C.Core.enums.event)
    UI:note(eventsPage,"Event aproxima e tenta combater alvos carregados com vida reconhecida. Nao navega barcos, invoca Leviathan, quebra segmentos nem coleta o coracao. Raid atua numa raid ja iniciada.")
    UI:button(eventsPage,"Iniciar modo Event",function() C:set("mode","Event"); C:set("attack",true) end)
    UI:button(eventsPage,"Iniciar modo Raid",function() C:set("mode","Raid"); C:set("attack",true) end)
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
    UI:heading(esp,"Visual / ESP")
    UI:toggle(esp,"ESP jogadores / HP / distancia","espPlayers")
    UI:toggle(esp,"ESP NPCs","espEnemies")
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
    local destinationBox=make("TextBox",{Position=UDim2.new(0.52,0,0,8),Size=UDim2.new(0.48,-10,0,28),BackgroundColor3=color.side,TextColor3=color.text,Text="",PlaceholderText="Nome do local",ClearTextOnFocus=false,TextSize=12,BorderSizePixel=0},destinationRow)
    local locationList=UI:note(travel,"")
    UI:button(travel,"Listar ilhas e locais detectados",function() locationList.Text=C.world:locationNames("locations"); locationList.Visible=true end)
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
        events.Visible=true; events.Text="Lua: "..C.Lighting:GetMoonPhase().." | Objetos: "..C.world:locationNames("race")
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
    UI:toggle(esp,"ESP de baus","espChests")
    UI:button(misc,"Iniciar coleta de baus",function() C:set("mode","Chest") end)
    UI:field(esp,"Limite de objetos com ESP","espLimit",true)
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
    UI.pages["Auto Farm"].Visible=true; UI.tabButtons["Auto Farm"].TextColor3=color.text; UI.tabButtons["Auto Farm"].BackgroundColor3=color.selected; UI.markers["Auto Farm"].Visible=true
    C:job("ui-status",0.5,function()
        footer.Text=string.format("Sea %s  ·  Lv %d  ·  %d FPS  ·  %s\n%s",tostring(C:sea() or "?"),C:level(),math.floor(C.state.fps),C.config.mode,C.state.status)
    end)
    return UI
end
