import assert from 'node:assert/strict';
import B from '../../engine/render/batch.bend';
import Font from '../../demos/turn/font.bend';
import V from '../../demos/turn/view.bend';
import L from '../../demos/turn/levels.bend';
import M from '../../engine/render/mesh.bend';
import Coverage from '../../engine/render/coverage.bend';
import TextCoverage from '../../demos/turn/text-coverage.bend';

assert.ok(Font.measure('III',1)<Font.measure('WWW',1),'real proportional advances');
for(let level=0;level<L.count();level++){
  assert.ok(Font.measure(L.title(level),.95)<118,'chapter title fits its card');
  assert.ok(Font.measure(L.title(level),1.05)<133,'HUD title fits');
  assert.ok(Font.measure(L.hint(level),1)<448,'hint fits the picker');
}
assert.ok(Font.measure('TAB  CHAPTERS',.95)+Font.measure('BACKSPACE / DELETE  RESTART',.95)+24<448,'restart and picker labels stay separate');
for(const ch of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !+,-./:<>?'){
  const g=Font.text(ch,10,10,1,0xffffff,B.create(512));
  assert.ok(ch===' '?g.count===0:g.count>0,'supported character has outlines');
  for(const t of g.triangles.slice(0,g.count)){
    assert.ok(TextCoverage.is_text(t),'glyph is in the covered text layer');
    for(const p of [t.a,t.b,t.c])assert.ok(p.x>=20&&p.x<=20+2*Font.advance(ch.charCodeAt(0))+.01);
  }
}

// Compare complete 8x8 tiles with a full-coverage reference. A colored panel
// behind a curved glyph catches bad counters and background blending. Tiles
// outside the text must exactly retain ordinary single-sample rasterization.
let g=V.rect_at(2,0,0,32,24,0x123456,B.create(512));
g=Font.text('O R',2.37,2.18,1.15,0xffffff,g);
const triangles=g.triangles.slice(0,g.count),bg={$:'Fragment',depth:1000,color:0x090d14};
let partial=0,covered=0,raw=0;
for(let y=0;y<48;y+=8)for(let x=0;x<64;x+=8){
  const ids=triangles.map((_,i)=>i).filter(i=>{
    const v=[triangles[i].a,triangles[i].b,triangles[i].c];
    return Math.min(...v.map(p=>p.x))<x+8&&Math.max(...v.map(p=>p.x))>=x&&Math.min(...v.map(p=>p.y))<y+8&&Math.max(...v.map(p=>p.y))>=y;
  });
  const aa=ids.some(i=>TextCoverage.is_text(triangles[i]));
  const cell=x/8+y/8*128,offsets=Array(16385).fill(0);
  offsets[cell+1]=ids.length;
  const drawing={$:'Drawing',triangles,offsets,ids:ids.length?ids:[0],pixels:Array(1048576).fill(0),background:Array(2097152).fill(bg)};
  const got=TextCoverage.raster(x,y,drawing);
  for(let py=y;py<y+8;py++)for(let px=x;px<x+8;px++){
    const ref=aa?Coverage.query(ids.length,0,px+.5,py+.5,triangles,ids,bg).result:
      ids.reduce((hit,i)=>M.sample(px+.5,py+.5,triangles[i],hit),bg);
    assert.equal(got.pixels[px+py*1024],ref.color,`text coverage at ${px},${py}`);
    if(aa&&ref.color!==0x123456&&ref.color!==0xffffff&&ref.color!==bg.color)partial++;
  }
  aa?covered++:raw++;
}
assert.ok(partial>10,'curves contain blended edge pixels');
assert.ok(covered>0&&raw>0,'both text and world raster paths are exercised');
console.log(`PASS: font metrics, 47 glyphs, chapter layouts; ${covered} covered / ${raw} ordinary tiles match reference, ${partial} blended edge pixels.`);
