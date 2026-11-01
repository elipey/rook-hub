# Rook Hub 2.0

Script Luau para cliente Roblox no PC, com GUI nativa, oito módulos e distribuição em arquivo único. Nenhuma biblioteca de interface ou código de terceiros é baixado durante a execução.

**Estado da entrega:** o bundle compila no compilador oficial Luau. Os 19 testes locais passaram. Não foi executado no Roblox, em executor ou em uma sessão de Blox Fruits. Compilar e testar regras isoladas não comprova compatibilidade com o jogo, permissões do executor, confirmação de compras, dano, movimento ou aceitação de quests.

## Executar

1. Abra `rook-hub.lua`, copie seu conteúdo completo e execute no cliente PC já dentro do jogo.
2. Aguarde o diagnóstico de leitura dos módulos de quests. Escolha seu Sea manualmente em **Misc / Settings** se aparecer `Sea ?`.
3. Selecione a arma em **Auto Farm**. Nome vazio mantém a equipada; categorias como `Melee`, `Sword` e `Gun` usam o `ToolTip` do objeto.
4. Escolha um modo de farm. Modos de combate ativam o ataque automático. Noclip, habilidades, compras, mira e ESP têm controles próprios.
5. Use **End** para parar; **RightShift** abre/minimiza. O botão flutuante ROOK também recupera o painel. A tecla pode ser alterada.

`rook-hub.lua` é o arquivo completo, não um carregador remoto. Os arquivos em `src/` são as fontes para manutenção; não devem ser executados isoladamente no executor. Reexecute o bundle após trocar de servidor. Não há reinjeção automática.

## Abas e funcionamento

### Auto Farm

- **Level:** lê `ReplicatedStorage.Quests` e `GuideModule`; seleciona a missão elegível de maior nível dentro do Sea atual; resolve o NPC, navega, solicita a quest e espera confirmação no painel. Não abandona uma quest diferente sem habilitar a opção correspondente.
- **Nearest:** seleciona um NPC vivo próximo, usando o filtro opcional de nome.
- **Boss:** considera nomes das quests de objetivo único, atributo `Boss` ou indicação no nome; aguarda spawn e tenta aceitar a missão quando ela é reconhecida.
- **Material:** Bones e Ectoplasm usam grupos de NPCs conhecidos; Custom usa o filtro informado. Candy reutiliza quests por nível: o drop depende de evento sazonal e das regras do servidor.
- **Maestria:** troca para a arma/fruta de finalização quando o HP do alvo cai abaixo do percentual escolhido. O crédito de maestria é concedido pelo servidor; a troca não garante o último golpe.
- **Raid:** combate NPCs próximos à ilha detectada de uma raid já ativa. Não compra chip, inicia raid, desperta habilidades ou mata inimigos instantaneamente.
- **Event:** procura Sea Beast, Ghost Ship/Pirate Brigade ou Leviathan carregados, com vida reconhecida; aproxima e tenta utilizar o mesmo módulo de combate. É assistência genérica para alvos existentes, não automação completa desses eventos.

O modo é exclusivo: farm, coleta, combate a jogadores e navegação não disputam simultaneamente o personagem. O voo desativa o modo de farm. A vida baixa pausa movimento e combate e exige recuperação adicional antes de retomar.

### Player / Combat

- Ataque temporizado chama `Tool:Activate()` quando a ferramenta está habilitada e o alvo está no alcance. O intervalo mínimo configurável é 0,12 s. Isso não constitui comprovação de fast attack funcional ou sincronização com o combate interno de Blox Fruits.
- Aura seleciona NPCs próximos. Modo Player permite username/nickname exato ou jogador vivo mais próximo quando o campo está vazio. Nomes de exibição ambíguos são rejeitados. Permissão e dano de PvP continuam sujeitos ao servidor.
- Habilidades usam `VirtualInputManager` com as teclas Z/X/C/V/F, intervalo por tecla e liberação da entrada após o pulso. O executor pode negar essa API.
- Mira preditiva orienta a câmera ao segurar o botão direito. A previsão linear usa velocidade do alvo, distância, velocidade configurada do projétil e limite temporal; não é uma solução balística com aceleração/gravidade. Não redireciona remotes nem controla habilidades que usam outro sistema de mira.
- ESP mostra nome, vida e distância, com limite configurável e prioridade aos objetos mais próximos.
- Buso tenta ativar a habilidade se o marcador reconhecido não estiver presente. Não compra desbloqueios.

**Não implementado:** habilidades infinitas, remoção de cooldown validado pelo servidor, silent aim, garantias de acerto ou ataques sem limite. Não há botões que simulem essas funções.

### Fruits / Shop

- Fruit ESP e coleta usam ferramentas físicas replicadas no mapa. Objetos fora do streaming do cliente não aparecem.
- Store tenta resolver o nome canônico pelo catálogo e envia a ferramenta física para `StoreFruit`. Frutas não reconhecidas não recebem IDs inventados.
- Buy consulta o catálogo periodicamente e tenta comprar a fruta exata quando marcada em estoque, com preço reconhecido, saldo suficiente e orçamento restante.
- A compra na loja pode substituir a fruta equipada. O orçamento é reservado por solicitação, mesmo se a resposta for negativa ou ambígua; evita repetir gastos sem confirmação. O limite de tentativas pertence à sessão e não é zerado por desligar/ligar o botão.
- Auto Random solicita um giro ao ativar e espera pelo menos duas horas entre solicitações. Usa Beli. O orçamento do catálogo não se aplica ao giro; o controle é separado.

Nenhuma opção compra produtos em Robux ou faz compras por padrão. Respostas brutas são registradas no diagnóstico; uma chamada sem erro não é apresentada como compra confirmada.

### Teleports / Sea

- Navegação gradual para posições detectadas em `_WorldOrigin.Locations` e filhos de `workspace.Map`.
- Viagens entre Seas usam comandos de viagem reconhecidos historicamente; o servidor valida requisitos e a versão atual precisa ser testada.
- Fly usa `LinearVelocity` e WASD/Q/E. Noclip altera colisão local. Velocidade, colisão, rotação e objetos de voo são restaurados ao encerrar.
- Detecção de Mirage, templo, engrenagens e desafios por objetos carregados; navegação para os encontrados.
- Consulta de fase lunar, câmera voltada para a lua e iluminação local. A iluminação não muda a fase lunar do servidor nem conclui a condição da Mirage.

**Não implementado:** todas as ilhas por coordenadas fixas, transporte por portais especiais, bypass de anti-cheat, automação integral de Race V4, sincronização entre raças, conclusão dos desafios, spawn/segmentos/coração do Leviathan, navegação de barcos ou mecânicas específicas do Ghost Ship. Esses recursos exigem integração específica e validação que esta entrega não possui. A assistência existente não deve ser confundida com sua conclusão automática.

### Misc / Settings

- Anti-AFK tenta responder ao sinal `Player.Idled` com `VirtualUser`; não usa um loop contínuo.
- Auto Chest navega até baús reconhecidos, tenta toque/prompt quando a API existe e ignora temporariamente uma coleta sem confirmação. Não existe bypass de anti-cheat.
- Server Hop consulta no máximo três páginas da API oficial, ignora servidor atual, lotados e visitados. Low Server escolhe a menor população disponível na página elegível consultada; não garante servidor vazio ou mínimo global.
- Hop automático depende de ausência de alvos e do intervalo escolhido. Consultas têm limite de tempo e tentativas espaçadas; não usam proxies.
- Perfis ficam em `RookHub/profile-v2.json`, no armazenamento do executor, se suas APIs de arquivo existirem. Carregar preserva preferências e mantém as automações desligadas.
- Diagnóstico é copiado apenas ao clicar no botão; sem clipboard, aparece no console F9. Não há telemetria nem envio de logs.

## Organização do código

| Arquivo | Responsabilidade |
|---|---|
| `src/Core.luau` | Validação de configuração, seleção de quests, Seas, normalização e seleção de servidores. Regras testáveis sem Roblox. |
| `src/Runtime.luau` | Estado, agendador, conexões, parada, perfis, diagnóstico e canal de remotes. |
| `src/World.luau` | Índices incrementais, adaptação dos módulos do jogo, identificação de NPCs, vida, destinos e spawn. |
| `src/MotionCombat.luau` | Movimento exclusivo, voo, restauração, equipamentos, ataques, teclas e câmera. |
| `src/Farm.luau` | Máquina de estados de quest, boss, material, coleta, player, raid e evento. |
| `src/Services.luau` | Catálogo, armazenamento, compras, giro, server hop e anti-AFK. |
| `src/Visuals.luau` | ESP limitado, rótulos, iluminação e câmera lunar. |
| `src/Interface.luau` | Cinco abas, seletores pesquisáveis, campos validados, atalhos e estado da sessão. |

Os módulos são fábricas que recebem o mesmo contexto `C`, e as regras puras ficam em `Core`. O construtor empacota cada módulo em um escopo próprio; nenhuma função global do jogo é substituída. A lógica que conhece o formato de Blox Fruits fica principalmente em `World`, `Farm` e `Services`.

## Desempenho e ciclo de vida

- Um agendador no `Heartbeat`, sem criar `while true` por botão.
- Farm a 5 Hz; seleção da mira a 10 Hz; combate a 20 Hz, com temporizador separado de ataque; ESP e estado da GUI a 2 Hz; loja a cada 2 s, mas catálogo com intervalo de 120 s.
- RenderStepped só orienta a câmera para um alvo previamente selecionado. PreSimulation trata movimento e colisão local.
- A varredura inicial obtém os descendentes uma vez e classifica lotes de 250; mudanças posteriores usam eventos. A criação inicial dessa lista ainda pode custar tempo/memória em mapas grandes.
- Apenas uma chamada de `CommF_` pendente; limites por comando, sem fila ilimitada. Uma chamada sem resposta por 15 s bloqueia o canal e exige reexecutar.
- StartQuest aguarda confirmação e para após três tentativas. APIs ausentes geram diagnóstico.
- End desliga os modos, libera teclas, remove ESP e restaura alterações locais. Encerrar também desconecta eventos e cancela tarefas locais. Solicitações já enviadas ao servidor não podem ser desfeitas.
- Reinjetar solicita o encerramento da instância anterior antes de criar outra.

Não há medição real de FPS, latência ou consumo no Blox Fruits nesta entrega. Os limites reduzem trabalho redundante; não comprovam ausência de lag.

## Construir e testar

Requisitos locais de desenvolvimento: Node.js e o CLI oficial [Luau](https://github.com/luau-lang/luau/releases). O executor precisa do ambiente Roblox para rodar o bundle.

```powershell
# PowerShell / build-and-test.ps1 / PowerShell 7 / desenvolvimento local
node .\build.js
luau-compile --null .\rook-hub.lua
node .\test.js luau
```

`test.js` aceita o caminho do executável Luau como argumento. O teste do farm usa vetores simulados e o código original de `Farm.luau`; não simula a rede ou o jogo inteiro.

Verificação realizada:

- Compilação de sintaxe de todo o bundle pelo compilador oficial Luau.
- 11 testes de configuração, perfis, quests, fronteiras de Sea e servidores.
- 8 testes de transição do farm: preservação/substituição de quest, aceitação, limite de tentativas, painel desconhecido, vida baixa e modo Off.
- Análise estática de `Core.luau` e seus testes, sem diagnósticos. Os módulos Roblox não foram validados com definições completas do engine.

Pendente: execução ao vivo, aparência e interação da GUI, permissões do executor, esquema atual de quests, remotes, dano, pickups, compras, viagens, eventos e comportamento de streaming. A lista de limitações acima é parte do escopo real do código.

## Referências de integração

O código é uma implementação própria. As referências abaixo ajudaram a identificar nomes de módulos e formatos históricos; não são uma API oficial de Blox Fruits nem comprovação de compatibilidade atual.

- [PlockScripts — módulo BloxFruits](https://github.com/PlockScripts/BloxFruits/blob/main/Utils/Module.luau): Quests, GuideModule, NPCList, LevelReq e nomes de objetos.
- [AutoQuest — referência de formato](https://gist.github.com/robloxscriptings/102258023d59f5636bf44be10d34130b): tarefas e informações de NPC.
- [Referência histórica de chamadas de catálogo e giro](https://gist.github.com/ServerSad/dff2a2d307abfc3b00ca2cc1da71f2de).
- [Roblox — fronteira cliente/servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary): validação de ações, frequência e compras pelo servidor.
