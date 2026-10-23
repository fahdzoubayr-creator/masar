#!/usr/bin/env node
/**
 * توليد فهرس ملفات المراجعة (assets/review_files/manifest.json) من مجلد
 * «ملفات التطبيق نهائي» على سطح المكتب، مع تجهيز ملفات PDF/NULL للنشر.
 *
 * البنية على القرص تطابق بنية التطبيق تماماً:
 *   <مجلد رئيسي>/<NN-محور فرعي>/<NN - اسم الملف>.pdf
 * فالمحور الفرعي = اسم المجلد الفرعي بلا ترقيمه، وهو نفس اسم المحور
 * الموجود في lib/features/review/data/review_content.dart.
 *
 * المخرجات:
 *   1) assets/review_files/manifest.json   — فهرس الملفات كما يعرضه التطبيق
 *   2) <stage>/<slug>__<NN>.pdf            — ملفات PDF جاهزة للرفع على الـRelease
 *   3) <stage>/manifest-plan.json          — تقرير: ما يحتاج رفعاً وما هو موجود
 *
 * الاستعمال:
 *   node tools/prep_review_files.mjs [--src <المجلد>] [--stage <مجلد>]
 */
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const REPO = path.resolve(__dirname, "..");
const args = process.argv.slice(2);
const argOf = (k, d) => {
  const i = args.indexOf(k);
  return i >= 0 && args[i + 1] ? args[i + 1] : d;
};

const SRC = argOf("--src", "C:/Users/JAMAL/Desktop/ملفات التطبيق نهائي");
const STAGE = argOf("--stage", "E:/masar_static/review_v3");
const MANIFEST = path.join(REPO, "assets/review_files/manifest.json");
const OLD_MANIFEST = path.join(REPO, "assets/review_files/manifest.json.bak");

/** مجلد سطح المكتب -> مجلد التطبيق + المزالغ اللاتينية (أسم�� Release). */
const FOLDERS = [
  { dir: "01-علوم التربية", app: "علوم التربية", slug: "ouloum_tarbiya" },
  { dir: "02-ديداكتيك اللغة العربية", app: "ديداكتيك اللغة العربية", slug: "didactique_arabe" },
  { dir: "03-ديداكتيك اللغة الفرنسية", app: "ديداكتيك اللغة الفرنسية", slug: "didactique_francais" },
  { dir: "04-ديداكتيك الرياضيات", app: "ديداكتيك الرياضيات", slug: "didactique_maths" },
  { dir: "05-ديداكتيك النشاط العلمي", app: "ديداكتيك النشاط العلمي", slug: "didactique_science" },
  { dir: "06-التشريع المدرسي", app: "التشريع المدرسي", slug: "tachrii_madrasii" },
  { dir: "07-التنشيط التربوي", app: "التنشيط التربوي", slug: "tanshit_tarbawi" },
  { dir: "08-خطاطات ذهنية", app: "خطاطات ذهنية", slug: "khatatat_dhihniya" },
  { dir: "09-دورات تكوينية", app: "دورات تكوينية", slug: "dawrat_takwiniya" },
  { dir: "10- مراسلات ومذكرات", app: "مراسلات ومذكرات", slug: "murasilat_mudhakkirat" },
  { dir: "11- مشروع المؤسسة المندمج", app: "مشروع المؤسسة المندمج", slug: "mashroua_muassasa" },
  { dir: "12-مؤسسات الريادة", app: "مؤسسات الريادة", slug: "mouassasat_riyada" },
];

/** مجلدات تُستثنى من العرض (ليست جزءاً من التطبيق). */
const EXCLUDE_DIR = /^_/;

/** تنظيف اسم الملف: إزالة الترقيم المبدئي وامتداد pdf. */
function cleanName(fileName) {
  let n = fileName.replace(/\.[Pp][Dd][Ff]$/, "");
  n = n.replace(/^\s*\d+\s*[-–—_]\s*/, ""); // "01 - " أو "22-" أو "24-38" → "38 ..."
  n = n.replace(/^[-–—_]\s*/, "");
  n = n.replace(/\s*\.(pptx?|docx?)\s*(\d+)?$/i, (m, ext, pg) => (pg ? ` ${pg}` : ""));
  n = n.replace(/\s+/g, " ").trim();
  return n || fileName.replace(/\.[Pp][Dd][Ff]$/, "");
}

/** رقم الملف كما وضعه الأستاذ في بدايته (لترتيب العرض). */
function fileNumber(fileName) {
  const m = /^\s*(\d+)/.exec(fileName);
  return m ? Number(m[1]) : 9999;
}

function walk(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

if (!fs.existsSync(SRC)) {
  console.error("مجلد المصدر غير موجود: " + SRC);
  process.exit(1);
}
fs.mkdirSync(STAGE, { recursive: true });

const manifest = {};
const plan = { stage: STAGE, files: [], byFolder: {} };
let seq = 0;

for (const f of FOLDERS) {
  const root = path.join(SRC, f.dir);
  if (!fs.existsSync(root)) {
    console.error("!! مجلد مفقود: " + f.dir);
    continue;
  }
  // المحاور الفرعية مرتّبة حسب أسمائها الرقمية
  const subDirs = fs
    .readdirSync(root, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !EXCLUDE_DIR.test(e.name))
    .map((e) => e.name)
    .sort((a, b) => fileNumber(a) - fileNumber(b));

  const entries = [];
  for (const sub of subDirs) {
    const topic = cleanName(sub);
    const files = walk(path.join(root, sub))
      .filter((p) => p.toLowerCase().endsWith(".pdf"))
      .sort((a, b) => fileNumber(path.basename(a)) - fileNumber(path.basename(b)));
    for (const file of files) {
      seq++;
      const nn = String(entries.length + 1).padStart(2, "0");
      const name = cleanName(path.basename(file));
      const assetPath = `assets/review_files/${f.app}/${nn}.pdf`;
      const releaseName = `${f.slug}__${nn}.pdf`;
      const dest = path.join(STAGE, releaseName);
      fs.copyFileSync(file, dest);
      entries.push({
        pdf: assetPath,
        name,
        topic,
        quiz: true,
        _src: file,
        _release: releaseName,
        _bytes: fs.statSync(file).size,
      });
    }
  }
  manifest[f.app] = entries.map((e) => ({
    pdf: e.pdf,
    name: e.name,
    topic: e.topic,
    quiz: e.quiz,
  }));
  plan.byFolder[f.app] = entries.length;
  plan.files.push(
    ...entries.map((e) => ({ release: e._release, src: e._src, bytes: e._bytes, pdf: e.pdf, topic: e.topic }))
  );
}

// «بنك الاسئلة» غير موجود على القرص (ملفات问答) — نُبقي مدخلاته كما هي
// من نسخة الفهرس السابقة (git HEAD) حتى لا يفقد التطبيق محوره.
if (!manifest["بنك الاسئلة"]) {
  const prev = readPreviousManifest();
  if (prev && prev["بنك الاسئلة"]) manifest["بنك الاسئلة"] = prev["بنك الاسئلة"];
}

/** نسخة الفهرس السابقة: من git (HEAD) ثم من ملف النسخة الاحتياطية. */
function readPreviousManifest() {
  try {
    const out = execFileSync("git", ["show", "HEAD:assets/review_files/manifest.json"], {
      cwd: REPO,
      encoding: "utf8",
      maxBuffer: 32 * 1024 * 1024,
    });
    return JSON.parse(out);
  } catch (_) {
    /* نجرّب النسخة الاحتياطية */
  }
  try {
    return JSON.parse(fs.readFileSync(OLD_MANIFEST, "utf8"));
  } catch (_) {
    return null;
  }
}

fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 1), "utf8");
fs.writeFileSync(path.join(STAGE, "manifest-plan.json"), JSON.stringify(plan, null, 1), "utf8");

const total = Object.values(plan.byFolder).reduce((a, b) => a + b, 0);
const bytes = plan.files.reduce((a, b) => a + b.bytes, 0);
console.log("الملفات: " + total + "  الحجم: " + (bytes / 1e9).toFixed(2) + " GB");
for (const [k, v] of Object.entries(plan.byFolder)) console.log("  " + k + " => " + v);
console.log("الفهرس: " + MANIFEST);
console.log("خطة الرفع: " + path.join(STAGE, "manifest-plan.json"));
