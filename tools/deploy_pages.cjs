#!/usr/bin/env node
/**
 * نشر نسخة الويب على GitHub Pages.
 *
 * صفحة GitHub Pages هنا مبنية بفرع `main` يحتوي على ناتج بناء Flutter
 * (وليس على فرع master الذي يحمل الشيفرة المصدرية)، مع ملف
 * `.github/workflows/pages.yml` الذي ينشره تلقائياً.
 *
 * الاستعمال:
 *   node tools/deploy_pages.cjs [--skip-build] [--dry]
 */
const { execFileSync, execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const REPO = path.resolve(__dirname, "..");
const TMP = "E:/masar_static/pages_deploy";
const args = process.argv.slice(2);
const SKIP_BUILD = args.includes("--skip-build");
const DRY = args.includes("--dry");
const REMOTE = "https://github.com/fahdzoubayr-creator/masar.git";

const sh = (cmd, cwd, capture = false) => {
  const out = execSync(cmd, {
    cwd,
    stdio: capture ? "pipe" : "inherit",
    shell: "cmd.exe",
    encoding: "utf8",
  });
  return out || "";
};

if (!SKIP_BUILD) {
  console.log("== بناء الويب ==");
  sh('"E:\\flutter\\bin\\flutter.bat" build web --release', REPO);
}

console.log("== تجهيز مجلد النشر ==");
fs.rmSync(TMP, { recursive: true, force: true });
fs.mkdirSync(TMP, { recursive: true });
try {
  // robocopy يُعيد 0-7 عند النجاح (مع نسخ/حذف ملفات) — نتجاهل هذه الشيفرة.
  execFileSync("robocopy", [path.join(REPO, "build", "web"), TMP, "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/R:2", "/W:2"], { stdio: "ignore" });
} catch (e) {
  if (e.status === undefined || e.status > 7) throw e;
}

// ملف النشر: يُستخرج من الأرشيف (الفرع main القديم) إن وُجد
const wfDir = path.join(TMP, ".github", "workflows");
fs.mkdirSync(wfDir, { recursive: true });
let wf = null;
try {
  wf = execSync(`git show archive/main-deploy:.github/workflows/pages.yml`, { cwd: REPO, encoding: "utf8" });
} catch (_) {
  wf = fs.readFileSync(path.join(REPO, "web", "pages.yml"), "utf8");
}
fs.writeFileSync(path.join(wfDir, "pages.yml"), wf, "utf8");
console.log("   workflow: .github/workflows/pages.yml");

console.log("== commit على فرع main ==");
sh("git init -q", TMP);
sh("git checkout -q -b main", TMP);
sh("git config user.email \"masar-bot@users.noreply.github.com\"", TMP);
sh("git config user.name \"masar-deploy\"", TMP);
sh("git add -A", TMP);
sh('git commit -q -m "deploy: تحديث نسخة الويب (فرع main للصفحات)"', TMP);
const sha = sh("git rev-parse --short HEAD", TMP, true).trim();
console.log("   commit: " + sha);

if (DRY) {
  console.log("== dry-run: لم يتم الدفع ==");
  process.exit(0);
}
console.log("== push ==");
try {
  sh(`git remote remove origin`, TMP);
} catch (_) {}
sh(`git remote add origin ${REMOTE}`, TMP);
sh("git push --force origin main", TMP);
console.log("تم النشر: " + sha);
