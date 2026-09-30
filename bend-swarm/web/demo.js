import {Renderer} from './renderer.js';
const catalog={
 meadow:{title:'Meadow',category:'WIND & GROWTH',description:'Hold a little breeze in your hand.',population:'4,096 grass blades · 32,768 triangles',help:'Hold or drag on the meadow to send a gust through the grass. Choose Calm, Breeze, or Strong wind. Space pauses; R resets.',load:()=>import('./adapters/meadow.bend')},
 cloth:{title:'Cloth',category:'SOFT BODIES',description:'Pull a corner. Feel a little tension.',population:'8 × 8 simulation · 16 × 16 surface · Web detail',help:'Drag the fabric to pull it. W switches the wind on or off. Space pauses; R resets. The two opposite corners remain pinned.',load:()=>import('./adapters/cloth.bend')},
 life:{title:'Particle Life',category:'EMERGENT SYSTEMS',description:'Six species. A few rules. Unexpected company.',population:'2,048 particles · Web population',help:'Hold the pointer to attract particles; right-click to repel. Try Islands, Chasers, or Random rules. Space pauses; R reseeds.',load:()=>import('./adapters/life.bend')},
 swarm:{title:'Swarm',category:'COLLECTIVE MOTION',description:'Give a flock a nudge and watch the idea spread.',population:'2,048 boids · Web population',help:'Hold the pointer to attract the flock; right-click to repel it. Release to let the flock find its own way. Space pauses; R resets.',load:()=>import('./adapters/swarm.bend')},
 monochrome:{title:'Monochrome',category:'KINETIC SCULPTURE',description:'A study in light, shape, and quiet movement.',population:'Live geometry · Shared camera and clipping',help:'Drag to orbit. W/S zoom, A/D pan, E/C move vertically. I/J/K/L look. O switches perspective; F switches between orbit and free flight. Space pauses the sculpture; the camera stays active.',load:()=>import('./adapters/camera.bend')},
 voxels:{title:'Voxels',category:'EDITABLE WORLDS',description:'Carve a tunnel. Add a block. Make it yours.',population:'32 × 16 × 32 editable world · Cached chunks',help:'Click to carve; right-click to add a block. Middle-drag to orbit, or choose the Orbit tool. W/S zoom, A/D pan, E/C rise or descend, I/J/K/L look. O switches perspective; F switches to free flight. R rebuilds the original landscape.',load:()=>import('./adapters/camera.bend')}
};
const $=id=>document.getElementById(id),name=new URLSearchParams(location.search).get('scene')||'meadow',entry=catalog[name]||catalog.meadow,id=catalog[name]?name:'meadow';
const camera=id==='voxels'||id==='monochrome',particles=id==='life'||id==='swarm';
let api,state,renderer,paused=false,wind=true,preset=1,seed=42,time=0,mx=.5,my=.5,power=0,grab=0xffffffff,grabDepth=7.5,active=true,dirty=true,last=0,frameCount=0,costs=[],tool='carve';
const keys=new Set(),palette=[5304258,16758619,15429309,6921215,15982954,9927665],canvas=$('demo');
const unwrap=r=>{if(r.$==='Fail')throw new Error(r.error||r.message||r.value||'The simulation could not continue.');return r.value;};
$('title').textContent=entry.title;$('category').textContent=entry.category;$('description').textContent=entry.description;$('population').textContent=entry.population;$('instructions').textContent=entry.help;document.title=entry.title+' — Bend playground';canvas.setAttribute('aria-label',entry.title+'. '+entry.help);
function extra(label,action){const b=document.createElement('button');b.textContent=label;b.onclick=()=>{action(b);dirty=true;canvas.focus({preventScroll:true});};$('extras').append(b);return b;}
function reset(){grab=0xffffffff;time=0;seed++;state=camera?api.create(id==='voxels'):id==='meadow'?api.create():unwrap(id==='life'?api.create(seed):api.create());paused=false;$('pause').firstChild.textContent='Pause ';dirty=true;}
function pause(){paused=!paused;if(camera){state=api.key(32,true,state);state=api.key(32,false,state);}else dirty=true;$('pause').firstChild.textContent=paused?'Resume ':'Pause ';}
function fail(error){$('loading').hidden=true;$('error').hidden=false;$('error').textContent=error.message;active=false;console.error(error);}
function inputCode(e){return e.code.startsWith('Digit')?48+Number(e.code.slice(5)):e.code==='Space'?32:e.code.startsWith('Key')?e.code.slice(3).toLowerCase().charCodeAt(0):undefined;}
function simulate(dt){
 if(camera){state=api.frame(dt,state);renderer.draw(state.batch.triangles,state.batch.count);}
 else if(id==='meadow'){state=api.frame(time,preset,power,mx,my,paused,state);renderer.draw(state.triangles,32768);if(!paused)time+=1/60;}
 else if(id==='cloth'){state=unwrap(api.frame(time,wind,grab,mx*512,my*512,grabDepth,!paused,state));renderer.draw(state.triangles,450,512);if(!paused)time+=1/120;}
 else {if(!paused)state=unwrap(id==='life'?api.frame(preset,seed,mx*1024,my*1024,power,state):api.frame(mx*1024,my*1024,power,state));renderer.points(state.current,id==='swarm'?[0x9edced,0xc4e5b2,0xffd4a1]:palette,id==='swarm');if(!paused)time+=1/60;}
}
function frame(now){requestAnimationFrame(frame);if(!active||document.hidden){last=now;return;}if(!last)last=now;const dt=Math.min(.05,(now-last)/1000);if(dt<1/60-.002&&!dirty)return;last=now;if(paused&&!camera&&!dirty)return;
 try{const start=performance.now();simulate(dt);costs.push(performance.now()-start);if(costs.length>120)costs.shift();frameCount++;dirty=false;if(frameCount%30===0){const avg=costs.reduce((a,b)=>a+b,0)/costs.length;$('stats').textContent=Math.round(avg)+' ms / frame';}}catch(e){fail(e);}
}
try{
 api=(await entry.load()).default;renderer=new Renderer(canvas);reset();
 if(id==='meadow')renderer.setBackground(api.background,1024,256);else if(id==='cloth')renderer.setBackground(api.background,512,512);
 else if(camera){const gl=renderer.gl;gl.clearColor(...(id==='monochrome'?[1,1,1,1]:[.78,.85,.89,1]));}
 if(id==='meadow'||id==='life')for(const [i,label] of (id==='meadow'?['Calm','Breeze','Strong']:['Islands','Chasers','Random']).entries())extra(label,()=>{preset=i;});
 if(id==='cloth')extra('Wind on',b=>{wind=!wind;b.textContent=wind?'Wind on':'Wind off';});
 if(camera){extra('Perspective / Ortho',()=>{state=api.key(111,false,api.key(111,true,state));});extra('Orbit / Fly',()=>{state=api.key(102,false,api.key(102,true,state));});}
 if(id==='voxels')for(const t of ['Carve','Add','Orbit'])extra(t,b=>{tool=t.toLowerCase();document.querySelectorAll('#extras button').forEach(e=>e.removeAttribute('aria-pressed'));b.setAttribute('aria-pressed','true');});
 $('pause').onclick=()=>{pause();canvas.focus({preventScroll:true});};$('reset').onclick=()=>{reset();canvas.focus({preventScroll:true});};
 $('help').onclick=()=>{$('instructions').hidden=!$('instructions').hidden;$('help').setAttribute('aria-expanded',String(!$('instructions').hidden));};
 document.addEventListener('keydown',e=>{
  if(e.ctrlKey||e.metaKey||e.altKey||e.target.closest('button')&&['Space','Enter'].includes(e.code))return;
  const c=inputCode(e);if(c===undefined)return;const recognized=camera||['Space','KeyR','KeyW','Digit1','Digit2','Digit3'].includes(e.code);if(!recognized)return;
  e.preventDefault();if(keys.has(e.code))return;keys.add(e.code);dirty=true;
  if(c>=49&&c<=51&&(id==='meadow'||id==='life'))preset=c-49;else if(c===32)pause();else if(c===114)reset();else if(camera){if(c!==113&&c!==103&&c!==27)state=api.key(c,true,state);}else if(c===119&&id==='cloth')wind=!wind;
 });
 document.addEventListener('keyup',e=>{keys.delete(e.code);const c=inputCode(e);if(camera&&c!==undefined&&c!==32)state=api.key(c,false,state);});
 const point=e=>{const r=canvas.getBoundingClientRect();mx=Math.max(0,Math.min(1,(e.clientX-r.left)/r.width));my=Math.max(0,Math.min(1,(e.clientY-r.top)/r.height));};
 canvas.addEventListener('contextmenu',e=>e.preventDefault());
 canvas.addEventListener('pointerdown',e=>{
  e.preventDefault();canvas.focus({preventScroll:true});active=true;$('inactive').hidden=true;canvas.setPointerCapture(e.pointerId);point(e);dirty=true;
  if(id==='cloth'){const r=api.pick(mx*512,my*512,state);state=r.fst;grab=r.snd.id;grabDepth=r.snd.depth;}
  else if(camera){if(id==='monochrome'||e.button===1||tool==='orbit')state=api.dragging(true,mx,my,state);else state=api.pick(mx,my,e.button===2||tool==='add',state);}
  else power=e.button===2?-1:1;
 });
 canvas.addEventListener('pointermove',e=>{point(e);if(camera)state=api.pointer(mx,my,state);dirty=true;});
 const release=()=>{power=0;grab=0xffffffff;if(camera)state=api.dragging(false,mx,my,state);dirty=true;};
 for(const event of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(event,release);
 window.addEventListener('blur',()=>{release();if(camera)for(const k of keys){const c=inputCode({code:k});if(c!==undefined)state=api.key(c,false,state);}keys.clear();active=false;$('inactive').hidden=false;});
 window.addEventListener('focus',()=>{active=true;last=0;dirty=true;$('inactive').hidden=true;});document.addEventListener('visibilitychange',()=>{release();last=0;});
 $('loading').hidden=true;canvas.focus({preventScroll:true});requestAnimationFrame(frame);
 window.demoDiagnostics=()=>({demo:id,frames:frameCount,paused,time,grab,preset,triangles:state.batch?.count||state.triangles?.length||0,medianFrameMs:[...costs].sort((a,b)=>a-b)[costs.length>>1],world:camera?state.world.$:null,rebuilt:state.world?.landscape?.rebuilt,error:$('error').hidden?null:$('error').textContent});
}catch(e){fail(e);}
