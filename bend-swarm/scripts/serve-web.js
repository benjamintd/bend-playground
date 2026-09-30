import {resolve,sep} from 'node:path';
const root=resolve('build/web-site');
const server=Bun.serve({hostname:'127.0.0.1',port:Number(process.env.PORT||4173),async fetch(req){
 let name;try{name=decodeURIComponent(new URL(req.url).pathname);}catch{return new Response('Bad request',{status:400});}
 let path=resolve(root,'.'+name);if(path!==root&&!path.startsWith(root+sep))return new Response('Forbidden',{status:403});
 if(name.endsWith('/'))path=resolve(path,'index.html');let file=Bun.file(path);
 if(!await file.exists()&&!name.includes('.'))file=Bun.file(resolve(path,'index.html'));
 return await file.exists()?new Response(file,{headers:{'Cache-Control':'no-store'}}):new Response('Not found',{status:404});
}});
console.log('Bend gallery: http://localhost:'+server.port);
