import assert from 'node:assert/strict';
import fs from 'node:fs';
for(const backend of ['cpu','gpu']) {
  const [sum,covered]=fs.readFileSync(`build/mesh-${backend}.csv`,'utf8').trim().split(',').map(Number);
  assert.equal(covered,256*256,'complete quad with no holes across tiles');
  // Shared diagonal may belong to either equal-depth triangle after scatter.
  // Red and blue differ by 16711425; all other pixels have a fixed color.
  let expected=0,diagonal=0;
  for(let y=0;y<512;y++) for(let x=0;x<512;x++) {
    let c=66051;
    if(x>=128&&x<384&&y>=128&&y<384) c=x+y<511?16711680:255;
    const px=x+.5,py=y+.5;
    const den=(240-280)*(200-180)+(180-320)*(160-280);
    const u=((240-280)*(px-180)+(180-320)*(py-280))/den;
    const v=((280-160)*(px-180)+(200-180)*(py-280))/den;
    if(u>=0&&v>=0&&1-u-v>=0) c=65280;
    if(x+y===511 && c===255) diagonal++;
    expected=(expected+c)>>>0;
  }
  const choices=new Set(Array.from({length:diagonal+1},(_,n)=>(expected+n*16711425)>>>0));
  assert.ok(choices.has(sum),`${backend}: framebuffer checksum ${sum}`);
}
console.log('PASS: native CPU/Metal mesh coverage and independent framebuffer checksum.');
