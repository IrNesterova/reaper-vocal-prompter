// Finds names the script reads as globals (usually a call to a local declared
// further down the file, which crashes in REAPER at runtime).
// Usage: npm install luaparse && node tests/tools/check_globals.js Vocal_Prompter.lua
const luaparse=require('luaparse');
const src=require('fs').readFileSync(process.argv[2],'utf8');
const ast=luaparse.parse(src,{luaVersion:'5.3',scope:true,locations:true});
const allowed=new Set(['reaper','utf8','string','table','math','os','io','pcall','xpcall','error','tostring','tonumber','type','ipairs','pairs','next','select','require','package','setmetatable','getmetatable','print','VP_TEST','rawget','assert']);
const out=new Map();
(function walk(n){ if(!n||typeof n!=='object')return;
  if(n.type==='Identifier'&&n.isLocal===false&&!allowed.has(n.name)){ if(!out.has(n.name))out.set(n.name,n.loc.start.line); }
  for(const k in n){ if(k==='loc')continue; const v=n[k]; if(Array.isArray(v))v.forEach(walk); else if(v&&typeof v==='object')walk(v);} })(ast);
if(out.size){console.error('Unexpected globals:\n'+[...out].map(([k,l])=>`  ${k} (line ${l})`).join('\n'));process.exit(1);}
console.log('no unexpected globals');
