// أداة إعداد فضاء «خرائط الذهنية»
// - تنسخ صور الخطاطات الذهنية من مجلد سطح المكتب إلى أصول التطبيق
// - تنظّف العناوين (إزالة أرقام الصفحات اللاحقة) وتُصلح علامات الترقيم
// - تُصنّفها في محاور مرتَّبة وتكتب ملف الفهرس (manifest.json)
const fs = require('fs');
const path = require('path');

const SRC = 'C:/Users/JAMAL/Desktop/MINDMAPS';
const DST = 'E:/DRestore/masar_app/masar_app/assets/mindmaps';
const OUT = path.join(DST, 'manifest.json');

// المحاور: المفتاح = معرّف المحور، والقيمة = { العنوان، الكلمات المفتاحية، الأيقونة }
const CATEGORIES = [
  {
    id: 'theories',
    title: 'نظريات التعلم والتطور',
    icon: 'psychology',
    keywords: [
      'نظرية', 'النظرية', 'بيجيه', 'بيياجيه', 'بافلوف', 'باندورا', 'برونر',
      'ثورندايك', 'جاثري', 'جاردنر', 'ديوي', 'واتسون', 'سكينر', 'ماسلو',
      'نورمان', 'أوزوبل', 'إريكسون', 'الكشفية', 'خريطة شاملة لنظريات',
    ],
  },
  {
    id: 'pedagogy',
    title: 'بيداغوجيا تطبيقية',
    icon: 'school',
    keywords: [
      'بيداغوجيا', 'البيداغوجيا', 'البرنامج الحكومي', 'النموذج التنموي',
      'المشروع', 'المقاربات', 'المهارات الحياتية', 'التربية الدامجة',
      'التنمية', 'ديداكتيك', 'المرجعيات', 'المطوية',
    ],
  },
  {
    id: 'institutions',
    title: 'المجالس والمؤسسات',
    icon: 'account_balance',
    keywords: [
      'مجالس', 'المجالس', 'مجلس', 'الأندية التربوية', 'الأندية', 'مؤسسة',
      'مشروع المؤسسة', 'الحياة المدرسية', 'مدارس الريادة', 'النجاح',
      'النادي البيئي',
    ],
  },
  {
    id: 'law',
    title: 'القانون والتشريع',
    icon: 'gavel',
    keywords: [
      'القانون', 'قانون', 'التشريع', 'الاطار',
    ],
  },
  {
    id: 'activities',
    title: 'الأنشطة والممارسات',
    icon: 'sports_soccer',
    keywords: [
      'الأنشطة', 'الأنشطة الاعتيادية', 'النادي', 'النوادي', 'الرياضيات',
      'المطوية', 'الورقات', 'التعلم', 'التواصل والتنشيط', 'التنشيط',
      'دليل تدبير', 'دليل الانشطة', 'طقوس', 'rite', 'Guide',
    ],
  },
  {
    id: 'assessment',
    title: 'التقييم والاختبارات',
    icon: 'fact_check',
    keywords: [
      'التقييم', 'TIMSS', 'PIRLS', 'PNEA', 'PISA', 'الاختبارات', 'الاختبار',
    ],
  },
];

const FALLBACK = {
  id: 'misc',
  title: 'أخرى',
  icon: 'folder',
  keywords: [],
};

/**
 * عناوين بديلة لملفات لا يحمل اسمها عنواناً واضحاً — تُصنَّف وتُسمّى يدوياً
 * ليبقى الفهرس مرتّباً ومقروءاً («مراقَم»).
 */
const TITLE_OVERRIDES = {
  'images3.jpeg': { title: 'خطاطة ذهنية — مخطط عام', category: 'misc' },
  'Guide des rituels-Primaireحس حركي جدادات-4.jpg': {
    title: 'دليل الطقوس (المستوى الابتدائي) — الحس الحركي والجدادات',
    category: 'activities',
  },
  'Guide Mes rituels en lecture Niveau 8.jpg': {
    title: 'دليل طقوس القراءة — المستوى 8',
    category: 'activities',
  },
  'Guide Mes rituels en lecture Niveau 9.jpg': {
    title: 'دليل طقوس القراءة — المستوى 9',
    category: 'activities',
  },
  'Guide Mes rituels en lecture Niveau 10.jpg': {
    title: 'دليل طقوس القراءة — المستوى 10',
    category: 'activities',
  },
  'إريكسون – النمو النفسي الاجتماعي-الخطاطات (الوثيقة).jpg': {
    title: 'إريكسون — النمو النفسي الاجتماعي (الخطاطات)',
    category: 'theories',
  },
  'دليل بنك الانشطة الاعتيادية 2022-5.jpg': {
    title: 'دليل بنك الأنشطة الاعتيادية 2022',
    category: 'activities',
  },
  'ملخص ديداكتيك المواد-13.jpg': {
    title: 'ملخص ديداكتيك المواد',
    category: 'pedagogy',
  },
  'نموذج جمعية دعم مدرسة النجاح-3.jpg': {
    title: 'نموذج جمعية دعم مدرسة النجاح',
    category: 'institutions',
  },
  'ورقات من وحي المنهاج-14.jpg': {
    title: 'ورقات من وحي المنهاج',
    category: 'misc',
  },
  'قانون الاطار عام.png': {
    title: 'قانون الإطار — النص العام',
    category: 'law',
  },
};

/** يزيل لاحقة رقم الصفحة من اسم الملف: «...-4.jpg» => «...». */
function stripPageSuffix(base) {
  return base.replace(/\s*-\d+$/u, '');
}

/** ينظّف العنوان: يزيل اللاحقة الرقمية، ويصلح علامات الترقيم الفرنسية. */
function cleanTitle(fileName) {
  let t = fileName.replace(/\.[a-zA-Z0-9]+$/u, '');
  t = stripPageSuffix(t);
  t = t.replace(/\s*\(\s*/gu, ' (').replace(/\s*\)\s*/gu, ') ');
  t = t.replace(/\(\s*\)/gu, '');
  t = t.replace(/\s{2,}/gu, ' ').trim();
  // «Pédagogie X» => «X (Pédagogie)»؟ نُبقي الأصل ونضيف تمييزاً عربياً.
  return t;
}

/**
 * تطبيع النص العربي للمطابقة: إزالة التشكيل وتوحيد صور الألف والياء
 * والتاء المربوطة (بعض الملفات محفوظة بأشكال متفرقة).
 */
function norm(s) {
  return String(s)
    .normalize('NFD')
    .replace(/[ً-ٰٟ]/gu, '')
    .replace(/[أإآٱ]/gu, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ـ/g, '')
    // «اللنادي» => «النادي» — تكرار أداة التعريف في أسماء الملفات.
    .replace(/لل(?=[نبتثجحخدسشصضطظعفقكلمنويأإ])/gu, 'ال')
    .replace(/[-‏‪-‮]/gu, '')
    .toLowerCase();
}

/**
 * يختار المحور المناسب حسب الكلمات المفتاحية — بالترجيح (الأطول تطابقاً
 * يفوز) فتصنف «البرنامج السنوي للنادي البيئي» في الأنشطة لا في البيداغوجيا.
 */
function pickCategory(title) {
  const hay = norm(title);
  const scores = new Map();
  for (const c of CATEGORIES) {
    for (const k of c.keywords) {
      const key = norm(k);
      if (hay.indexOf(key) >= 0) {
        scores.set(c.id, (scores.get(c.id) || 0) + key.length);
      }
    }
  }
  let best = null;
  let bestScore = 0;
  for (const [id, score] of scores) {
    if (score > bestScore) {
      best = id;
      bestScore = score;
    }
  }
  if (!best) return FALLBACK;
  return CATEGORIES.find((c) => c.id === best) || FALLBACK;
}

/**
 * ملفات «<الاسم> -الخطاطات (الوثيقة)» — تُصنَّف بالاسم ما قبل الشرطة
 * (اسم العالِم) لا بعبارة «الوثيقة» المشتركة.
 */
const THEORISTS = [
  'أوزوبل', 'إريكسون', 'بافلوف', 'باندورا', 'برونر', 'ثورندايك', 'جاثري',
  'جاردنر', 'بيياجيه', 'ديوي', 'واتسون', 'سكينر', 'فرتهايمر', 'كوهلر',
  'كوفكا', 'فيغوتسكي', 'ماسلو', 'نورمان',
];

function pickCategoryFor(title) {
  if (/الخطاطات\s*\(الوثيقة\)/u.test(title)) {
    const head = norm(title.split('–')[0].split('-الخطاطات')[0].trim());
    if (THEORISTS.some((t) => head.indexOf(norm(t)) >= 0)) {
      return CATEGORIES.find((c) => c.id === 'theories');
    }
  }
  return pickCategory(title);
}

const files = fs
  .readdirSync(SRC, { withFileTypes: true })
  .filter((d) => d.isFile() && /\.(jpg|jpeg|png|jfif|webp)$/i.test(d.name))
  .map((d) => d.name)
  .sort((a, b) => a.localeCompare(b, 'ar'));

if (!fs.existsSync(DST)) fs.mkdirSync(DST, { recursive: true });

// تنظيف النسخ القديمة
fs.readdirSync(DST)
  .filter((f) => /\.(jpg|jpeg|png|jfif|webp)$/i.test(f))
  .forEach((f) => fs.unlinkSync(path.join(DST, f)));

const items = [];
files.forEach((name, i) => {
  const ext = (name.match(/\.([a-zA-Z0-9]+)$/u) || [, 'jpg'])[1].toLowerCase();
  const safeExt = ext === 'jpeg' ? 'jpg' : ext;
  const fileName = 'mm_' + String(i + 1).padStart(3, '0') + '.' + safeExt;
  fs.copyFileSync(path.join(SRC, name), path.join(DST, fileName));
  const title = cleanTitle(name);
  const override = TITLE_OVERRIDES[name];
  const cat = override
    ? CATEGORIES.concat([FALLBACK]).find((c) => c.id === override.category) ||
      FALLBACK
    : pickCategoryFor(title);
  items.push({
    id: 'mm_' + String(i + 1).padStart(3, '0'),
    file: 'assets/mindmaps/' + fileName,
    title: override ? override.title : title,
    source: name,
    category: cat.id,
  });
});

const manifest = {
  version: 1,
  updated: new Date().toISOString().slice(0, 10),
  categories: CATEGORIES.concat([FALLBACK]).map((c) => ({
    id: c.id,
    title: c.title,
    icon: c.icon,
  })),
  items: items,
};
fs.writeFileSync(OUT, JSON.stringify(manifest, null, 2), 'utf8');

// ===== ضغط الصور قبل النشر (تصغير + إعادة ترميز JPEG) =====
// يحوّل كل الصور إلى .jpg، لذا يُصحَّح الفهرس على الامتدادات الجديدة.
const { spawnSync } = require('child_process');
const optimizer = path.join(__dirname, 'optimize_mindmaps.py');
const opt = spawnSync('python', [optimizer], { encoding: 'utf8', windowsHide: true });
if (opt.status === 0) {
  const summary = (opt.stdout || '').trim().split(/\r?\n/).pop();
  console.log('optimized: ' + summary);
} else {
  console.warn('optimize failed: ' + (opt.stderr || '').trim().slice(-200));
}

// تصحيح أسماء الملفات بعد الضغط (امتداد .jfif/.png => .jpg)
const onDisk = fs
  .readdirSync(DST)
  .filter((f) => /\.(jpg|jpeg|png|jfif|webp)$/i.test(f));
const diskSet = new Set(onDisk);
let fixed = 0;
for (const it of items) {
  const base = path.basename(it.file);
  if (diskSet.has(base)) continue;
  const stem = base.replace(/\.(jfif|jpeg|png|webp|jpg)$/i, '');
  const alt = onDisk.find(
    (f) => f.replace(/\.(jfif|jpeg|png|webp|jpg)$/i, '') === stem
  );
  if (alt) {
    it.file = 'assets/mindmaps/' + alt;
    fixed++;
  }
}
if (fixed) {
  fs.writeFileSync(OUT, JSON.stringify(manifest, null, 2), 'utf8');
  console.log('manifest paths fixed=' + fixed);
}

const byCat = {};
items.forEach((it) => {
  byCat[it.category] = (byCat[it.category] || 0) + 1;
});
console.log('copied=' + items.length);
console.log(
  'by category: ' +
    Object.entries(byCat)
      .map(([k, v]) => k + '=' + v)
      .join(' | ')
);
const others = items.filter((it) => it.category === 'misc');
if (others.length) {
  console.log('--- others ---');
  others.forEach((o) => console.log('  ' + o.title));
}
