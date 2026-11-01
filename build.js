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
chunks.push(`\n-- Marcadores locais identificam a ultima etapa antes de uma falha nativa.\nprint("[Rook " .. Core.version .. "] Runtime:start")\nlocal context = Runtime(Core)\nlocal ok, problem = pcall(function()\n`);
for (const name of names.slice(2)) {
  chunks.push(`    print("[Rook] ${name}:start")\n    ${name}(context)\n    print("[Rook] ${name}:ready")\n`);
}
chunks.push(`end)\nif not ok then\n    context:destroy()\n    error("Rook Hub: " .. tostring(problem))\nend\nprint("[Rook] UI ready; map and quest loading await manual activation")\n`);
const output = path.join(root, 'rook-hub.lua');
fs.writeFileSync(output, chunks.join(''), 'utf8');
process.stdout.write(`Bundle: ${fs.statSync(output).size} bytes\n`);
