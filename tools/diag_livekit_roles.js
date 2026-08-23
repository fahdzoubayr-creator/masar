// تشخيص مباشر: قوائم الغرف والمشاركين وأدوارهم من خادم البث
process.env.LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || 'APIlocalTest123';
process.env.LIVEKIT_API_SECRET =
  process.env.LIVEKIT_API_SECRET || 'localSecret456localSecret456localSecret';
const LK = { apiKey: 'APIlocalTest123', apiSecret: 'localSecret456localSecret456localSecret', url: 'ws://192.168.0.129:7880' };
const crypto = require('crypto');
const http = require('http');
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
function sign(p) {
  const h = b64({ alg: 'HS256', typ: 'JWT' });
  const b = b64(p);
  const s = crypto.createHmac('sha256', LK.apiSecret).update(`${h}.${b}`).digest('base64url');
  return `${h}.${b}.${s}`;
}
function twirp(method, body) {
  return new Promise((res, rej) => {
    const data = Buffer.from(JSON.stringify(body));
    const r = http.request({
      host: '192.168.0.129', port: 7880, path: `/twirp/livekit.RoomService/${method}`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${sign({ exp: Math.floor(Date.now() / 1000) + 60, iss: LK.apiKey, sub: 'diag', video: { roomAdmin: true, roomList: true } })}`, 'Content-Length': data.length },
      timeout: 5000,
    }, (resp) => { const c = []; resp.on('data', (x) => c.push(x)); resp.on('end', () => res(JSON.parse(Buffer.concat(c).toString() || '{}'))); });
    r.on('error', rej); r.write(data); r.end();
  });
}
(async () => {
  const lr = await twirp('ListRooms', {});
  console.log('=== LIVE ROOMS ===');
  for (const room of lr.rooms || []) {
    console.log(`room=${room.name} participants=${room.numParticipants}`);
    try {
      const lp = await twirp('ListParticipants', { room: room.name });
      for (const p of lp.participants || []) {
        let role = '?';
        try { role = JSON.parse(p.metadata || '{}').role || '?'; } catch {}
        console.log(`  - identity=${p.identity} name=${p.name} role=${role} joinedAt=${new Date(Number(p.joinedAt) * 1000).toISOString()} sid=${p.sid}`);
      }
    } catch (e) { console.log('  listParticipants fail:', e.message); }
  }
  if (!(lr.rooms || []).length) console.log('(no live rooms)');
})();
