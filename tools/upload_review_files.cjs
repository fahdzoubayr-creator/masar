#!/usr/bin/env node
/**
 * رفع ملفات المراجعة النهائية (PDF + TXT) إلى release جديد على GitHub.
 * الرفع على دفعات (لتفادي حدود سطر الأوامر) مع تقرير تقدّم.
 */
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const STAGE = process.argv[2] || "E:/masar_static/review_v3";
const TAG = process.argv[3] || "review-files-v3";
const REPO = path.resolve(__dirname, "..");
const BATCH = 12;

const files = fs
  .readdirSync(STAGE)
  .filter((f) => /^(.*__\d+\.(pdf|txt))$/.test(f))
  .map((f) => path.join(STAGE, f));

let done = 0;
let bytes = 0;
const t0 = Date.now();
for (let i = 0; i < files.length; i += BATCH) {
  const batch = files.slice(i, i + BATCH);
  for (const b of batch) bytes += fs.statSync(b).size;
  try {
    execFileSync("gh", ["release", "upload", TAG, ...batch, "--clobber"], {
      cwd: REPO,
      stdio: "ignore",
    });
  } catch (e) {
    console.log("FAILED batch at " + i + ": " + e.message);
    // إعادة المحاولة file by file
    for (const b of batch) {
      try {
        execFileSync("gh", ["release", "upload", TAG, b, "--clobber"], { cwd: REPO, stdio: "ignore" });
      } catch (e2) {
        console.log("  FAILED " + path.basename(b));
      }
    }
  }
  done += batch.length;
  const mb = (bytes / 1e6).toFixed(0);
  const rate = (bytes / 1e6 / ((Date.now() - t0) / 1000)).toFixed(2);
  console.log(done + "/" + files.length + "  " + mb + " MB  " + rate + " MB/s");
}
console.log("DONE " + done + " files");
