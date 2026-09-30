import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve('build/web-site');
let checked=0;
for(const name of ['index.html','demo/index.html','turn/index.html']){
 const html=fs.readFileSync(path.join(root,name),'utf8');
 for(const match of html.matchAll(/(?:src|href)="([^"#]+)"/g)){
  const url=new URL(match[1],'https://preview.test/'+name);
  if(url.origin!=='https://preview.test')continue;
  let file=path.join(root,decodeURIComponent(url.pathname));
  if(url.pathname.endsWith('/'))file=path.join(file,'index.html');
  assert.ok(fs.existsSync(file),`${name}: missing ${url.pathname}`);checked++;
 }
}
const home=fs.readFileSync(path.join(root,'index.html'),'utf8');
for(const scene of ['meadow','cloth','life','swarm','monochrome','voxels'])assert.ok(home.includes('?scene='+scene));
assert.ok(home.includes('/turn/'));
console.log(`PASS: all seven gallery entries and ${checked} page assets/links resolve in the static build.`);
