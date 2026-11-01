// JavaScript / test.js / Node.js 18+ e Luau CLI / Rook Hub
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const luau = process.argv[2] || 'luau';
const root = __dirname;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'rook-tests-'));
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const vectorMock = `
local function vector(x,y,z)
    local v={X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)}
    return setmetatable(v,{
        __sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
        __add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
    })
end
local Vector3={new=vector}
`;
try {
  cp.execFileSync(luau, [path.join(root, 'tests/core.spec.luau')], {stdio: 'inherit'});
  const runner = `${vectorMock}\nlocal Core=(function()\n${read('src/Core.luau')}\nend)()\nlocal Farm=(function()\n${read('src/Farm.luau')}\nend)()\nlocal test=(function()\n${read('tests/farm.spec.luau')}\nend)()\ntest(Farm,Core,vector)\n`;
  const target = path.join(temp, 'farm-runner.luau');
  fs.writeFileSync(target, runner);
  cp.execFileSync(luau, [target], {stdio: 'inherit'});
} finally {
  // Remove apenas o arquivo temporario que este processo acabou de criar.
  const target = path.join(temp, 'farm-runner.luau');
  if (fs.existsSync(target)) fs.unlinkSync(target);
  fs.rmdirSync(temp);
}
