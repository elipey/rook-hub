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
