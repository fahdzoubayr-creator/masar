/* ============================================================
   جواهر الكفاءة — تحميل بنك الأسئلة وبناء المستويات
   ============================================================ */

import { CONFIG, CHAPTERS } from "./config.js";

/* رقعة عشوائية مزروعة لضمان ثبات المستويات بين الجلسات */
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seededShuffle(arr, seed) {
  const rnd = mulberry32(seed);
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export class Bank {
  constructor() {
    this.bySubject = new Map();
    this.chapters = [];
    this.ready = false;
    this.totalQuestions = 0;
  }

  async load() {
    const paths = [CONFIG.bankPath, CONFIG.bankFallbackPath].filter(Boolean);
    let res = null;
    let lastErr = null;
    for (const p of paths) {
      try {
        const r = await fetch(p, { cache: "no-store" });
        if (r.ok) { res = r; break; }
        lastErr = new Error("تعذّر تحميل بنك الأسئلة (" + r.status + ")");
      } catch (e) {
        lastErr = e;
      }
    }
    if (!res) throw lastErr || new Error("تعذّر تحميل بنك الأسئلة");
    const data = await res.json();
    const group = data[CONFIG.bankGroup] || data[Object.keys(data)[0]] || [];
    this.raw = group;

    this.bySubject.clear();
    let idx = 0;
    for (const q of group) {
      if (!q || !q.subject || !Array.isArray(q.options)) continue;
      if (!this.bySubject.has(q.subject)) this.bySubject.set(q.subject, []);
      this.bySubject
        .get(q.subject)
        .push(Object.assign({ _i: idx++ }, q));
    }
    this.totalQuestions = idx;

    this._buildChapters();
    this.ready = true;
    return this;
  }

  _buildChapters() {
    const Q = CONFIG.questionsPerLevel; // عدد الأسئلة لكل مستوى
    const L = CONFIG.levelsPerChapter; // عدد المستويات لكل مرحلة (ثابت)
    this.chapters = CHAPTERS.map((c, ci) => {
      const pool = this.bySubject.get(c.subject) || [];
      const shuffled = seededShuffle(pool, 1000 + ci * 97);
      const levels = [];
      if (shuffled.length > 0) {
        // بناء L مستوى ثابتًا، كل مستوى Q سؤالًا.
        // عند قلّة أسئلة المحور تُعاد دورة الأسئلة (wraparound) حتى نمدّه بأسئلة كافية.
        for (let li = 0; li < L; li++) {
          const questions = [];
          for (let k = 0; k < Q; k++) {
            questions.push(shuffled[(li * Q + k) % shuffled.length]);
          }
          levels.push({
            id: `c${ci}_l${li + 1}`,
            index: li + 1,
            chapterIndex: ci,
            questions,
          });
        }
      }
      return {
        index: ci,
        subject: c.subject,
        title: c.title,
        icon: c.icon,
        theme: c.theme,
        questions: shuffled,
        count: shuffled.length,
        levels,
      };
    });
    // إخفاء الفصول التي لا تحتوي أسئلة
    this.chapters = this.chapters.filter((c) => c.count > 0);
    this.chapters.forEach((c, i) => {
      c.index = i;
      // ترقيم متصل عبر المراحل: المحور 1 => 1..30، المحور 2 => 31..60، ...
      c.levels.forEach((lv, j) => { lv.globalIndex = i * L + j + 1; });
    });
  }

  level(chapterIndex, levelIndex) {
    const ch = this.chapters[chapterIndex];
    if (!ch) return null;
    return ch.levels[levelIndex] || null;
  }

  levelById(id) {
    for (const ch of this.chapters) {
      const lv = ch.levels.find((l) => l.id === id);
      if (lv) return { chapter: ch, level: lv };
    }
    return null;
  }

  /* كل معرّفات مستويات فصل معيّن */
  levelIds(chapterIndex) {
    const ch = this.chapters[chapterIndex];
    return ch ? ch.levels.map((l) => l.id) : [];
  }

  allLevelIds() {
    return this.chapters.flatMap((c) => c.levels.map((l) => l.id));
  }

  allQuestions() {
    return this.chapters.flatMap((c) => c.questions);
  }
}

/* ---------- منطق الفتح ---------- */
export function isLevelUnlocked(bank, store, chapterIndex, levelIndex) {
  const ch = bank.chapters[chapterIndex];
  if (!ch) return false;
  if (levelIndex === 0) return true;
  const prev = ch.levels[levelIndex - 1];
  return store.isCompleted(prev.id);
}

export function isChapterUnlocked(bank, store, chapterIndex) {
  if (chapterIndex === 0) return true;
  const prevCh = bank.chapters[chapterIndex - 1];
  if (!prevCh) return true;
  const ids = prevCh.levels.map((l) => l.id);
  return store.completedCount(ids) >= Math.min(CONFIG.chapterUnlockLevels, ids.length);
}

/* أول مستوى غير مكتمل (المستوى الحالي) */
export function currentLevelRef(bank, store) {
  for (const ch of bank.chapters) {
    for (const lv of ch.levels) {
      if (!store.isCompleted(lv.id)) {
        return { chapter: ch, level: lv };
      }
    }
  }
  const lastCh = bank.chapters[bank.chapters.length - 1];
  const lastLv = lastCh.levels[lastCh.levels.length - 1];
  return { chapter: lastCh, level: lastLv };
}
