// JavaScript / build.js / Node.js 18+ / Rook Hub bundle local
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const names = ['Core', 'Runtime', 'World', 'MotionCombat', 'Farm', 'Services', 'Visuals', 'Interface'];
const chunks = ['-- Luau / rook-hub.lua / Roblox client PC / Blox Fruits - compatibilidade ao vivo nao verificada\n'];
for (const name of names) {
  const source = fs.readFileSync(path.join(root, 'src', name + '.luau'), 'utf8');
  chunks.push(`\n-- ===== MODULO: ${name} =====\nlocal ${name} = (function()\n${source}\nend)()\n`);
}
chunks.push(`\n-- Inicializacao atomica: falha de modulo encerra conexoes e restaura alteracoes.\nlocal context = Runtime(Core)\nlocal ok, problem = pcall(function()\n    World(context)\n    MotionCombat(context)\n    Farm(context)\n    Services(context)\n    Visuals(context)\n    Interface(context)\nend)\nif not ok then\n    context:destroy()\n    error("Rook Hub: " .. tostring(problem))\nend\n`);
const output = path.join(root, 'rook-hub.lua');
fs.writeFileSync(output, chunks.join(''), 'utf8');
process.stdout.write(`Bundle: ${fs.statSync(output).size} bytes\n`);
