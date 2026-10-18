/* ============================================================
   جواهر الكفاءة — الإعدادات والمحتوى
   جميع القيم قابلة للتعديل من هنا (نظام محتوى أولي)
   ============================================================ */

export const CONFIG = {
  title: "جواهر الكفاءة",
  subtitle: "رحلة التعلم الممتعة",
  tagline: "اجمع الجواهر واجتز المحاور لتصبح سفيراً للكفاءة المهنية.",

  bankPath: "/api/question-banks/game_challenges.json",
  bankFallbackPath: "/assets/assets/banks/game_challenges.json",
  bankGroup: "تحدي الكفاءة المهنية",

  // قواعد المستويات — موحّدة: كل مرحلة لها نفس العدد من المستويات والأسئلة
  levelsPerChapter: 30, // 30 مستوى لكل مرحلة
  questionsPerLevel: 10, // 10 أسئلة لكل مستوى
  passPercent: 60, // نسبة النجاح الدنيا
  starThresholds: { one: 60, two: 80, three: 100 }, // 10 أسئلة => 6/10، 8/10، 10/10

  // المكافآت
  coins: { perCorrect: 10, perStar: 25, levelClear: 30 },
  gems: { perfectLevel: 1 },

  // فتح الفصول التالية بعد إنجاز عدد من مستويات الفصل السابق
  chapterUnlockLevels: 3,

  // شرط فتح الموسم الجديد (New Game+): أقل عدد نجوم مطلوب في كل مستوى
  seasonUnlockStars: 2,

  // الخيار الخامس: يُضاف فقط عند تفعيله (بنك الأسئلة لا يحتوي خياراً خامساً أصلاً)
  forceFifthOption: false,
  fifthOptionLabel: "جميع الاختيارات خاطئة",

  optionKeys: ["أ", "ب", "ج", "د", "هـ"],

  // الأرواح (القلوب)
  lives: { max: 5, regenMinutes: 15 },

  // المؤقّت لكل سؤال
  timer: { enabled: true, secondsPerQuestion: 45, bonusCoinsPerRemainingSecond: 0 },

  // المعزّزات (تُشترى بالنقاط)
  boosters: {
    fifty: { cost: 30, label: "حذف خيارين", icon: "➗" },
    hint: { cost: 20, label: "تلميح", icon: "💡" },
    skip: { cost: 50, label: "تخطّي السؤال", icon: "⏭️" },
  },

  // تحدي اليوم
  daily: { enabled: true, questionsPerDay: 10, bonusCoins: 150, bonusGems: 2, timePerQuestion: 30 },

  isRtl: true,
};

/* أنواع الأوضاع (قابلة للتوسعة) */
export const MODES = {
  adventure: { label: "المغامرة", icon: "🗺️" },
  daily: { label: "تحدّي اليوم", icon: "📅" },
  review: { label: "المراجعة", icon: "🔁" },
};

/* ------------------------------------------------------------
   سمات المناطق (خلفيات/ألوان) — للعرض الجمالي فقط
   a/b = لون البانر، n1/n2 = لون العقدة، sky1/sky2 = سماء المنطقة،
   hill = لون التلال، deco = عناصر زخرفية تعليمية للمنطقة
   ------------------------------------------------------------ */
export const THEMES = {
  knowledge: { a: "#2b3fd6", b: "#17c9c0", n1: "#6f86ff", n2: "#1b2aa0", sky1: "#5b6cff", sky2: "#2b3fd6", hill: "#0e7d78", deco: ["📚", "🔭", "💠"] },
  education: { a: "#17c9c0", b: "#21c25e", n1: "#5fe7dd", n2: "#0e7d78", sky1: "#35e0d6", sky2: "#12a097", hill: "#0e8f42", deco: ["🧠", "📖", "🪄"] },
  psychology: { a: "#21c25e", b: "#8bd450", n1: "#79f0a0", n2: "#0e8f42", sky1: "#7bf0a0", sky2: "#17a05a", hill: "#0e8f42", deco: ["🌳", "🍃", "🦉"] },
  didactics: { a: "#6a3bd6", b: "#8a2be2", n1: "#b28bff", n2: "#5a2bb0", sky1: "#b28bff", sky2: "#6a3bd6", hill: "#5a2bb0", deco: ["✏️", "📐", "🧩"] },
  planning: { a: "#ff8a3c", b: "#ffcf3f", n1: "#ffb877", n2: "#c96a10", sky1: "#ffd27a", sky2: "#ff8a3c", hill: "#c96a10", deco: ["📋", "🗂️", "📍"] },
  assessment: { a: "#ff5fa2", b: "#ff4d5e", n1: "#ff9bc0", n2: "#c01f4a", sky1: "#ff9bc0", sky2: "#ff5fa2", hill: "#c01f4a", deco: ["📝", "✅", "📊"] },
  practice: { a: "#ffcf3f", b: "#ff8a3c", n1: "#ffe58a", n2: "#c8960a", sky1: "#ffe58a", sky2: "#ffb347", hill: "#c8960a", deco: ["🏫", "🧰", "🗝️"] },
  legislation: { a: "#3b3bd6", b: "#6a3bd6", n1: "#8f8cff", n2: "#2a1f8f", sky1: "#8f9cff", sky2: "#3b3bd6", hill: "#2a1f8f", deco: ["⚖️", "📜", "🏛️"] },
  summit: { a: "#8a2be2", b: "#4a2d9c", n1: "#c79bff", n2: "#5a1f9c", sky1: "#c79bff", sky2: "#8a2be2", hill: "#5a1f9c", deco: ["⛰️", "🏔️", "🗻"] },
  finalfort: { a: "#c8960a", b: "#8a2be2", n1: "#ffe9a8", n2: "#8a5a00", sky1: "#ffe9a8", sky2: "#c8960a", hill: "#8a5a00", deco: ["🏰", "👑", "🏆"] },
};

/* مستوى الصعوبة داخل المحور (للمعاينة والزخرفة) */
export function difficultyOf(levelIndex, total) {
  const r = total > 1 ? levelIndex / (total - 1) : 0;
  if (r < 0.34) return { key: "easy", label: "سهل", color: "#21c25e" };
  if (r < 0.67) return { key: "medium", label: "متوسط", color: "#ffcf3f" };
  return { key: "hard", label: "متقدم", color: "#ff5fa2" };
}

/* مكافأة تقريبية للمستوى (للعرض في المعاينة) */
export function levelReward(levelIndex) {
  return { coins: CONFIG.coins.levelClear + (levelIndex + 1) * 2, gems: 1 };
}

/* ------------------------------------------------------------
   الفصول = محاور بنك الأسئلة الفعلية (15 محوراً)
   subject = المفتاح المطابق لحقل subject في البنك
   ------------------------------------------------------------ */
export const CHAPTERS = [
  { subject: "علوم التربية", title: "جزيرة علوم التربية", icon: "🧠", theme: "education" },
  { subject: "البيداغوجيا والتشريع", title: "حصن التشريع والبيداغوجيا", icon: "⚖️", theme: "legislation" },
  { subject: "التشريع المدرسي", title: "قلعة التشريع المدرسي", icon: "📜", theme: "legislation" },
  { subject: "بيداغوجيا ومستجدات التدريس الفعال", title: "مملكة التدريس الفعال", icon: "🎯", theme: "didactics" },
  { subject: "تداخل علوم التربية ونظريات التعلم مع مستجدات الإصلاح", title: "غابة نظريات التعلم", icon: "🌳", theme: "psychology" },
  { subject: "مؤسسات الريادة", title: "مدينة مؤسسات الريادة", icon: "🏙️", theme: "practice" },
  { subject: 'حكامة وتنزيل مشروع "مدارس الريادة"', title: "وادي مدارس الريادة", icon: "🛤️", theme: "assessment" },
  { subject: "ديداكتيك اللغة العربية", title: "أزقة ديداكتيك العربية", icon: "📖", theme: "didactics" },
  { subject: "ديداكتيك الرياضيات", title: "برج ديداكتيك الرياضيات", icon: "🔢", theme: "didactics" },
  { subject: "النشاط العلمي", title: "مختبر النشاط العلمي", icon: "🔬", theme: "education" },
  { subject: "اللغة الفرنسية", title: "بوابة اللغة الفرنسية", icon: "🇫🇷", theme: "knowledge" },
  { subject: "مقاربة طارل TaRL وعلاج التعثرات", title: "مستشفى علاج التعثرات", icon: "🩺", theme: "assessment" },
  { subject: "مقارنة المستويين 1 و2", title: "قمة المستويين 1 و2", icon: "⛰️", theme: "summit" },
  { subject: "مقارنة المستويين 3 و4", title: "قمة المستويين 3 و4", icon: "🏔️", theme: "summit" },
  { subject: "مقارنة المستويين 5 و6", title: "قلعة الامتحان النهائي", icon: "🏰", theme: "finalfort" },
];

export function themeOf(key) {
  return THEMES[key] || THEMES.knowledge;
}
