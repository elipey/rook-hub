-- Luau / farm.spec.luau / Luau CLI / transicoes do farm
-- O runner injeta apenas os tipos geometricos; a maquina de estados e a original.
return function(Farm,Core,vector)
    local passed=0
    local function test(name,callback)
        local ok,problem=pcall(callback)
        assert(ok,name..": "..tostring(problem)); passed=passed+1; print("PASS "..name)
    end
    local function fixture()
        local C={Core=Core,config=Core.config(),state={emptySince=os.clock()},jobs={},calls={},world={},motion={}}
        C.config.mode="Level"
        local root={Position=vector(0,0,0)}
        local humanoid={Health=100,MaxHealth=100}
        local W=C.world
        W.ready=true; W.quests=Core.questRecords({BanditQuest={{LevelReq=1,Task={Bandit=5}}}})
        W.questStatus="none"
        function W:questState() return self.questStatus end
        function W:questPosition() return vector(0,0,0) end
        function W:enemies() return {} end
        function W:nearest() return nil end
        function W:spawnFor() return nil end
        function C:level() return 5 end
        function C:sea() return 1 end
        function C:character() return {},root,humanoid end
        function C:job(name,_,callback) self.jobs[name]=callback end
        function C:status(text) self.state.status=text end
        function C:notify(text) self.state.status=text end
        function C:log() end
        function C:set(key,value) self.config[key]=value end
        function C:remote(command,args) table.insert(self.calls,{command=command,args=args}); return true end
        function C.motion:go(position) C.state.destination=position end
        local farm=Farm(C)
        return C,farm,humanoid
    end
    test("quest existente nao e abandonada sem opcao explicita",function()
        local C=fixture(); C.world.questStatus="other"; C.jobs.farm(os.clock())
        assert(#C.calls==0 and C.state.target==nil)
    end)
    test("substituicao explicita chama apenas AbandonQuest",function()
        local C=fixture(); C.world.questStatus="other"; C.config.replaceQuest=true; C.jobs.farm(os.clock())
        assert(#C.calls==1 and C.calls[1].command=="AbandonQuest")
    end)
    test("quest reconhecida nao repete StartQuest",function()
        local C=fixture(); C.world.questStatus="match"; C.jobs.farm(os.clock())
        assert(#C.calls==0)
    end)
    test("aceitacao de quest envia id e indice",function()
        local C=fixture(); C.jobs.farm(os.clock())
        assert(#C.calls==1 and C.calls[1].command=="StartQuest")
        assert(C.calls[1].args[1]=="BanditQuest" and C.calls[1].args[2]==1)
    end)
    test("quest sem confirmacao para depois de tres tentativas",function()
        local C,farm=fixture()
        for _=1,4 do farm.nextQuest=0; C.jobs.farm(os.clock()) end
        assert(#C.calls==3 and C.config.mode=="Off")
    end)
    test("painel desconhecido nao gera chamadas",function()
        local C=fixture(); C.world.questStatus="unknown"; C.jobs.farm(os.clock())
        assert(#C.calls==0)
    end)
    test("vida baixa cancela movimento e usa histerese",function()
        local C,_,humanoid=fixture(); humanoid.Health=10; C.state.destination="anterior"; C.jobs.farm(os.clock())
        assert(C.state.paused and C.state.destination==nil and #C.calls==0)
        humanoid.Health=20; C.jobs.farm(os.clock()); assert(C.state.paused)
        humanoid.Health=35; C.jobs.farm(os.clock()); assert(not C.state.paused and #C.calls==1)
    end)
    test("modo Off nao aceita quest nem altera destino manual",function()
        local C=fixture(); C.config.mode="Off"; C.state.destination="manual"; C.jobs.farm(os.clock())
        assert(#C.calls==0 and C.state.destination=="manual")
    end)
    print("Farm: "..passed.." testes passaram.")
end
