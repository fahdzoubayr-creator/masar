const fs = require('fs');
const sr = 44100;
function wav(name, n, fn) {
  const nF = Math.floor(n); const data = Buffer.alloc(44 + nF * 2);
  data.write('RIFF',0); data.writeUInt32LE(36+nF*2,4); data.write('WAVE',8);
  data.write('fmt ',12); data.writeUInt32LE(16,16); data.writeUInt16LE(1,20);
  data.writeUInt16LE(1,22); data.writeUInt32LE(sr,24); data.writeUInt32LE(sr*2,28);
  data.writeUInt16LE(2,32); data.writeUInt16LE(16,34);
  data.write('data',36); data.writeUInt32LE(nF*2,40);
  for (let i=0;i<nF;i++){ let v=Math.max(-1,Math.min(1,fn(i/sr))); data.writeInt16LE(Math.round(v*32767),44+i*2); }
  fs.writeFileSync(name,data); console.log(name.split(/[\\/]/).pop(), Math.round(nF/sr*1000)+'ms');
}
const bell=(f,t,t0,dur,a)=>{ if(t<t0||t>t0+dur) return 0; const x=t-t0;
  return (Math.sin(2*Math.PI*f*x)+0.35*Math.sin(4*Math.PI*f*x)) * Math.min(1,x/a) * Math.exp(-x/dur*6); };
const D = process.argv[2];
// نقرة الضغط
wav(D+'/tap.wav', sr*0.12, t=>{
  const tick=Math.sin(2*Math.PI*1900*t)*Math.exp(-t*55)*0.75*Math.min(1,t/0.0007);
  const warm=Math.sin(2*Math.PI*260*t)*Math.exp(-t*30)*0.375;
  return (tick+warm)*0.82; });
// لمس اختيار هادئ
wav(D+'/select.wav', sr*0.16, t=>{
  const a=bell(1250,t,0,0.07,0.004)*0.55+bell(950,t,0.05,0.1,0.006)*0.7;
  return a*0.85; });
// رنين نجاح دافئ
wav(D+'/success.wav', sr*0.62, t=>
  (bell(1046.5,t,0,0.34,0.006)+bell(1318.5,t,0.09,0.34,0.006)+bell(1568,t,0.18,0.4,0.006))*0.42 );
// خطأ لطيف
wav(D+'/error.wav', sr*0.26, t=>{
  const env=Math.min(1,t/0.01)*Math.exp(-t*10);
  const trem=0.85+0.15*Math.sin(2*Math.PI*17*t);
  const low=(Math.sin(2*Math.PI*196*t)+Math.sin(2*Math.PI*207*t))*0.5;
  const hint=bell(520,t,0,0.06,0.003)*0.35;
  return (low*trem*0.8+hint)*env*0.72; });
// إتمام عام
wav(D+'/complete.wav', sr*0.68, t=>
  (bell(784,t,0,0.22,0.005)+bell(1046.5,t,0.08,0.24,0.005)+bell(1318.5,t,0.16,0.26,0.005)
   +bell(1568,t,0.24,0.34,0.005)+bell(2093,t,0.36,0.28,0.004))*0.38 );
// ===== انتصار: فخرفة صاعدة + هتاف جماهيري + صفير فرح =====
{ let seed=7; const rnd=()=>{seed=(seed*1103515245+12345)&0x7fffffff; return seed/0x7fffffff*2-1;};
  let lp=0;
  wav(D+'/victory.wav', sr*1.7, t=>{
    let f=0;
    [[523.25,0,.45],[659.25,.09,.45],[783.99,.18,.5],[1046.5,.27,.85],[1318.5,.36,.85]].forEach(([fr,t0,dur])=>{
      if(t>=t0&&t<t0+dur){const x=t-t0;
        f+=(Math.sin(2*Math.PI*fr*x)+.3*Math.sin(4*Math.PI*fr*x))*Math.min(1,x/.006)*Math.exp(-x/(dur*.55));}});
    [1046.5,1318.5,1568,2093].forEach((fr,i)=>{const x=t-.48-i*.02;
      if(x>0&&x<1.05)f+=Math.sin(2*Math.PI*fr*x)*Math.exp(-x/.5)*(i===3?.11:.16);});
    const cheer=Math.min(1,Math.max(0,t)/.35)*Math.exp(-Math.max(0,t-.5)/.8)
      *(.55+.45*Math.sin(2*Math.PI*5.3*t+1)+.25*Math.sin(2*Math.PI*8.1*t));
    lp += 0.18*((rnd()*.95)-lp);
    let w=0;
    [[2600,.5],[3200,.85],[2900,1.18],[3400,1.3]].forEach(([fr,t0])=>{const x=t-t0;
      if(x>0&&x<.2){w+=Math.sin(2*Math.PI*(fr+500*Math.sin(2*Math.PI*3.2*x))*x)*Math.exp(-x/.08)*.09;}});
    return f*.38+cheer*lp*.55+w; });
}
// ===== فشل: ترومبون حزين هابط + زئير استياء منخفض =====
{ let seed=13; const rnd=()=>{seed=(seed*1103515245+12345)&0x7fffffff; return seed/0x7fffffff*2-1;};
  let lp=0;
  wav(D+'/defeat.wav', sr*2.0, t=>{
    let tb=0;
    [[233.08,0,.34,.03,.012],[207.65,.37,.34,.04,.012],[185,.74,.38,.05,.015],
     [164.81,1.16,.84,.14,.02]].forEach(([f0,t0,dur,bend,vib])=>{
      const x=t-t0; if(x<0||x>dur)return;
      const fr=f0*(1-Math.min(1,x/dur)*bend)*(1+vib*Math.sin(2*Math.PI*5.5*x)*Math.min(1,x/.15));
      const ph=2*Math.PI*fr*x;
      tb+=(Math.sin(ph)+.45*Math.sin(2*ph)+.25*Math.sin(3*ph)+.12*Math.sin(4*ph))
        *Math.min(1,x/.01)*Math.min(1,(dur-x)/.05);});
    const aw=Math.min(1,Math.max(0,t-.2)/.5)*Math.exp(-Math.max(0,t-1.15)/.65)
      *(1+.2*Math.sin(2*Math.PI*2.2*t+.6));
    lp += 0.07*((rnd()*.9)-lp);
    return tb*.34+aw*lp*.62; });
}
