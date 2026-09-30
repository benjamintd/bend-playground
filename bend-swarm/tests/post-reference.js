// Independent scalar reference. Coordinates are pixel centers; reject each
// depth sample before its bilinear weight contributes to the normalized sum.
export function defocus(get, width, x, y, radius) {
  const center=get(x,y), sum=[0,0,0]; let weight=0;
  const step=radius/Math.sqrt(2);
  for(let ky=-1;ky<=1;ky++) for(let kx=-1;kx<=1;kx++) {
    const px=Math.max(0,Math.min(width-1,x+kx*step));
    const py=Math.max(0,Math.min(width-1,y+ky*step));
    const ix=Math.floor(px),iy=Math.floor(py),fx=px-ix,fy=py-iy;
    const kernel=(kx===0?2:1)*(ky===0?2:1);
    for(let dy=0;dy<=1;dy++) for(let dx=0;dx<=1;dx++) {
      const p=get(Math.min(width-1,ix+dx),Math.min(width-1,iy+dy));
      if(Math.abs(p.depth-center.depth)>=Math.max(.2,center.depth*.1))continue;
      const w=kernel*(dx?fx:1-fx)*(dy?fy:1-fy);
      weight+=w;
      [16,8,0].forEach((shift,k)=>sum[k]+=((p.color>>>shift)&255)*w);
    }
  }
  return sum.map(v=>Math.floor(v/weight+1e-7));
}
