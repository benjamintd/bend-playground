import Bend from '../.toolchain/bend/bend2/main.ts';
import {mkdir,copyFile,writeFile,readdir,rm} from 'node:fs/promises';
import {resolve} from 'node:path';
const outdir=resolve('build/web-site');
await mkdir(outdir,{recursive:true});
for(const name of await readdir(outdir))if(name!==".vercel")await rm(resolve(outdir,name),{recursive:true,force:true});
const result=await Bun.build({entrypoints:['web/index.html','web/demo.html','demos/turn/web/index.html'],outdir,target:'browser',minify:true,splitting:true,publicPath:'/',plugins:[Bend]});
if(!result.success){for(const log of result.logs)console.error(log);process.exit(1);}
for(const output of result.outputs)console.log(output.path.replace(outdir+'/',''),output.size);
// HTML entry points retain their source-relative directory in a multi-page
// bundle. Relocate just the pages; hashed script/style URLs are root-relative.
for(const [source,destination] of [['web/index.html','index.html'],['web/demo.html','demo/index.html'],['demos/turn/web/index.html','turn/index.html']]){
 const candidates=result.outputs.filter(o=>o.path===resolve(outdir,source));
 if(candidates.length!==1)throw new Error('Missing HTML output '+source);
 await mkdir(resolve(outdir,destination,'..'),{recursive:true});await copyFile(candidates[0].path,resolve(outdir,destination));
}
await writeFile(resolve(outdir,'vercel.json'),JSON.stringify({version:2,cleanUrls:true,trailingSlash:true,headers:[{source:'/(.*)',headers:[{key:'X-Content-Type-Options',value:'nosniff'},{key:'Referrer-Policy',value:'strict-origin-when-cross-origin'},{key:'Permissions-Policy',value:'camera=(), microphone=(), geolocation=()'}]}]},null,2)+'\n');
await mkdir(resolve(outdir,'licenses'),{recursive:true});
await copyFile('demos/turn/assets/OFL.txt',resolve(outdir,'licenses/turn-outline-ofl.txt'));
console.log('Built seven Bend demos in build/web-site.');
