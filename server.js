const http = require('http');
const https = require('https');
let remoteManifestCache = { t: 0, data: null };
const FOLDER_SLUGS = {
  'التشريع المدرسي': 'tachrii_madrasii',
  'التنشيط التربوي': 'tanshit_tarbawi',
  'خطاطات ذهنية': 'khatatat_dhihniya',
  'دورات تكوينية': 'dawrat_takwiniya',
  'ديداكتيك الرياضيات': 'didactique_maths',
  'ديداكتيك اللغة الأمازيغية': 'didactique_amazigh',
  'ديداكتيك اللغة العربية': 'didactique_arabe',
  'ديداكتيك اللغة الفرنسية': 'didactique_francais',
  'ديداكتيك النشاط العلمي': 'didactique_science',
  'علوم التربية': 'ouloum_tarbiya',
  'مؤسسات الريادة': 'mouassasat_riyada',
  'مراسلات ومذكرات': 'murasilat_mudhakkirat',
  'مشروع المؤسسة المندمج': 'mashroua_muassasa',
  'التعليم الثانوي بسلكيه': 'taalim_thaanawi',
  'بنك الاسئلة': 'bank_asila',
};
const RELEASE_BASE =
  'https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v1/';
function releaseUrlFor(pdfPath) {
  const m = String(pdfPath).replace(/^\/+/, '').match(/^assets(?:\/assets)?\/review_files\/([^/]+)\/(.+)$/);
  if (!m) return null;
  const slug = FOLDER_SLUGS[m[1]];
  if (!slug) return null;
  return RELEASE_BASE + slug + '__' + m[2];
}
function toCloudFiles(entries, pagesBase) {
  return entries
    .filter((e) => e && typeof e.pdf === 'string')
    .map((e) => ({
      path: e.pdf,
      name: e.name || e.pdf,
      url: releaseUrlFor(e.pdf) || pagesBase + e.pdf.replace(/^\/+/, '').replace(/^assets\//, 'assets/assets/'),
    }));
}
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, 'build', 'web');
const PORT = Number(process.env.PORT) || 8123;

// ===== الملفات المرفوعة (صور/مستندات) — خارج مجلد البناء كي لا تُمسح عند إعادة البناء =====
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

/** الحد الأقصى لحجم الملف المرفق (20 ميغابايت). */
const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;

/** الامتدادات المسموحة للمرفقات — صور ومستندات فقط (بلا فيديو). */
const ALLOWED_IMAGE_EXTS = ['png', 'jpg', 'jpeg', 'jfif', 'jpe', 'gif', 'webp', 'bmp'];
const ALLOWED_DOC_EXTS = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'rtf',
];
const ALLOWED_ATTACHMENT_EXTS = [...ALLOWED_IMAGE_EXTS, ...ALLOWED_DOC_EXTS];

// ===== سجل القاعات الدائم (يُحفظ على القرص ويُحمَّل عند الإقلاع) =====
const DATA_FILE = path.join(__dirname, 'rooms_data.json');

/** مدة صلاحية القاعة غير المستخدمة: تُحذف تلقائياً بعد 30 يوماً بلا دخول. */
const ROOM_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.jfif': 'image/jpeg',
  '.jpe': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.pdf': 'application/pdf',
  '.map': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.rtf': 'application/rtf',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.ppt': 'application/vnd.ms-powerpoint',
  '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

const handler = async (req, res) => {
  let urlPath;
  try {
    urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    urlPath = '/';
  }

  // ===== CORS — التطبيق الويب منشور على GitHub Pages (نطاق مختلف عن الخادم) =====
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, x-file-name'
  );
  res.setHeader('Access-Control-Max-Age', '86400');

  // استجابة مسبقة (preflight) لطلبات CORS من متصفح الويب (رفع الملفات مثلاً).
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  // نقطة فحص صحة (health) لاستضافة Render — يجب أن تعيد 200.
  if (req.method === 'GET' && urlPath === '/health') {
    return json(res, 200, { ok: true });
  }

  // رابط تحميل تطبيق الأندرويد — يقرأ آخر APK مبني من مجلد البناء مباشرة،
  // فلا حاجة لنسخ الملف يدوياً بعد كل بناء.
  //   http://<ip>:8123/download-app            ← الهواتف الحديثة (arm64)
  //   http://<ip>:8123/download-app?arch=armeabi ← الهواتف القديمة قبل 2018 تقريباً
  if ((req.method === 'GET' || req.method === 'HEAD') &&
      (urlPath === '/download-app' || urlPath === '/app-release.apk')) {
    const wantOld = new URL(req.url, 'http://localhost')
      .searchParams.get('arch') === 'armeabi';
    const apkPath = path.join(__dirname,
      'build', 'app', 'outputs', 'flutter-apk',
      wantOld ? 'app-armeabi-v7a-release.apk' : 'app-arm64-v8a-release.apk');
    if (!fs.existsSync(apkPath)) {
      return json(res, 404, { error: 'لم يُبنَ التطبيق بعد — نفّذ flutter build apk --split-per-abi' });
    }
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': fs.statSync(apkPath).size,
      'Content-Disposition':
        `attachment; filename="masar-app${wantOld ? '-old' : ''}.apk"`,
      'Cache-Control': 'no-cache',
    });
    return fs.createReadStream(apkPath).pipe(res);
  }

  // ===== خدمة توكنات LiveKit — مفاتيح الإنتاج في متغيرات البيئة فقط =====
  // التطبيق لا يحمل أي سر؛ يطلب توكنه من هنا، والخادم هو من يوقّعه.
  if (urlPath.startsWith('/api/livekit')) {
    return handleLiveKitApi(req, res, urlPath);
  }

  // تحويل صفحات المتصفح من HTTP إلى HTTPS — لأن الميكروفون والكاميرا
  // محجوبان على http غير المشفّر. يُطبَّق على صفحة القاعات فقط (وليس على
  // /ws أو /uploads أو /api التي يعتمد عليها تطبيق الهاتف ويبقى عليها HTTP).
  // لا يُطبَّق عند وجود وسيط TLS (مثل Render/Cloudflare) — هناك HTTPS
  // يُدار خارجياً ولا يُعاد توجيه إليه.
  const behindProxy = String(req.headers['x-forwarded-proto'] || '')
    .split(',')[0]
    .trim();
  if (
    req.method === 'GET' &&
    !behindProxy &&
    !req.socket.encrypted &&
    (urlPath === '/' || urlPath === '/index.html')
  ) {
    const host = String(req.headers.host || `localhost:${HTTPS_PORT}`);
    const hostname = host.split(':')[0];
    res.writeHead(302, {
      Location: `https://${hostname}:${HTTPS_PORT}/`,
    });
    return res.end();
  }

  // ===== واجهة القاعات (HTTP) =====
  if (req.method === 'GET' && urlPath === '/api/rooms') {
    const viewerName =
      new URL(req.url, 'http://localhost').searchParams.get('name') || '';
    const viewerStage = normalizeStage(
      new URL(req.url, 'http://localhost').searchParams.get('stage') || ''
    );
    const viewerKey = viewerName.trim().toLowerCase();
    // عدد الحاضرين الفعلي لكل قاعة من خادم البث — أفضل جهد عند تعذره.
    let lkCounts = new Map();
    try {
      if (lkConfigured()) {
        const lr = await lkTwirp('ListRooms', {});
        for (const r of (lr && lr.rooms) || []) {
          lkCounts.set(
            String(r.name || ''),
            Number(r.numParticipants ?? r.num_participants ?? 0)
          );
        }
      }
    } catch {}
    const roomsList = [];
    for (const [id, room] of roomRegistry) {
      // عزل صارم للمراحل: عند اختيار مرحلة تُعرض قاعات تلك المرحلة فقط،
      // ولا تظهر القاعات القديمة بلا مرحلة في القوائم المرتبة.
      if (viewerStage && room.stage !== viewerStage) continue;
      // القاعات الخاصة (رمز الدعوة) تظهر للجميع في القائمة لكن رمزها
      // لا يُكشف إلا لأصحابها (المنشئ/المنسقون) — الدخول يبقى محمياً بالرمز.
      const isMember =
        !!viewerKey &&
        (room.creatorKey === viewerKey ||
          room.coordinators.some((c) => c.key === viewerKey));
      roomsList.push({
        ...roomInfo(id, room, isMember),
        participants: lkCounts.get(lkRoomName(room.name)) ?? 0,
      });
    }
    roomsList.sort((a, b) => b.createdAt - a.createdAt);
    return json(res, 200, { rooms: roomsList });
  }
  if (req.method === 'GET' && urlPath === '/api/rooms/by-code') {
    const code =
      (new URL(req.url, 'http://localhost').searchParams.get('code') || '')
        .trim()
        .toUpperCase();
    const viewerStage = normalizeStage(
      new URL(req.url, 'http://localhost').searchParams.get('stage') || ''
    );
    if (!code) return json(res, 400, { error: 'أدخل رمز الدعوة.' });
    let found = null;
    for (const room of roomRegistry.values()) {
      if (room.access === 'code' && room.inviteCode === code) {
        found = room;
        break;
      }
    }
    if (!found) {
      return json(res, 404, {
        error: 'لا توجد قاعة بهذا الرمز — تأكد من الرمز أو اطلبه من المنسق.',
      });
    }
    if (viewerStage && found.stage && found.stage !== viewerStage) {
      return json(res, 404, {
        error: 'هذه القاعة من مرحلة تعليمية أخرى — أدخل رمز قاعة من مرحلتك.',
      });
    }
    return json(res, 200, {
      room: {
        id: found.id,
        name: found.name,
        creatorName: found.creatorName,
        access: found.access,
        stage: found.stage || '',
      },
    });
  }
  if (req.method === 'POST' && urlPath === '/api/rooms') {
    const body = await readBody(req);
    const name = String(body.name || '').trim();
    const creatorName = String(body.creatorName || 'مستخدم').trim();
    const access = body.access === 'code' ? 'code' : 'public';
    const stage = normalizeStage(String(body.stage || ''));
    if (!name) return json(res, 400, { error: 'أدخل اسم القاعة.' });
    for (const room of roomRegistry.values()) {
      if (room.name.trim().toLowerCase() === name.toLowerCase()) {
        return json(res, 409, { error: 'يوجد قاعة بهذا الاسم بالفعل — اختر اسماً آخر.' });
      }
    }
    const id = createRoomId();
    const room = {
      id,
      name,
      creatorName,
      creatorKey: creatorName.toLowerCase(),
      coordinators: [{ name: creatorName, key: creatorName.toLowerCase() }],
      createdAt: Date.now(),
      access,
      lastUsedAt: Date.now(),
    };
    if (stage) room.stage = stage;
    if (access === 'code') room.inviteCode = createInviteCode();
    roomRegistry.set(id, room);
    saveRegistry();
    console.log(
      `[room-created] ${id} «${name}» بقيادة ${creatorName} (${
        access === 'code' ? `خاصة بالرمز ${room.inviteCode}` : 'عامة'
      })`
    );
    return json(res, 201, {
      room: { id, name, access, inviteCode: room.inviteCode },
    });
  }
  if (req.method === 'DELETE' && urlPath.startsWith('/api/rooms/')) {
    const key = decodeURIComponent(urlPath.slice('/api/rooms/'.length));
    const queryName =
      new URL(req.url, 'http://localhost').searchParams.get('name') || '';
    // نقبل المعرّف الداخلي أو رمز الدعوة أو اسم القاعة — العميل لا
    // يملك بالضرورة المعرّف الداخلي للقاعة.
    let foundId = null;
    let room = null;
    if (roomRegistry.has(key)) {
      foundId = key;
      room = roomRegistry.get(key);
    } else {
      const upKey = key.trim().toUpperCase();
      const lowKey = key.trim().toLowerCase();
      for (const [rid, r] of roomRegistry) {
        if (
          (r.inviteCode && r.inviteCode === upKey) ||
          String(r.name || '')
            .trim()
            .toLowerCase() === lowKey
        ) {
          foundId = rid;
          room = r;
          break;
        }
      }
    }
    if (!foundId || !room)
      return json(res, 404, { error: 'القاعة غير موجودة.' });
    if (queryName.trim().toLowerCase() !== room.creatorKey) {
      return json(res, 403, {
        error: 'يمكن للمنشئ حذف القاعة فقط.',
      });
    }
    // قاعدة صارمة: الحذف الفوري متاح دون خمسة أعضاء. عند خمسة
    // فأكثر يُرفض الحذف — على المنسق التسليم والمغادرة فقط.
    // العدّ الأول من اتصالات هذه القاعة تحديداً (دقيق لغرفتها)،
    // وإن لم تسجّل اتصالات نرجع لعدّ خادم البث شرط عدم تداخل أسماء.
    const sockSet = rooms.get(foundId);
    const occupants = sockSet ? sockSet.size : 0;
    let blockedByLive = false;
    try {
      if (occupants === 0 && lkConfigured()) {
        const rn = lkRoomName(room.name);
        const sameKeyCount = [...roomRegistry.values()].filter(
          (r) => lkRoomName(r.name) === rn
        ).length;
        if (sameKeyCount === 1) {
          const lr = await lkTwirp('ListRooms', {});
          const live = ((lr && lr.rooms) || []).find(
            (x) => String(x.name || '') === rn
          );
          const cnt = live
            ? Number(live.numParticipants ?? live.num_participants ?? 0)
            : 0;
          if (cnt >= 5) blockedByLive = true;
        }
      }
    } catch {}
    if (occupants >= 5 || blockedByLive) {
      return json(res, 403, {
        error:
          'القاعة فيها ٥ أعضاء فأكثر — لا يمكن حذفها. سلّم التنسيق ثم غادر.',
      });
    }
    roomRegistry.delete(foundId);
    const set = rooms.get(foundId);
    if (set && set.size > 0) {
      broadcast(foundId, { type: 'room-deleted' });
      for (const c of [...set]) disconnect(c);
    } else {
      rooms.delete(foundId);
      voiceRooms.delete(foundId);
      roomHosts.delete(foundId);
      chatLogs.delete(foundId);
      chatHistory.delete(foundId);
    }
    saveRegistry();
    console.log(`[room-deleted] ${foundId} «${room.name}»`);
    return json(res, 200, { ok: true });
  }

  // ===== رفع ملف مرفق (صورة/مستند) — بلا فيديو =====
  if (req.method === 'POST' && urlPath === '/api/chat-file') {
    const declaredLength = Number(req.headers['content-length']) || 0;
    if (declaredLength > MAX_ATTACHMENT_BYTES) {
      return json(res, 413, {
        error: `حجم الملف يتجاوز الحد المسموح (${MAX_ATTACHMENT_BYTES / 1024 / 1024} ميغابايت).`,
      });
    }
    const rawName = String(req.headers['x-file-name'] || 'file');
    let fileName = 'file';
    try {
      fileName = decodeURIComponent(rawName);
    } catch {
      /* تجاهل الأسماء غير الصالحة */
    }
    const mime = String(req.headers['content-type'] || '')
      .toLowerCase()
      .split(';')[0]
      .trim();

    // رفض الفيديو/الصوت صراحةً حتى لو عُدّل الامتداد.
    if (/^(video|audio)\//.test(mime)) {
      return json(res, 415, {
        error: 'الفيديو والصوت غير مدعومين — الصور والمستندات فقط.',
      });
    }

    const ext = path.extname(fileName).toLowerCase().replace('.', '');
    if (!ALLOWED_ATTACHMENT_EXTS.includes(ext)) {
      return json(res, 415, {
        error:
          'الملفات المسموحة: صور (PNG/JPG/JFIF/GIF/WebP/BMP) ومستندات (PDF/Word/Excel/PowerPoint/نصية). الفيديو غير مدعوم.',
      });
    }

    const chunks = [];
    let received = 0;
    let aborted = false;
    req.on('data', (c) => {
      received += c.length;
      if (received > MAX_ATTACHMENT_BYTES) {
        aborted = true;
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (aborted) return;
      const buf = Buffer.concat(chunks);
      if (buf.length === 0) return json(res, 400, { error: 'الملف فارغ.' });
      const safeBase = path
        .basename(fileName)
        .replace(/[^A-Za-z0-9._()\u0600-\u06FF -]/g, '_')
        .slice(0, 80);
      const stored = `${Date.now()}_${Math.random().toString(36).slice(2, 6)}_${safeBase}`;
      fs.writeFile(path.join(UPLOAD_DIR, stored), buf, (err) => {
        if (err) {
          console.error(`[upload-error] ${err.message}`);
          return json(res, 500, { error: 'تعذّر حفظ الملف على الخادم.' });
        }
        console.log(
          `[upload] ${stored} (${buf.length} bytes, ${mime || 'unknown'})`
        );
        return json(res, 200, {
          url: '/uploads/' + stored,
          name: fileName,
          size: buf.length,
          mime,
        });
      });
    });
    req.on('error', () => {
      /* تجاهل — غالباً إلغاء من العميل أو تجاوز الحجم */
    });
    return;
  }

  // ===== خدمة الملفات المرفوعة =====
  if (urlPath.startsWith('/uploads/')) {
    const rel = urlPath.slice('/uploads/'.length);
    const safe = path.basename(rel);
    const filePath = path.join(UPLOAD_DIR, safe);
    if (!filePath.startsWith(UPLOAD_DIR)) {
      res.writeHead(403);
      return res.end('Forbidden');
    }
    fs.stat(filePath, (err, stat) => {
      if (err || !stat.isFile()) {
        res.writeHead(404);
        return res.end('Not Found');
      }
      const mime = MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': mime });
      return fs.createReadStream(filePath).pipe(res);
    });
    return;
  }

  // ===== توليد كويز من ملف الدرس (PDF -> Groq -> 70 سؤالاً) =====
  if (req.method === 'POST' && urlPath === '/api/quiz/generate-from-pdf') {
    let body = '';
    req.on('data', (c) => {
      body += c;
      if (body.length > 8192) req.destroy();
    });
    req.on('end', () => {
      let payload = {};
      try {
        payload = JSON.parse(body || '{}');
      } catch {}
      const rawPath = typeof payload.path === 'string' ? payload.path : '';
      const payloadUrl = typeof payload.url === 'string' ? payload.url : '';
      if (!rawPath && !payloadUrl) return json(res, 400, { error: 'path أو url مطلوب' });
      let rel;
      let remoteUrl = '';
      if (payloadUrl) {
        // قراءة PDF من GitHub سحابياً — نطاقات مسموحة فقط
        try {
          remoteUrl = decodeURIComponent(payloadUrl);
        } catch {
          remoteUrl = payloadUrl;
        }
        const ok = /^https:\/\/([a-z0-9.-]+\.github\.io|raw\.githubusercontent\.com|github\.com|codeload\.github\.com)\//i.test(remoteUrl);
        if (!ok) return json(res, 403, { error: 'نطاق غير مسموح' });
        rel = typeof rawPath === 'string' ? rawPath : '';
      }
      try {
        rel = decodeURIComponent(String(rel || '').replace(/^\/+/, ''));
      } catch {}
      rel = rel.replace(/^assets\/assets\//, 'assets/');
      if (rel && !/^assets\/review_files\/.+\.pdf$/i.test(rel)) {
        rel = 'assets/review_files/' + rel.replace(/^assets\//, '');
      }
      const baseDir = path.join(__dirname, 'assets', 'review_files');
      const pdfFile = rel ? path.normalize(path.join(__dirname, rel)) : null;
      if (!remoteUrl) {
        if (!pdfFile || !pdfFile.startsWith(baseDir) || !pdfFile.toLowerCase().endsWith('.pdf')) {
          return json(res, 403, { error: 'مسار غير مسموح' });
        }
      }
      const groqKey = () =>
        process.env.GROQ_API_KEY ||
        (() => {
          try {
            const t = fs.readFileSync(
              path.join(__dirname, 'tools', 'ai_review', 'run_pipeline.ps1'),
              'utf8'
            );
            const m = t.match(/gsk_[A-Za-z0-9]+/);
            return m ? m[0] : null;
          } catch {
            return null;
          }
        })();

      const proceed = () => {
        const key = groqKey();
        if (!key) return json(res, 503, { error: 'GROQ_KEY_MISSING' });
        // بلا كاش دائم: كل محاولة توليد جديدة ببذرة مختلفة.
        const genDir = path.join(__dirname, 'assets', 'banks', 'generated');
        fs.mkdirSync(genDir, { recursive: true });
        const crypto = require('crypto');
        const stamp =
          Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
        const seed = crypto.randomInt(1, 0x7fffffff);
        const outFile = path.join(genDir, 'gen_' + stamp + '.json');
        const { spawn } = require('child_process');
        const scriptArgs = [path.join(__dirname, 'tools', 'quiz_from_pdf.py')];
        if (remoteUrl) {
          scriptArgs.push('--url', remoteUrl);
          if (pdfFile) scriptArgs.push('--pdf', pdfFile);
        } else {
          scriptArgs.push('--pdf', pdfFile);
        }
        scriptArgs.push(
          '--seed', String(seed),
          '--subject', String(payload.subject || ''),
          '--out', outFile
        );
        const proc = spawn('python', scriptArgs, {
          env: { ...process.env, GROQ_API_KEY: key, PYTHONIOENCODING: 'utf-8' },
          windowsHide: true,
        });
        let errTxt = '';
        const killer = setTimeout(() => proc.kill(), 480000);
        proc.stdout.on('data', () => {});
        proc.stderr.on('data', (d) => {
          errTxt += d.toString();
          if (errTxt.length > 8000) errTxt = errTxt.slice(-4000);
        });
        proc.on('error', (e) => {
          errTxt += String(e);
        });
        proc.on('close', (code) => {
          clearTimeout(killer);
          if (code === 0 && fs.existsSync(outFile)) {
            try {
              const j = JSON.parse(fs.readFileSync(outFile, 'utf8'));
              console.log('[quiz-gen] ' + (remoteUrl || rel) + ' seed=' + seed + ' -> ' + j.count + 'q');
              return json(res, 200, { cached: false, seed, ...j });
            } catch (e) {
              errTxt += String(e);
            }
          }
          console.error('[quiz-gen-fail] code=' + code + ' ' + errTxt.slice(-400));
          return json(res, 502, {
            error: 'GENERATION_FAILED',
            detail: errTxt.slice(-180),
          });
        });
      };

      if (remoteUrl) return proceed();
      fs.stat(pdfFile, (err, st) => {
        if (err || !st.isFile()) return json(res, 404, { error: 'الملف غير موجود' });
        proceed();
      });
    });
    return;
  }

  // قائمة ملفات المراجعة من القرص مباشرة — بديل عندما يكون المانيفست قديماً أو غير متاح
  if (req.method === 'GET' && urlPath.startsWith('/api/review-files/list')) {
    let parsed;
    try {
      parsed = new URL(req.url, 'http://localhost');
    } catch {
      return json(res, 400, { error: 'طلب غير صالح' });
    }
    let folder = '';
    try {
      folder = decodeURIComponent(parsed.searchParams.get('folder') || '');
    } catch {}
    const safe = folder.replace(/[\/\\]/g, '').trim();
    if (!safe) return json(res, 400, { error: 'folder مطلوب' });
    const dir = path.join(__dirname, 'assets', 'review_files', safe);
    fs.readdir(dir, (err, entries) => {
      if (err) entries = [];
      const files = (entries || [])
        .filter((f) => f.toLowerCase().endsWith('.pdf'))
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
        .map((f) => ({
          path: `assets/review_files/${safe}/${f}`,
          name: f.replace(/\.pdf$/i, ''),
          url: releaseUrlFor(`assets/review_files/${safe}/${f}`),
        }));
      const done = (files) => {
        console.log(`[review-files] ${safe} -> ${files.length} pdf`);
        return json(res, 200, { files });
      };
      if (files.length > 0) return done(files);
      // لا ملفات محلية؟ اسأل المانيفست السحابي في GitHub (مصدر الملفات الرسمي).
      const PAGES_BASE = 'https://fahdzoubayr-creator.github.io/masar/';
      const SOURCES = [
        // ????? ??????? ????? ? ???? ?? ????? ????? ??? ?????? ????? ??? ??????.
        'https://raw.githubusercontent.com/fahdzoubayr-creator/masar/main/assets/assets/review_files/manifest.json',
        PAGES_BASE + 'assets/assets/review_files/manifest.json',
      ];
      if (remoteManifestCache.data && Date.now() - remoteManifestCache.t < 300000) {
        return done(toCloudFiles(remoteManifestCache.data[safe] || [], PAGES_BASE));
      }
      const tryFetch = (i) => {
        if (i >= SOURCES.length) return done([]);
        https
          .get(SOURCES[i], { headers: { 'User-Agent': 'masar-server' } }, (r) => {
            let b = '';
            r.on('data', (c) => (b += c));
            r.on('end', () => {
              if (r.statusCode !== 200) {
                console.warn('[review-files] source', i, 'status', r.statusCode);
                return tryFetch(i + 1);
              }
              try {
                const m = JSON.parse(b);
                remoteManifestCache = { t: Date.now(), data: m };
                return done(toCloudFiles(m[safe] || [], PAGES_BASE));
              } catch (e) {
                console.warn('[review-files] parse error', e.message);
                return tryFetch(i + 1);
              }
            });
          })
          .on('error', (e) => {
            console.warn('[review-files] fetch error', e.message);
            tryFetch(i + 1);
          });
      };
      tryFetch(0);
    });
    return;
  }

  if (urlPath.endsWith('/')) urlPath += 'index.html';
  // أسماء الأصول العربية تُخزَّن مشفّرة على القرص (ترميز URL) في build/web —
  // نجرّب المسار المفكوك ثم المسار الخام (المشفر) عند خدمة الملفات الثابتة.
  const rawPath = new URL(req.url, 'http://localhost').pathname;
  const candidates = [urlPath];
  if (rawPath && rawPath !== urlPath) candidates.push(rawPath);
  for (const candidate of candidates) {
    let filePath = path.join(ROOT, candidate);
    if (!filePath.startsWith(ROOT)) {
      res.writeHead(403);
      return res.end('Forbidden');
    }
    try {
      const stat = fs.statSync(filePath);
      if (stat.isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, {
          'Content-Type': MIME[ext] || 'application/octet-stream',
          'Content-Length': stat.size,
          'Cache-Control': 'no-cache',
        });
        fs.createReadStream(filePath).pipe(res);
        return;
      }
    } catch (_) {
      // جرّب المرشح التالي
    }
  }
  res.writeHead(404);
  return res.end('Not Found');
};

// خادم HTTP (للأجهزة التي لا تصل إلى HTTPS ولتطبيق الهاتف).
const server = http.createServer(handler);

// ===== خادم إشارات WebSocket (نقل رسائل الغرفة فقط — لا يمرر الصوت/الفيديو) =====
const WS_MAGIC = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/** الغرف: room -> Set<client> */
const rooms = new Map();

/** حالة القاعات الصوتية: room -> { host, queue: [], speakers: [], muted: [] } */
const voiceRooms = new Map();

/** مشرف كل قاعة (فيديو أو صوتي): room -> peerId — قاعة واحدة لا تتضمن أكثر من مشرف. */
const roomHosts = new Map();

/** سجل رسائل الدردشة لإيصالات الوصول/القراءة: room -> Map<msgId, senderPeerId> */
const chatLogs = new Map();

/** سجل رسائل الدردشة للوافدين الجدد: room -> [message...] (آخر 100 رسالة). */
const chatHistory = new Map();

/** الحد الأقصى لرسائل السجل المرسلة لمن يدخل القاعة. */
const CHAT_HISTORY_LIMIT = 100;

function pushChatHistory(room, message) {
  if (!chatHistory.has(room)) chatHistory.set(room, []);
  const list = chatHistory.get(room);
  list.push(message);
  if (list.length > CHAT_HISTORY_LIMIT) list.splice(0, list.length - CHAT_HISTORY_LIMIT);
}

/** سجل القاعات الدائم (يُحفظ على القرص ويُحمَّل عند الإقلاع):
 *  roomId -> { id, name, creatorName, creatorKey,
 *              coordinators: [{name, key}], createdAt,
 *              access: 'public'|'code', inviteCode, lastUsedAt }
 *  القاعات الخاصة (رمز الدعوة) تبقى مسجلة لصاحبها حتى تُحذف تلقائياً
 *  بعد 30 يوماً من آخر دخول. */
const roomRegistry = new Map();

let roomSeq = 0;
function createRoomId() {
  roomSeq += 1;
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 5; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return `R${s}${roomSeq.toString(36).toUpperCase()}`;
}

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** يولّد رمز دعوة فريداً (6 أحرف) للقاعات الخاصة. */
function createInviteCode() {
  for (let attempt = 0; attempt < 50; attempt++) {
    let s = '';
    for (let i = 0; i < 6; i++) {
      s += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    }
    let clash = false;
    for (const room of roomRegistry.values()) {
      if (room.inviteCode === s) {
        clash = true;
        break;
      }
    }
    if (!clash) return s;
  }
  return `INV${Date.now().toString(36).toUpperCase()}`;
}

/** يحمّل السجل الدائم من القرص عند إقلاع الخادم. */
function loadRegistry() {
  try {
    const raw = fs.readFileSync(DATA_FILE, 'utf8');
    const data = JSON.parse(raw);
    const rooms = Array.isArray(data.rooms) ? data.rooms : [];
    let maxSeq = 0;
    for (const r of rooms) {
      if (!r || !r.id) continue;
      const access = r.access === 'code' ? 'code' : 'public';
      roomRegistry.set(r.id, {
        id: r.id,
        name: String(r.name || 'قاعة'),
        creatorName: String(r.creatorName || 'مستخدم'),
        creatorKey: String(
          r.creatorKey || String(r.creatorName || '').toLowerCase()
        ),
        coordinators: Array.isArray(r.coordinators) ? r.coordinators : [],
        createdAt: Number(r.createdAt) || Date.now(),
        access,
        stage: normalizeStage(String(r.stage || '')),
        inviteCode: access === 'code' ? String(r.inviteCode || '') : undefined,
        lastUsedAt: Number(r.lastUsedAt) || Date.now(),
      });
      const idSuffix = r.id.replace(/^R[A-Z0-9]{5}/, '');
      const seq = parseInt(idSuffix, 36);
      if (!Number.isNaN(seq) && seq > maxSeq) maxSeq = seq;
    }
    roomSeq = maxSeq;
    console.log(`[registry] load ${roomRegistry.size} room(s) from ${DATA_FILE}`);
  } catch (_) {
    // لا يوجد ملف سجل بعد — نبدأ بسجل فارغ.
  }
}

/** يحفظ السجل الدائم على القرص (بعد أي إنشاء/حذف/تغيير). */
function saveRegistry() {
  try {
    const rooms = [];
    for (const r of roomRegistry.values()) {
      rooms.push({
        id: r.id,
        name: r.name,
        creatorName: r.creatorName,
        creatorKey: r.creatorKey,
        coordinators: r.coordinators,
        createdAt: r.createdAt,
        access: r.access,
        stage: r.stage || '',
        inviteCode: r.inviteCode,
        lastUsedAt: r.lastUsedAt,
      });
    }
    fs.writeFileSync(DATA_FILE, JSON.stringify({ rooms }, null, 2), 'utf8');
  } catch (e) {
    console.error('[registry] فشل حفظ السجل:', e.message);
  }
}

/** يحدّث زمن آخر استخدام للقاعة (عند كل دخول ناجح). */
function touchRoom(id) {
  const room = roomRegistry.get(id);
  if (!room) return;
  room.lastUsedAt = Date.now();
  saveRegistry();
}

/** يحذف تلقائياً القاعات غير المستخدمة منذ 30 يوماً. */
function cleanupExpiredRooms() {
  const now = Date.now();
  let removed = 0;
  for (const [id, room] of roomRegistry) {
    const lastUse = room.lastUsedAt || room.createdAt || now;
    if (now - lastUse <= ROOM_TTL_MS) continue;
    const days = Math.floor((now - lastUse) / (24 * 60 * 60 * 1000));
    console.log(
      `[room-expired] ${id} «${room.name}» — غير مستخدمة منذ ${days} يوماً — حُذفت تلقائياً`
    );
    roomRegistry.delete(id);
    const set = rooms.get(id);
    if (set && set.size > 0) {
      broadcast(id, { type: 'room-deleted' });
      for (const c of [...set]) disconnect(c);
    } else {
      rooms.delete(id);
      voiceRooms.delete(id);
      roomHosts.delete(id);
      chatLogs.delete(id);
      chatHistory.delete(id);
    }
    removed++;
  }
  if (removed > 0) saveRegistry();
}

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      chunks.push(c);
      size += c.length;
      if (size > 1e6) req.destroy();
    });
    req.on('end', () => {
      try {
        const body = Buffer.concat(chunks).toString('utf8');
        resolve(body ? JSON.parse(body) : {});
      } catch {
        resolve({});
      }
    });
    req.on('error', () => resolve({}));
  });
}

function json(res, code, obj) {
  const buf = Buffer.from(JSON.stringify(obj), 'utf8');
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-cache',
  });
  res.end(buf);
}

// ================================================================
// ==================== LiveKit (إنتاج) ===========================
// ================================================================

/** إعدادات LiveKit — لا قيم افتراضية للأسرار: تُقرأ من البيئة حصراً. */
const LK = {
  apiKey: process.env.LIVEKIT_API_KEY || '',
  apiSecret: process.env.LIVEKIT_API_SECRET || '',
  url: process.env.LIVEKIT_URL || '',
  roomPrefix: process.env.LIVEKIT_ROOM_PREFIX || 'Ehtiraf_',
  maxParticipants: Number(process.env.LIVEKIT_MAX_PARTICIPANTS) || 50,
  /** حد الكاميرات المتزامنة في القاعة (1-2 وفق اشتراطات المشروع). */
  maxCameras: Math.min(2, Math.max(1, Number(process.env.MAX_CAMERA_PUBLISHERS) || 2)),
};

const lkConfigured = () => !!(LK.apiKey && LK.apiSecret && LK.url);

const b64urlJson = (obj) =>
  Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');

/** يوقّع توكن HS256 بنفس صيغة LiveKit. */
function lkSign(payload) {
  const header = b64urlJson({ alg: 'HS256', typ: 'JWT' });
  const body = b64urlJson(payload);
  const sig = crypto
    .createHmac('sha256', LK.apiSecret)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${sig}`;
}

/** يتحقق من توكن صادر عن هذا الخادم ويعيد حمولته أو null. */
function lkVerify(token) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const expected = crypto
    .createHmac('sha256', LK.apiSecret)
    .update(`${parts[0]}.${parts[1]}`)
    .digest('base64url');
  const a = Buffer.from(expected);
  const b = Buffer.from(parts[2]);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (!payload.exp || payload.exp * 1000 < Date.now()) return null;
    return payload;
  } catch {
    return null;
  }
}

/** ينظّف اسم القاعة المنطقي ويضيف البادئة — المرجعية للخادم لا للعميل. */
function sanitizeRoomName(input) {
  const cleaned = String(input || '')
    .trim()
    .replace(/[^A-Za-z0-9_-]/g, '_')
    .replace(/_+/g, '_');
  return cleaned || 'Room';
}
const lkRoomName = (logical) => LK.roomPrefix + sanitizeRoomName(logical);

/** حد معدل بسيط: 30 طلب توكن في الدقيقة لكل عنوان IP. */
const tokenRate = new Map();
function tokenRateLimited(ip) {
  const now = Date.now();
  const arr = (tokenRate.get(ip) || []).filter((t) => now - t < 60000);
  if (arr.length >= 30) {
    tokenRate.set(ip, arr);
    return true;
  }
  arr.push(now);
  tokenRate.set(ip, arr);
  if (tokenRate.size > 5000) tokenRate.clear();
  return false;
}

async function handleLiveKitApi(req, res, urlPath) {
  // فحص جاهزية الخدمة.
  if (req.method === 'GET' && urlPath === '/api/livekit/health') {
    return json(res, 200, { ok: true, configured: lkConfigured() });
  }

  if (!lkConfigured()) {
    return json(res, 503, { error: 'خدمة القاعات غير مهيأة على الخادم بعد.' });
  }

  // إصدار توكن انضمام — البديل الآمن للتوقيع داخل التطبيق.
  if (req.method === 'POST' && urlPath === '/api/livekit/token') {
    const ip = req.socket.remoteAddress || '?';
    if (tokenRateLimited(ip)) {
      return json(res, 429, { error: 'طلبات كثيرة — أعد المحاولة بعد قليل.' });
    }
    const body = await readBody(req);
    let logicalRoom = String(body.room || '').trim().slice(0, 64);
    const name = String(body.name || '').trim().slice(0, 48) || '?????';
    // توحيد مفتاح الغرفة: أي كود محلي/رمز دعوة/معرف دليل يُترجم إلى
    // اسم القاعة المنشورة — حتى يجتمع المنشئ والمنضم في نفس الغرفة.
    try {
      const raw = logicalRoom;
      const norm = (s) => String(s || '').trim().toLowerCase();
      let stripped = raw.startsWith('Ehtiraf_') ? raw.slice(8) : raw;
      if (stripped.endsWith('_Open')) stripped = stripped.slice(0, -5);
      for (const r of roomRegistry.values()) {
        if (
          norm(raw) === norm(r.name) ||
          raw === r.id ||
          raw === `dir_${r.id}` ||
          (r.inviteCode && r.inviteCode === raw.toUpperCase()) ||
          norm(stripped) === norm(r.name)
        ) {
          logicalRoom = r.name;
          break;
        }
      }
    } catch {}
    let role = body.role === 'coordinator' ? 'coordinator' : 'member';
    if (!logicalRoom) {
      return json(res, 400, { error: '??? ?????? ?????.', });
    }
    // مصدر الحقيقة: القاعة المنشورة ملك لمنشئها وحده. إن طلب دور
    // المنسق لقاعة منشورة يملكها غيره نُنزَّله عضواً — لا نجمان.
    if (role === 'coordinator') {
      try {
        const rn = lkRoomName(logicalRoom);
        const viewerKey = String(body.name || '').trim().toLowerCase();
        for (const r of roomRegistry.values()) {
          if (lkRoomName(r.name) === rn && r.creatorKey !== viewerKey) {
            role = 'member';
            break;
          }
        }
      } catch {}
    }
    const identity = `${role === 'coordinator' ? 'c' : 'm'}_${Date.now().toString(36)}${crypto.randomBytes(3).toString('hex')}`;
    const now = Math.floor(Date.now() / 1000);
    const ttl = 6 * 3600;
    const payload = {
      exp: now + ttl,
      nbf: now - 10,
      iat: now,
      iss: LK.apiKey,
      sub: identity,
      name,
      metadata: JSON.stringify({ role }),
      video: {
        room: lkRoomName(logicalRoom),
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        roomConfig: { maxParticipants: LK.maxParticipants },
      },
    };
    return json(res, 200, {
      url: LK.url,
      token: lkSign(payload),
      room: payload.video.room,
      identity,
      expiresIn: ttl,
    });
  }

  // إجراءات إشرافية (كتم/طرد): تتطلب توكن منسق صادراً من هذا الخادم
  // لنفس القاعة — التوقيع يثبت الصدور، والحمولة تثبت الدور.
  if (
    req.method === 'POST' &&
    (urlPath === '/api/livekit/admin/mute' ||
      urlPath === '/api/livekit/admin/remove')
  ) {
    const body = await readBody(req);
    const claims = lkVerify(body.token);
    const targetRoom = lkRoomName(String(body.room || ''));
    const identity = String(body.identity || '').slice(0, 128);
    if (!claims || !claims.video || claims.video.room !== targetRoom) {
      return json(res, 403, { error: 'توكن غير صالح لهذه القاعة.' });
    }
    let role = 'member';
    try {
      role = JSON.parse(claims.metadata || '{}').role || 'member';
    } catch {}
    if (role !== 'coordinator') {
      return json(res, 403, { error: 'الإجراء متاح للمنسق فقط.' });
    }
    if (!identity) return json(res, 400, { error: 'معرف المشارك مطلوب.' });
    try {
      if (urlPath.endsWith('/mute')) {
        await lkTwirp('MutePublishedTrack', {
          room: targetRoom,
          identity,
          muted: true,
        });
      } else {
        await lkTwirp('RemoveParticipant', { room: targetRoom, identity });
      }
      return json(res, 200, { ok: true });
    } catch (e) {
      return json(res, 502, {
        error: 'تعذر تنفيذ الإجراء على خادم البث.',
        detail: String((e && e.message) || e).slice(0, 300),
      });
    }
  }

  return json(res, 404, { error: 'غير موجود.' });
}

/**
 * نداء Twirp إلى RoomService عبر HTTPS — يُستخدم للكتم والطرد
 * وحدّ الكاميرات، بتوكن إداري قصير العمر يوقّعه الخادم نفسه.
 */
function lkTwirp(method, bodyObj) {
  return new Promise((resolve, reject) => {
    const hostPart = LK.url.replace(/^wss?:\/\//, '').replace(/\/+$/, '');
    const host = hostPart.split(':')[0];
    const port = Number(hostPart.split(':')[1]) || 443;
    // ws:// محلي يعني HTTP عادي — wss:// فقط يستخدم TLS.
    const transport = LK.url.startsWith('ws://') ? http : https;
    const adminToken = lkSign({
      exp: Math.floor(Date.now() / 1000) + 120,
      iss: LK.apiKey,
      sub: 'masar_backend',
      video: { roomAdmin: true, roomCreate: true, roomList: true },
    });
    const data = Buffer.from(JSON.stringify(bodyObj), 'utf8');
    const r2 = transport.request(
      {
        host,
        port,
        path: `/twirp/livekit.RoomService/${method}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          Authorization: `Bearer ${adminToken}`,
          'Content-Length': data.length,
        },
        timeout: 8000,
      },
      (resp) => {
        const chunks = [];
        resp.on('data', (c) => chunks.push(c));
        resp.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            resolve(text);
          } else {
            reject(new Error(`HTTP ${resp.statusCode}: ${text.slice(0, 300)}`));
          }
        });
      }
    );
    r2.on('error', reject);
    r2.on('timeout', () => r2.destroy(new Error('timeout')));
    r2.end(data);
  });
}

/**
 * مراقبة حد الكاميرات: لا يبثّ صورته أكثر من LK.maxCameras مشاركين
 * في القاعة الواحدة — أولوية للمنسق ثم الأقدم دخولاً، ويُكتم بثّ
 * الزوائد خادمياً (إنفاذ حقيقي لا اعتماداً على واجهة التطبيق).
 */
let camSweepRunning = false;
async function sweepCameraLimits() {
  if (camSweepRunning || !lkConfigured()) return;
  camSweepRunning = true;
  try {
    const rooms = JSON.parse(await lkTwirp('ListRooms', {})).rooms || [];
    for (const room of rooms) {
      const name = room.name || '';
      if (!name.startsWith(LK.roomPrefix)) continue; // قاعاتنا فقط
      let participants = [];
      try {
        const out = await lkTwirp('ListParticipants', { room: name });
        participants = JSON.parse(out).participants || [];
      } catch {
        continue; // القاعة أُغلقت ربما
      }
      const publishers = [];
      for (const p of participants) {
        const hasCam = (p.tracks || []).some(
          (t) => t.type === 'VIDEO' && !t.muted
        );
        if (hasCam) publishers.push(p);
      }
      if (publishers.length <= LK.maxCameras) continue;

      const roleOf = {};
      publishers.forEach((p) => {
        try {
          roleOf[p.identity] =
            (JSON.parse(p.metadata || '{}').role) || 'member';
        } catch {
          roleOf[p.identity] = 'member';
        }
      });
      publishers.sort((a, b) => {
        const ra = roleOf[a.identity] === 'coordinator' ? 0 : 1;
        const rb = roleOf[b.identity] === 'coordinator' ? 0 : 1;
        if (ra !== rb) return ra - rb;
        return (a.joinedAt || 0) - (b.joinedAt || 0);
      });

      for (const p of publishers.slice(LK.maxCameras)) {
        for (const t of p.tracks || []) {
          if (t.type === 'VIDEO' && !t.muted) {
            await lkTwirp('MutePublishedTrack', {
              room: name,
              identity: p.identity,
              trackSid: t.sid,
              muted: true,
            }).catch(() => {});
          }
        }
        console.log(`[livekit] camera-limit enforced in ${name} on ${p.identity}`);
      }
    }
  } catch {
    // خادم البث غير متاح مؤقتاً — نحاول في الدورة التالية بصمت.
  } finally {
    camSweepRunning = false;
  }
}
setInterval(sweepCameraLimits, 60 * 1000).unref();

// ================================================================
// ================== /LiveKit (إنتاج) ============================
// ================================================================


function roomInfo(id, room, includeInviteCode) {
  const set = rooms.get(id);
  const participants = [];
  if (set) {
    for (const c of set) {
      participants.push({
        name: c.name,
        isCoordinator: !!c.isCoordinator,
        isCreator: !!c.isCreator,
        isMonitor: !!c.isMonitor,
      });
    }
  }
  const info = {
    id,
    name: room.name,
    creatorName: room.creatorName,
    coordinators: room.coordinators.map((c) => c.name),
    activeCount: set ? set.size : 0,
    participants,
    createdAt: room.createdAt,
    access: room.access || 'public',
    stage: room.stage || '',
  };
  if (room.access === 'code' && includeInviteCode) {
    info.inviteCode = room.inviteCode;
  }
  return info;
}

/** المراحل التعليمية المعتمدة للقاعات — أي قيمة أخرى تُعدّ بلا مرحلة. */
const ROOM_STAGES = ['primary', 'middle', 'secondary'];
function normalizeStage(value) {
  return ROOM_STAGES.includes(value) ? value : '';
}

function sendFrame(socket, data) {
  const buf = Buffer.isBuffer(data) ? data : Buffer.from(String(data), 'utf8');
  const len = buf.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x81, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x81;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  socket.write(Buffer.concat([header, buf]));
}

function broadcast(room, message, except) {
  const set = rooms.get(room);
  if (!set) return;
  const payload = JSON.stringify(message);
  for (const client of set) {
    if (client === except) continue;
    sendFrame(client.socket, payload);
  }
}

function findClient(room, peerId) {
  const set = rooms.get(room);
  if (!set) return null;
  for (const client of set) {
    if (client.peerId === peerId) return client;
  }
  return null;
}

// المراقب لا يُكتم ولا يُنزع ولا يُطرد — صفته محصّنة.
function isImmune(room, peerId) {
  const c = findClient(room, peerId);
  return !!c && (c.isCoordinator || c.isCreator || c.isMonitor);
}

function isImmuneName(room, nameKey) {
  const set = rooms.get(room);
  if (!set) return false;
  for (const c of set) {
    if (c.nameKey === nameKey && (c.isCoordinator || c.isCreator || c.isMonitor)) {
      return true;
    }
  }
  return false;
}

function handleMessage(client, msg) {
  if (!msg || typeof msg !== 'object') return;
  const room = msg.room;

  switch (msg.type) {
    case 'join': {
      client.room = room;
      client.peerId = msg.peerId;
      client.name = String(msg.name || '').trim();
      client.mode = msg.mode || 'video';
      client.role = msg.role || 'participant';
      // المراقب: صلاحية كاملة — يدخل أي قاعة بلا قيود الازدواج ولا يُكتم ولا يُطرد.
      client.isMonitor = msg.isMonitor === true;
      const nameKey = client.name.toLowerCase();
      client.nameKey = nameKey;
      if (!rooms.has(room)) rooms.set(room, new Set());
      const set = rooms.get(room);

      // لا يمكن الدخول إلى قاعة غير مسجلة في السجل الدائم.
      const reg = roomRegistry.get(room);
      if (!reg) {
        console.log(`[join-rejected] ${client.name} — قاعة غير موجودة (${room})`);
        return sendFrame(client.socket, JSON.stringify({
          type: 'join-error',
          message: 'هذه القاعة غير موجودة أو حُذفت — أنشئ قاعة جديدة من القائمة.',
        }));
      }

      // القاعات الخاصة تتطلب رمز الدعوة الصحيح — المراقب يتجاوز هذا القيد.
      if (reg.access === 'code' && !client.isMonitor) {
        const sent = String(msg.inviteCode || '').trim().toUpperCase();
        if (sent !== reg.inviteCode) {
          console.log(`[join-rejected] ${client.name} — رمز دعوة خاطئ لـ ${room}`);
          return sendFrame(client.socket, JSON.stringify({
            type: 'join-error',
            message: 'رمز الدعوة غير صحيح — اطلب رمز الدعوة من منسّق القاعة.',
          }));
        }
      }

      // منع الدخول المزدوج: الاسم الموجود فعلاً في القاعة لا يدخل مرة ثانية.
      // المراقب يتجاوز هذا القيد — يدخل للمراقبة حتى لو وُجد اسم مشابه.
      if (nameKey && !client.isMonitor) {
        for (const c of set) {
          if (String(c.name || '').trim().toLowerCase() === nameKey) {
            console.log(`[join-rejected] ${client.name} — الاسم موجود بالفعل في ${room}`);
            return sendFrame(client.socket, JSON.stringify({
              type: 'join-error',
              message: 'هذا الاسم موجود بالفعل في القاعة — يُسمح بدخول واحد فقط لكل شخص.',
            }));
          }
        }
      }

      // القاعة لا تتضمن أكثر من مشرف واحد (المنشّط الأول فقط) — للحالة الصوتية القديمة.
      if (client.role === 'host') {
        const existingHost = roomHosts.get(room);
        if (existingHost && existingHost !== client.peerId) {
          console.log(`[join-rejected] ${client.name} — القاعة لها مشرف بالفعل (${room})`);
          return sendFrame(client.socket, JSON.stringify({
            type: 'join-error',
            message: 'هذه القاعة لها مشرف (منشّط) بالفعل — لا يمكن الدخول بصفة منشّط، أدخل كمشارك.',
          }));
        }
      }

      // صفة المنسق تأتي من سجل القاعة (بالاسم الموثّق من الحساب).
      client.isCoordinator = reg.coordinators.some((c) => c.key === nameKey);
      client.isCreator = nameKey === reg.creatorKey;

      set.add(client);

      // سجّل آخر استخدام للقاعة (لمنع الحذف التلقائي بعد 30 يوماً).
      touchRoom(room);

      if (client.role === 'host' && !roomHosts.has(room)) {
        roomHosts.set(room, client.peerId);
      }

      console.log(`[join] ${client.name} (${client.peerId}) دخل غرفة ${room} (${client.mode}) — الحاضرون: ${set.size}`);

      // حالة القاعة الصوتية (تستخدم أيضاً لإدارة المايك في القاعات الموحّدة).
      let vstate = voiceRooms.get(room);
      if (!vstate) {
        vstate = { host: null, queue: [], speakers: [], muted: [] };
        voiceRooms.set(room, vstate);
      }
      if (!vstate.host && client.role === 'host') vstate.host = client.peerId;

      // أرسل للوافد قائمة الحاضرين ليبدأ الاتصال بهم جميعاً.
      const members = [];
      for (const c of set) {
        if (c !== client && c.peerId) {
          members.push({
            peerId: c.peerId,
            name: c.name,
            isCoordinator: !!c.isCoordinator,
            isCreator: !!c.isCreator,
            isMonitor: !!c.isMonitor,
          });
        }
      }
      sendFrame(client.socket, JSON.stringify({ type: 'members', members }));

      // أرسل للوافد صفته في القاعة (مراقب/منسق/منشئ/حاضر).
      sendFrame(client.socket, JSON.stringify({
        type: 'your-role',
        isCoordinator: client.isCoordinator,
        isCreator: client.isCreator,
        isMonitor: client.isMonitor,
        room: {
          id: reg.id,
          name: reg.name,
          creatorName: reg.creatorName,
          coordinators: reg.coordinators.map((c) => c.name),
        },
      }));

      // أرسل للوافد سجل الرسائل السابقة في القاعة.
      const history = chatHistory.get(room);
      if (history && history.length > 0) {
        sendFrame(client.socket, JSON.stringify({
          type: 'chat-history',
          messages: history,
        }));
      }

      // أبلغ الحاضرين القدامى بوجود وافد جديد.
      broadcast(room, {
        type: 'peer-joined',
        peerId: client.peerId,
        name: client.name,
        isCoordinator: client.isCoordinator,
        isCreator: client.isCreator,
        isMonitor: client.isMonitor,
      }, client);

      // أرسل حالة القاعة الصوتية الحالية للوافد الجديد.
      sendFrame(client.socket, JSON.stringify({
        type: 'room-state',
        host: vstate.host,
        queue: vstate.queue,
        speakers: vstate.speakers,
        muted: vstate.muted,
      }));
      break;
    }
    case 'hand-raise': {
      console.log(`[hand-raise] ${client.name} (${client.peerId}) في ${room} | coord=${client.isCoordinator} | الحاضرون: ${rooms.get(room)?.size}`);
      const vstate = voiceRooms.get(room);
      if (!vstate) break;
      if (!vstate.queue.includes(client.peerId)) vstate.queue.push(client.peerId);
      broadcast(room, { type: 'queue-updated', queue: vstate.queue });
      break;
    }
    case 'cancel-hand': {
      const vstate = voiceRooms.get(room);
      if (!vstate) break;
      vstate.queue = vstate.queue.filter((id) => id !== client.peerId);
      broadcast(room, { type: 'queue-updated', queue: vstate.queue });
      break;
    }
    case 'grant-mic': {
      console.log(`[grant-mic] ${client.name} (coord=${client.isCoordinator}) -> ${msg.to} في ${room} | الحاضرون: ${rooms.get(room)?.size}`);
      const vstate = voiceRooms.get(room);
      if (!vstate || !client.isCoordinator) break;
      const target = msg.to;
      vstate.queue = vstate.queue.filter((id) => id !== target);
      if (!vstate.speakers.includes(target)) vstate.speakers.push(target);
      broadcast(room, { type: 'mic-granted', peerId: target, by: client.peerId });
      broadcast(room, { type: 'queue-updated', queue: vstate.queue });
      break;
    }
    case 'revoke-mic': {
      console.log(`[revoke-mic] ${client.name} (coord=${client.isCoordinator}) -> ${msg.to} في ${room} | الحاضرون: ${rooms.get(room)?.size}`);
      const vstate = voiceRooms.get(room);
      if (!vstate || !client.isCoordinator) break;
      const target = msg.to;
      if (isImmune(room, target)) break; // المراقب (والمنسّقون) لا يُنزعون.
      vstate.speakers = vstate.speakers.filter((id) => id !== target);
      broadcast(room, { type: 'mic-revoked', peerId: target, by: client.peerId });
      break;
    }
    case 'mute-speaker': {
      const vstate = voiceRooms.get(room);
      if (!vstate || !client.isCoordinator) break;
      const target = msg.to;
      if (isImmune(room, target)) break; // المراقب لا يُكتم.
      if (!vstate.muted.includes(target)) vstate.muted.push(target);
      broadcast(room, { type: 'mic-muted', peerId: target, by: client.peerId });
      break;
    }
    case 'unmute-speaker': {
      const vstate = voiceRooms.get(room);
      if (!vstate || !client.isCoordinator) break;
      const target = msg.to;
      vstate.muted = vstate.muted.filter((id) => id !== target);
      broadcast(room, { type: 'mic-unmuted', peerId: target, by: client.peerId });
      break;
    }
    case 'promote-coordinator': {
      const reg = roomRegistry.get(room);
      if (!reg || !client.isCoordinator) break;
      const target = String(msg.to || '').trim();
      const targetKey = target.toLowerCase();
      if (!targetKey || targetKey === client.nameKey) break;
      if (isImmuneName(room, targetKey)) break; // المراقب لا يُرقّى ولا يُنزع.
      if (!reg.coordinators.some((c) => c.key === targetKey)) {
        reg.coordinators.push({ name: target, key: targetKey });
      }
      saveRegistry();
      console.log(`[promote] ${target} أصبح منسقاً في ${room} (بواسطة ${client.name})`);
      broadcast(room, { type: 'coordinator-added', name: target });
      // إن كان الهدف متصلاً الآن: حدّث صفته فوراً.
      const set = rooms.get(room);
      if (set) for (const c of set) {
        if (c.nameKey === targetKey) {
          c.isCoordinator = true;
          sendFrame(c.socket, JSON.stringify({
            type: 'your-role',
            isCoordinator: true,
            isCreator: c.isCreator,
            isMonitor: c.isMonitor,
          }));
        }
      }
      break;
    }
    case 'remove-coordinator': {
      const reg = roomRegistry.get(room);
      if (!reg || !client.isCoordinator) break;
      const target = String(msg.to || '').trim();
      const targetKey = target.toLowerCase();
      if (!targetKey || targetKey === reg.creatorKey) break; // المنشئ لا يُنزع.
      if (isImmuneName(room, targetKey)) break; // المراقب لا يُنزع.
      const idx = reg.coordinators.findIndex((c) => c.key === targetKey);
      if (idx < 0) break;
      reg.coordinators.splice(idx, 1);
      saveRegistry();
      console.log(`[demote] ${target} لم يعد منسقاً في ${room} (بواسطة ${client.name})`);
      broadcast(room, { type: 'coordinator-removed', name: target });
      const set = rooms.get(room);
      if (set) for (const c of set) {
        if (c.nameKey === targetKey) {
          c.isCoordinator = false;
          sendFrame(c.socket, JSON.stringify({
            type: 'your-role',
            isCoordinator: false,
            isCreator: c.isCreator,
            isMonitor: c.isMonitor,
          }));
        }
      }
      break;
    }
    case 'kick': {
      const set2 = rooms.get(room);
      if (!set2 || !client.isCoordinator) break;
      const targetPeerId = String(msg.to || '');
      let target = null;
      for (const c of set2) if (c.peerId === targetPeerId) target = c;
      if (!target || isImmune(room, targetPeerId)) break; // المراقب لا يُطرد.
      console.log(`[kick] ${target.name} طُرد من ${room} (بواسطة ${client.name})`);
      sendFrame(target.socket, JSON.stringify({
        type: 'kicked',
        by: client.name,
        message: 'تم طردك من القاعة بواسطة المنسق.',
      }));
      disconnect(target);
      break;
    }
    case 'delete-room': {
      const reg = roomRegistry.get(room);
      if (!reg || reg.creatorKey !== client.nameKey) break;
      roomRegistry.delete(room);
      saveRegistry();
      const set3 = rooms.get(room);
      if (set3 && set3.size > 0) {
        console.log(`[delete-room] ${room} «${reg.name}» — غادر الجميع (بواسطة ${client.name})`);
        broadcast(room, { type: 'room-deleted' });
        for (const c of [...set3]) disconnect(c);
      } else {
        rooms.delete(room);
        voiceRooms.delete(room);
        roomHosts.delete(room);
        chatLogs.delete(room);
        chatHistory.delete(room);
      }
      break;
    }
    case 'reaction': {
      broadcast(room, {
        type: 'reaction',
        peerId: client.peerId,
        name: client.name,
        reaction: msg.reaction,
      }, client);
      break;
    }
    case 'offer':
    case 'answer':
    case 'candidate': {
      const target = findClient(room, msg.to);
      if (!target) {
        console.log(`[!] ${msg.type} إلى ${msg.to} غير موجود في ${room}`);
        return;
      }
      console.log(`[${msg.type}] ${client.peerId} -> ${msg.to} في ${room}`);
      const rawSdp = String((msg.sdp && msg.sdp.sdp) || '');
      if (rawSdp) {
        const mAudio = (rawSdp.match(/^m=audio\b/gm) || []).length;
        const mVideo = (rawSdp.match(/^m=video\b/gm) || []).length;
        const mApp = (rawSdp.match(/^m=application\b/gm) || []).length;
        const sendDirs = (rawSdp.match(/^a=sendrecv|^a=sendonly|^a=recvonly|^a=inactive/gm) || []);
        const rtcpFb = (rawSdp.match(/^a=rtcp-mux/gm) || []).length;
        console.log(`[SDP-${msg.type}] m=audio:${mAudio} m=video:${mVideo} m=application:${mApp} dirs=[${sendDirs.join(',')}] rtcp-mux:${rtcpFb} len:${rawSdp.length}`);
      }
      const relay = {
        type: msg.type,
        from: client.peerId,
        name: client.name,
        to: msg.to,
      };
      if (msg.sdp) relay.sdp = msg.sdp;
      if (msg.candidate) relay.candidate = msg.candidate;
      sendFrame(target.socket, JSON.stringify(relay));
      break;
    }
    case 'chat': {
      const msgId = String(msg.msgId || '').trim();
      const recipients = Math.max(0, (rooms.get(room)?.size || 1) - 1);
      console.log(`[chat] ${client.name} -> ${room} | المستقبلون: ${recipients} | نص: ${String(msg.text || '').slice(0, 40)}`);
      const payload = {
        type: 'chat',
        from: client.peerId,
        name: client.name,
        text: String(msg.text || ''),
        at: msg.at || Date.now(),
      };
      if (msgId) payload.msgId = msgId;
      if (msg.replyTo) payload.replyTo = msg.replyTo;
      if (Array.isArray(msg.attachments)) {
        payload.attachments = msg.attachments
          .filter((a) => a && typeof a === 'object')
          .map((a) => {
            const url = String(a.url || '');
            // نسمح فقط بالملفات المرفوعة على خادمنا — الأسماء قد تحوي
            // أحرفاً عربية ومسافات وأقواساً (نفس القاعدة التي يطبّقها الرفع).
            if (!/^\/uploads\/[A-Za-z0-9._()\u0600-\u06FF -]+$/.test(url)) return null;
            return {
              type: a.type === 'photo' ? 'photo' : 'document',
              name: String(a.name || 'ملف').slice(0, 100),
              url,
              sizeText: String(a.sizeText || '').slice(0, 20),
            };
          })
          .filter(Boolean);
      }
      broadcast(room, payload, client);
      // احفظ الرسالة في سجل القاعة ليراها من يدخل لاحقاً.
      pushChatHistory(room, payload);
      // سجّل الرسالة لإيصالات الوصول/القراءة، وأكّد للمرسل.
      if (msgId) {
        if (!chatLogs.has(room)) chatLogs.set(room, new Map());
        chatLogs.get(room).set(msgId, client.peerId);
        const recipients = Math.max(0, (rooms.get(room)?.size || 1) - 1);
        sendFrame(client.socket, JSON.stringify({
          type: 'chat-ack',
          msgId,
          delivered: recipients,
        }));
      }
      break;
    }
    case 'chat-receipt': {
      const senderId = chatLogs.get(room)?.get(String(msg.msgId || ''));
      if (senderId && senderId !== client.peerId) {
        const target = findClient(room, senderId);
        if (target) {
          sendFrame(target.socket, JSON.stringify({
            type: 'chat-receipt',
            msgId: msg.msgId,
            status: msg.status === 'read' ? 'read' : 'delivered',
          }));
        }
      }
      break;
    }
    case 'typing': {
      broadcast(room, {
        type: 'typing',
        from: client.peerId,
        name: client.name,
        active: !!msg.active,
      }, client);
      break;
    }
    case 'chat-edit': {
      const editId = String(msg.msgId || '');
      const history = chatHistory.get(room);
      if (history) {
        const hit = history.find((h) => String(h.msgId || '') === editId);
        if (hit) hit.text = String(msg.text || '');
      }
      broadcast(room, {
        type: 'chat-edit',
        msgId: msg.msgId,
        text: String(msg.text || ''),
      }, client);
      break;
    }
    case 'chat-delete': {
      const delId = String(msg.msgId || '');
      chatLogs.get(room)?.delete(delId);
      const history = chatHistory.get(room);
      if (history) {
        const idx = history.findIndex((h) => String(h.msgId || '') === delId);
        if (idx >= 0) history.splice(idx, 1);
      }
      broadcast(room, { type: 'chat-delete', msgId: msg.msgId }, client);
      break;
    }
    case 'chat-reaction': {
      broadcast(room, {
        type: 'chat-reaction',
        msgId: msg.msgId,
        from: client.peerId,
        name: client.name,
        reaction: msg.reaction,
      }, client);
      break;
    }
    case 'media-state': {
      console.log(`[media-state] ${client.name} (${client.peerId}) video=${msg.videoOn} audio=${msg.audioOn} في ${room}`);
      broadcast(room, {
        type: 'media-state',
        from: client.peerId,
        videoOn: msg.videoOn,
        audioOn: msg.audioOn,
      }, client);
      break;
    }
    case 'rtc-error': {
      console.log(`[rtc-error] ${client.peerId} [${msg.context}] ${msg.error}`);
      break;
    }
    case 'leave':
      disconnect(client);
      break;
    default:
      break;
  }
}

function disconnect(client) {
  if (!client.room) return;
  const set = rooms.get(client.room);
  if (set) {
    set.delete(client);
    // المشرف غادر — تسمح القاعة لمشرف جديد بتولي المنصب.
    if (roomHosts.get(client.room) === client.peerId) roomHosts.delete(client.room);
    if (set.size === 0) {
      rooms.delete(client.room);
      voiceRooms.delete(client.room);
      roomHosts.delete(client.room);
      chatLogs.delete(client.room);
      chatHistory.delete(client.room);
    } else {
      // في القاعات الصوتية: أزل المغادر من القائمة والمتحدثين والكتم.
      const vstate = voiceRooms.get(client.room);
      if (vstate) {
        vstate.queue = vstate.queue.filter((id) => id !== client.peerId);
        vstate.speakers = vstate.speakers.filter((id) => id !== client.peerId);
        vstate.muted = vstate.muted.filter((id) => id !== client.peerId);
        if (vstate.host === client.peerId) vstate.host = null;
        broadcast(client.room, { type: 'queue-updated', queue: vstate.queue });
      }
    }
    broadcast(client.room, { type: 'peer-left', peerId: client.peerId }, client);
  }
  client.room = null;
  try {
    client.socket.end();
  } catch (_) {}
}

function attachClient(socket) {
  const client = { socket, room: null, peerId: null, name: null };
  let buffer = Buffer.alloc(0);

  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (buffer.length >= 2) {
      const opcode = buffer[0] & 0x0f;
      const masked = (buffer[1] & 0x80) !== 0;
      let len = buffer[1] & 0x7f;
      let offset = 2;
      if (len === 126) {
        if (buffer.length < 4) break;
        len = buffer.readUInt16BE(2);
        offset = 4;
      } else if (len === 127) {
        if (buffer.length < 10) break;
        len = Number(buffer.readBigUInt64BE(2));
        offset = 10;
      }
      const maskLen = masked ? 4 : 0;
      if (buffer.length < offset + maskLen + len) break;

      const mask = masked
        ? buffer.subarray(offset, offset + 4)
        : null;
      const payload = Buffer.from(
        buffer.subarray(offset + maskLen, offset + maskLen + len)
      );
      buffer = buffer.slice(offset + maskLen + len);

      if (mask) {
        for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
      }

      if (opcode === 8) {
        // close
        try {
          socket.write(Buffer.from([0x88, 0x00]));
        } catch (_) {}
        socket.end();
        disconnect(client);
        return;
      } else if (opcode === 9) {
        // ping -> pong
        try {
          const header = Buffer.from([0x8a, payload.length]);
          socket.write(Buffer.concat([header, payload]));
        } catch (_) {}
      } else if (opcode === 10) {
        // pong: ignore
      } else if (opcode === 1) {
        // text
        try {
          handleMessage(client, JSON.parse(payload.toString('utf8')));
        } catch (_) {}
      }
    }
  });

  socket.on('close', () => disconnect(client));
  socket.on('error', () => disconnect(client));
}

function handleUpgrade(req, socket) {
  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }
  const accept = crypto
    .createHash('sha1')
    .update(key + WS_MAGIC)
    .digest('base64');
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
      'Upgrade: websocket\r\n' +
      'Connection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\n\r\n`
  );
  attachClient(socket);
}

server.on('upgrade', handleUpgrade);

// تحميل السجل الدائم وحذف القاعات المنتهية (بعد 30 يوماً بلا استخدام) —
// عند الإقلاع ثم بشكل دوري كل ساعة.
loadRegistry();
cleanupExpiredRooms();
setInterval(cleanupExpiredRooms, 60 * 60 * 1000);

// يعرض عناوين LAN الحالية عند الإقلاع — عنوان الجهاز قد يتغير تلقائياً
// (DHCP)، فمن المهم معرفة الرابط الجديد لفتح الويب من الأجهزة الأخرى.
function logLanAddresses() {
  const net = require('os').networkInterfaces();
  const v4 = [];
  for (const iface of Object.values(net)) {
    if (!iface) continue;
    for (const addr of iface) {
      if (addr.family === 'IPv4' && !addr.internal) v4.push(addr.address);
    }
  }
  if (v4.length === 0) return;
  console.log('==========================================================');
  console.log('  افتح التطبيق من هاتفك/حاسوب آخر عبر:');
  for (const ip of v4) {
    console.log(`    https://${ip}:${HTTPS_PORT}/  (أو http://${ip}:${PORT}/)`);
  }
  console.log('==========================================================');
}

server.listen(PORT, () => {
  if (fs.existsSync(ROOT)) {
    console.log(`Serving ${ROOT} at http://localhost:${PORT}`);
  } else {
    console.log(
      `[static] مجلد ${ROOT} غير موجود — يُخدم فقط /api و/ws و/uploads (التطبيق منشور على GitHub Pages).`
    );
  }
  console.log(`WebSocket signaling ready at ws://localhost:${PORT}/ws`);
  logLanAddresses();
});

// خادم HTTPS اختياري — يعمل عند وجود شهادة ذاتية في مجلد certs.
// يُستخدم للمتصفحات (المايك والكاميرا ممنوعان على http غير المشفّر).
const HTTPS_PORT = Number(process.env.HTTPS_PORT) || 8443;
const certPath = path.join(__dirname, 'certs', 'cert.pem');
const keyPath = path.join(__dirname, 'certs', 'key.pem');
if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  const httpsServer = https.createServer(
    {
      key: fs.readFileSync(keyPath),
      cert: fs.readFileSync(certPath),
    },
    handler
  );
  httpsServer.on('upgrade', handleUpgrade);
  httpsServer.listen(HTTPS_PORT, () => {
    console.log(`[HTTPS] Serving ${ROOT} at https://localhost:${HTTPS_PORT}`);
    console.log(`[HTTPS] WebSocket signaling ready at wss://localhost:${HTTPS_PORT}/ws`);
    logLanAddresses();
  });
} else {
  console.log('[HTTPS] غير مفعّل — لا توجد شهادة في مجلد certs (https://...:8443).');
}
