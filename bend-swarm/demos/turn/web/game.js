import Game from '../browser.bend';
import {Renderer} from '../../../web/renderer.js';
const $=id=>document.getElementById(id),canvas=$('game');
let p,batch,renderer,last=0,lastDraw=0,dirty=true,active=true,saveStamp='',drawTimes=[];
const keys=new Set(),codes={ArrowLeft:63234,ArrowRight:63235,ArrowUp:63232,ArrowDown:63233,Space:32,Tab:9,Enter:13,Backspace:127,Delete:127,Escape:9};
for(const c of 'adwsrhnqe123456789')codes['Key'+c.toUpperCase()]=c.charCodeAt(0);
for(let i=1;i<=9;i++)codes['Digit'+i]=48+i;
function save(){const stamp=p.level+':'+p.completed;if(stamp===saveStamp)return;saveStamp=stamp;try{localStorage.setItem('bend-turn-progress-v1',JSON.stringify({level:p.level,completed:p.completed}));}catch{}}
function key(code,down){if(code===undefined)return;p=Game.key(code,down,p);dirty=true;update();}
function tap(code){key(code,true);key(code,false);canvas.focus({preventScroll:true});}
function release(){keys.clear();p=Game.suspend(p);dirty=true;}
function update(){
 $('hints-left').textContent=Game.remaining(p)+' left';$('play-chapter').hidden=!p.menu;
 $('announcement').textContent=p.menu?'Choose a chapter with the arrow keys. Enter to play.':Game.title(p)+(p.hints.note===101?'. Restart to follow the hint route.':p.hints.note===100?'. No more rotations needed on this route.':p.hints.target?'. Rotation hint shown in blue.':'');
 save();
}
function frame(now){
 requestAnimationFrame(frame);
 if(!active||document.hidden){last=now;return;}
 if(!last)last=now;const dt=Math.min((now-last)/1000,.05);last=now;
 const oldLevel=p.level,oldComplete=p.completed;p=Game.tick(dt,p);
 if(oldLevel!==p.level||oldComplete!==p.completed)update();
 const period=Game.period(p)/1000;
 if(dirty||(period&&now-lastDraw>=period-.5)){
  const t=performance.now();batch=Game.scene(p,batch);renderer.draw(batch.triangles,batch.count);
  drawTimes.push(performance.now()-t);if(drawTimes.length>120)drawTimes.shift();lastDraw=now;dirty=false;
 }
}
try{
 let saved={};try{saved=JSON.parse(localStorage.getItem('bend-turn-progress-v1')||'{}');}catch{}
 p=Game.create(Number.isInteger(saved.level)?saved.level:0);p.completed=Number.isInteger(saved.completed)?saved.completed&0x3ffffff:0;
 batch=Game.batch();renderer=new Renderer(canvas);renderer.setBackground(Game.background,1024,128);
 $('loading').hidden=true;update();canvas.focus({preventScroll:true});requestAnimationFrame(frame);
 document.addEventListener('keydown',e=>{
  if(e.ctrlKey||e.metaKey||e.altKey||e.target.closest('button')&&['Space','Enter'].includes(e.code))return;
  const code=codes[e.code];if(code===undefined)return;e.preventDefault();active=true;$('paused').hidden=true;
  if(!keys.has(e.code)){keys.add(e.code);key(code,true);}
 });
 document.addEventListener('keyup',e=>{const code=codes[e.code];if(code!==undefined){e.preventDefault();keys.delete(e.code);key(code,false);}});
 window.addEventListener('blur',()=>{release();active=false;$('paused').hidden=false;});
 window.addEventListener('focus',()=>{last=0;active=true;$('paused').hidden=true;dirty=true;});
 document.addEventListener('visibilitychange',()=>{release();last=0;});
 canvas.addEventListener('pointerdown',()=>{active=true;last=0;$('paused').hidden=true;canvas.focus({preventScroll:true});});
 for(const [id,code] of [['hint',104],['restart',127],['chapters',9]])$(id).addEventListener('click',()=>tap(code));
 $('help').addEventListener('click',()=>{const hidden=!$('instructions').hidden;$('instructions').hidden=hidden;$('help').setAttribute('aria-expanded',String(!hidden));});
 for(const b of document.querySelectorAll('[data-key]')){
  const pointers=new Set();b.addEventListener('pointerdown',e=>{e.preventDefault();b.setPointerCapture(e.pointerId);pointers.add(e.pointerId);key(codes[b.dataset.key],true);});
  const up=e=>{if(pointers.delete(e.pointerId)&&!pointers.size)key(codes[b.dataset.key],false);};
  b.addEventListener('pointerup',up);b.addEventListener('pointercancel',up);b.addEventListener('lostpointercapture',up);
 }
 // Read-only diagnostics for smoke tests; never changes game coordinates.
 window.turnDiagnostics=()=>({level:p.level,plane:p.plane.$,position:{...p.body.position},turn:p.turn,turns:p.turns,pace:p.pace,time:p.time,hints:Game.remaining(p),target:p.hints.target,menu:p.menu,triangles:batch.count,frames:drawTimes.length,medianDrawMs:[...drawTimes].sort((a,b)=>a-b)[drawTimes.length>>1]});
}catch(error){$('loading').textContent=error.message;console.error(error);}
