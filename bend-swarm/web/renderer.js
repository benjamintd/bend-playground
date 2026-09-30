// Browser presentation only: the demos supply projected engine Mesh triangles.
// World transforms, geometry, picking, simulation and collision stay in Bend.
export class Renderer {
  constructor(canvas) {
    this.canvas=canvas;
    const gl=this.gl=canvas.getContext('webgl2',{antialias:true,alpha:false,preserveDrawingBuffer:false});
    if(!gl)throw new Error('This browser needs WebGL 2 to show the demos. Try a recent Safari, Firefox, or Chrome.');
    const shader=(type,source)=>{const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s));return s;};
    const program=(v,f)=>{const p=gl.createProgram();gl.attachShader(p,shader(gl.VERTEX_SHADER,v));gl.attachShader(p,shader(gl.FRAGMENT_SHADER,f));gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p));return p;};
    this.makeProgram=program;
    this.mesh=program(`#version 300 es
      precision highp float;
      layout(location=0) in vec3 position;layout(location=1) in float light;
      layout(location=2) in vec3 color;layout(location=3) in float mode;
      uniform float size;out vec3 ink;out float depthValue;out float lighting;flat out int kind;
      void main(){kind=int(mode);bool ortho=kind==2;bool perspectiveLight=kind==1;
        gl_Position=vec4(position.x/size*2.-1.,1.-position.y/size*2.,0.,1.);
        depthValue=ortho?position.z:1./position.z;lighting=perspectiveLight?light/position.z:light;ink=color;}`,
      `#version 300 es
      precision highp float;in vec3 ink;in float depthValue;in float lighting;flat in int kind;out vec4 result;
      void main(){float depth=kind==2?depthValue:1./depthValue;
        gl_FragDepth=clamp(1.-.1/depth,0.,1.);float l=kind==1?lighting/depthValue:lighting;
        result=vec4(clamp(ink*max(l,0.),0.,1.),1.);}`);
    this.background=program(`#version 300 es
      out vec2 uv;void main(){vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);uv=vec2(p.x,1.-p.y);gl_Position=vec4(p*2.-1.,0.,1.);}`,
      `#version 300 es
      precision highp float;in vec2 uv;uniform sampler2D colors;uniform sampler2D depths;out vec4 result;
      void main(){result=texture(colors,uv);gl_FragDepth=clamp(1.-.1/texture(depths,uv).r,0.,1.);}`);
    this.vao=gl.createVertexArray();gl.bindVertexArray(this.vao);this.buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,this.buffer);
    for(const [index,size,offset] of [[0,3,0],[1,1,12],[2,3,16],[3,1,28]]){gl.enableVertexAttribArray(index);gl.vertexAttribPointer(index,size,gl.FLOAT,false,32,offset);}
    this.storage=new Float32Array(32768*3*8);this.bytes=0;this.textures=[];
    gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.disable(gl.CULL_FACE);gl.clearColor(.035,.06,.10,1);
    canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();this.lost=true;});
    canvas.addEventListener('webglcontextrestored',()=>location.reload());
  }
  points(current,palette,swarm=false){
    const gl=this.gl,n=swarm?current.count:current.length;
    if(!this.pointProgram){
      this.pointProgram=this.makeProgram(`#version 300 es
        precision highp float;layout(location=0) in vec2 position;layout(location=1) in vec3 color;uniform float radius;out vec3 ink;
        void main(){gl_Position=vec4(position.x/512.-1.,1.-position.y/512.,0.,1.);gl_PointSize=radius;ink=color;}`,
        `#version 300 es
        precision highp float;in vec3 ink;out vec4 result;
        void main(){vec2 d=gl_PointCoord*2.-1.;float r=dot(d,d);if(r>1.)discard;float glow=exp(-r*5.)*(1.-r);result=vec4(ink*glow,1.);}`);
      this.pointVao=gl.createVertexArray();gl.bindVertexArray(this.pointVao);this.pointBuffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,this.pointBuffer);
      gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,2,gl.FLOAT,false,20,0);gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,3,gl.FLOAT,false,20,8);
      this.pointStorage=new Float32Array(8192*5);gl.bufferData(gl.ARRAY_BUFFER,this.pointStorage.byteLength,gl.DYNAMIC_DRAW);
    }
    for(let i=0;i<n;i++){const p=swarm?null:current[i],c=palette[i%palette.length],at=i*5;
      this.pointStorage[at]=swarm?current.px[i]:p.x;this.pointStorage[at+1]=swarm?current.py[i]:p.y;
      this.pointStorage[at+2]=(c>>>16&255)/255;this.pointStorage[at+3]=(c>>>8&255)/255;this.pointStorage[at+4]=(c&255)/255;
    }
    gl.viewport(0,0,this.canvas.width,this.canvas.height);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.disable(gl.DEPTH_TEST);gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE);
    gl.useProgram(this.pointProgram);gl.bindVertexArray(this.pointVao);gl.bindBuffer(gl.ARRAY_BUFFER,this.pointBuffer);gl.bufferSubData(gl.ARRAY_BUFFER,0,this.pointStorage.subarray(0,n*5));
    gl.uniform1f(gl.getUniformLocation(this.pointProgram,'radius'),(swarm?6:11)*this.canvas.width/1024);gl.drawArrays(gl.POINTS,0,n);gl.disable(gl.BLEND);gl.enable(gl.DEPTH_TEST);
  }
  setBackground(sample,size=1024,resolution=256){
    const gl=this.gl,colors=new Uint8Array(resolution*resolution*4),depths=new Float32Array(resolution*resolution);
    for(let y=0;y<resolution;y++)for(let x=0;x<resolution;x++){
      const p=sample(Math.floor((x+.5)*size/resolution),Math.floor((y+.5)*size/resolution)),i=y*resolution+x,c=p.color;
      colors[i*4]=c>>>16&255;colors[i*4+1]=c>>>8&255;colors[i*4+2]=c&255;colors[i*4+3]=255;depths[i]=p.depth||1000;
    }
    for(const t of this.textures)gl.deleteTexture(t);this.textures=[];
    for(const [i,data,internal,format,type] of [[0,colors,gl.RGBA8,gl.RGBA,gl.UNSIGNED_BYTE],[1,depths,gl.R32F,gl.RED,gl.FLOAT]]){
      const t=gl.createTexture();this.textures.push(t);gl.activeTexture(gl.TEXTURE0+i);gl.bindTexture(gl.TEXTURE_2D,t);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,i?gl.NEAREST:gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,i?gl.NEAREST:gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
      gl.texImage2D(gl.TEXTURE_2D,0,internal,resolution,resolution,0,format,type,data);
    }
  }
  draw(triangles,count,size=1024){
    if(this.lost)return;
    const gl=this.gl,needed=count*24;
    if(this.storage.length<needed)this.storage=new Float32Array(2**Math.ceil(Math.log2(needed)));
    let at=0;
    for(let i=0;i<count;i++){
      const t=triangles[i],c=t.color,r=(c>>>16&255)/255,g=(c>>>8&255)/255,b=(c&255)/255,mode=c&33554432?(c&16777216?2:1):0;
      for(let j=0;j<3;j++){const v=j===0?t.a:j===1?t.b:t.c;
        this.storage[at++]=v.x;this.storage[at++]=v.y;this.storage[at++]=v.z;this.storage[at++]=v.light;
        this.storage[at++]=r;this.storage[at++]=g;this.storage[at++]=b;this.storage[at++]=mode;
      }
    }
    gl.viewport(0,0,this.canvas.width,this.canvas.height);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
    if(this.textures.length){
      gl.useProgram(this.background);gl.bindVertexArray(null);
      for(let i=0;i<2;i++){gl.activeTexture(gl.TEXTURE0+i);gl.bindTexture(gl.TEXTURE_2D,this.textures[i]);}
      gl.uniform1i(gl.getUniformLocation(this.background,'colors'),0);gl.uniform1i(gl.getUniformLocation(this.background,'depths'),1);gl.drawArrays(gl.TRIANGLES,0,3);
    }
    gl.useProgram(this.mesh);gl.uniform1f(gl.getUniformLocation(this.mesh,'size'),size);gl.bindVertexArray(this.vao);gl.bindBuffer(gl.ARRAY_BUFFER,this.buffer);
    if(this.bytes<this.storage.byteLength){this.bytes=this.storage.byteLength;gl.bufferData(gl.ARRAY_BUFFER,this.bytes,gl.DYNAMIC_DRAW);}
    gl.bufferSubData(gl.ARRAY_BUFFER,0,this.storage.subarray(0,needed));gl.drawArrays(gl.TRIANGLES,0,count*3);
  }
}
