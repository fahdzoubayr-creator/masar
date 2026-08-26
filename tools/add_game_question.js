const fs = require('fs');
const readline = require('readline');

const BANK_PATH = 'D:/masar_app/masar_app/assets/banks/game_challenges.json';

function loadBank() {
  try {
    return JSON.parse(fs.readFileSync(BANK_PATH, 'utf8'));
  } catch {
    return { 'تحدي الكفاءة المهنية': [] };
  }
}

function saveBank(data) {
  fs.writeFileSync(BANK_PATH, JSON.stringify(data, null, 2), 'utf8');
}

function addQuestion(data, q) {
  const key = 'تحدي الكفاءة المهنية';
  if (!data[key]) data[key] = [];
  data[key].push({
    subject: key,
    text: q.text,
    options: q.options,
    correctIndex: q.correctIndex,
    explanation: q.explanation,
  });
  saveBank(data);
  return data[key].length;
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise((r) => rl.question(q, r));

async function main() {
  const bank = loadBank();
  const total = bank['تحدي الكفاءة المهنية']?.length || 0;
  console.log(`\n=== بنك أسئلة مسار التحدي ===`);
  console.log(`الأسئلة الحالية: ${total}\n`);

  let count = 0;
  while (true) {
    console.log(`--- سؤال جديد (${total + count + 1}) ---`);
    const text = (await ask('السؤال: ')).trim();
    if (!text || text === 'q' || text === 'quit') break;

    const options = [];
    for (let i = 0; i < 5; i++) {
      const label = String.fromCharCode(65 + i); // A B C D E
      const opt = (await ask(`  الخيار ${label}: `)).trim();
      if (opt) options.push(opt);
    }
    if (options.length < 2) {
      console.log('  => أقل من خيارين، تم الإلغاء.\n');
      continue;
    }

    const correctStr = (await ask('الخيار الصحيح (حرف: A-E): ')).trim().toUpperCase();
    const correctIdx = correctStr.charCodeAt(0) - 65;
    if (correctIdx < 0 || correctIdx >= options.length) {
      console.log('  => حرف غير صحيح، تم الإلغاء.\n');
      continue;
    }

    const explanation = (await ask('التوضيح (اختياري، اضغط Enter للتخطي): ')).trim();

    const newTotal = addQuestion(bank, {
      text,
      options,
      correctIndex: correctIdx,
      explanation: explanation || '',
    });
    count++;
    console.log(`  => تم الحفظ! (${newTotal} سؤالاً في البنك)\n`);
  }

  console.log(`\nانتهى. أُضيف ${count} سؤالاً. الإجمالي: ${total + count}`);
  rl.close();
}

main();
