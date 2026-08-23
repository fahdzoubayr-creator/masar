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
  fs.writeFileSync(name,data); console.log(name, Math.round(n/sr*1000)+'ms');
}
const bell=(f,t,t0,dur,a)=>{ if(t<t0||t>t0+dur) return 0; const x=t-t0;
  return (Math.sin(2*Math.PI*f*x)+0.35*Math.sin(4*Math.PI*f*x)) * Math.min(1,x/a) * Math.exp(-x/dur*6); };
// نقرة الضغط
wav(process.argv[2]+'/tap.wav', sr*0.12, t=>{
  const tick=Math.sin(2*Math.PI*1900*t)*Math.exp(-t*55)*0.75*Math.min(1,t/0.0007);
  const warm=Math.sin(2*Math.PI*260*t)*Math.exp(-t*30)*0.375;
  return (tick+warm)*0.82; });
// لمس اختيار هادئ: نغمتان متموجتان
wav(process.argv[2]+'/select.wav', sr*0.16, t=>{
  const a=bell(1250,t,0,0.07,0.004)*0.55+bell(950,t,0.05,0.1,0.006)*0.7;
  return a*0.85; });
// رنين نجاح دافئ: ثلاثية كبرى متدرجة
wav(process.argv[2]+'/success.wav', sr*0.62, t=>
  (bell(1046.5,t,0,0.34,0.006)+bell(1318.5,t,0.09,0.34,0.006)+bell(1568,t,0.18,0.4,0.006))*0.42 );
// خطأ لطيف: همهمة منخفضة مضاعفة الاختلاف مع ارتجاف خفيف
wav(process.argv[2]+'/error.wav', sr*0.26, t=>{
  const env=Math.min(1,t/0.01)*Math.exp(-t*10);
  const trem=0.85+0.15*Math.sin(2*Math.PI*17*t);
  const low=(Math.sin(2*Math.PI*196*t)+Math.sin(2*Math.PI*207*t))*0.5;
  const hint=bell(520,t,0,0.06,0.003)*0.35;
  return (low*trem*0.8+hint)*env*0.72; });
// فخرفة إتمام صاعدة مع بريق
wav(process.argv[2]+'/complete.wav', sr*0.68, t=>
  (bell(784,t,0,0.22,0.005)+bell(1046.5,t,0.08,0.24,0.005)+bell(1318.5,t,0.16,0.26,0.005)
   +bell(1568,t,0.24,0.34,0.005)+bell(2093,t,0.36,0.28,0.004))*0.38 );

