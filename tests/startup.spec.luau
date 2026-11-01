-- Luau / startup.spec.luau / Luau CLI / regressao da inicializacao
local World=require("../src/World")
local jobs={}
local forbidden=setmetatable({},{__index=function(_,key) error("Acesso ao jogo durante abertura: "..tostring(key)) end})
local context={Core=require("../src/Core"),ReplicatedStorage=forbidden}
function context:job(name,_,callback) jobs[name]=callback end
function context:log() end
local world=World(context)
assert(not world.ready and not world.loading and not world.indexStarted)
assert(#world.quests==0)
for _,callback in pairs(jobs) do callback(100,0.016) end
assert(not world.loading and not world.indexStarted)
print("PASS abrir e manter o painel ocioso nao carrega quests nem varre o mapa")
