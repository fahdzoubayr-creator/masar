# دليل نشر خادم LiveKit للإنتاج — تطبيق مسار Ehtiraf

الانتقال من الوضع التجريبي إلى الاعتماد النهائي: خادم LiveKit مستقل
(Self-Hosted) + Redis + TLS تلقائي، مع خدمة توكنات في الـ Backend
لا تحمل التطبيق فيها أي سرّ.

---

## 1) المتطلبات على الـ VPS

- Ubuntu 22.04+ (أو أي توزيعة تدعم Docker)
- Docker + Docker Compose v2:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # ثم أعد تسجيل الدخول
```

## 2) DNS

أنشئ سجل **A** يشير به النطاق الفرعي (مثال `livekit.ehtiraf-app.com`)
إلى عنوان IP العام للـ VPS، وانتظر انتشار السجل:

```bash
dig +short livekit.ehtiraf-app.com   # يجب أن يعيد IP الخادم
```

## 3) جدار الحماية

افتح المنافذ التالية فقط:

```bash
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # إصدار شهادة Let's Encrypt
sudo ufw allow 443/tcp    # wss/https (الإشارات)
sudo ufw allow 443/udp    # WebRTC عبر HTTPS منفذ
sudo ufw allow 7881/tcp   # WebRTC TCP احتياطي
sudo ufw allow 50000:60000/udp   # مدى وسائط UDP
sudo ufw enable
```

> لا تفتح 7880 ولا 6379 — يبقيهما Caddy والخادم محليين.

## 4) المفاتيح والإقلاع

```bash
cd deploy/livekit
cp .env.example .env
# ولّد قيمتين قويتين:
openssl rand -hex 16   # → LIVEKIT_API_KEY (أضف لها البادئة API إن أردت)
openssl rand -hex 32   # → LIVEKIT_API_SECRET
nano .env              # ضع القيم + النطاق
docker compose up -d
docker compose logs -f livekit   # تأكد: "starting LiveKit server" بلا أخطاء
```

Caddy سيُصدر شهادة TLS تلقائياً خلال دقيقة.

## 5) ربط خدمة التوكنات (Backend)

خدمة التوكنات مدمجة في `server.js` الخاص بالتطبيق. على الخادم الذي
يشغّله، أضف متغيرات البيئة التالية (نفس القيم التي وضعتها في `.env`
أعلاه):

```bash
export LIVEKIT_API_KEY="API..."
export LIVEKIT_API_SECRET="..."
export LIVEKIT_URL="wss://livekit.ehtiraf-app.com"
```

ثم أعد تشغيله. تحقق من الجاهزية:

```bash
curl https://YOUR-BACKEND-DOMAIN/api/livekit/health
# {"ok":true,"configured":true}
```

## 6) ربط تطبيق الهاتف

في `lib/features/audio_room/config/audio_room_config.dart`:

```dart
static const String tokenEndpoint =
    'https://YOUR-BACKEND-DOMAIN/api/livekit/token';
```

ثم أعد بناء التطبيق. هذا كل المطلوب — لا مفاتيح داخل العميل.

## 7) أول جلسة اختبار تمثيلية (Checklist)

1. افتح التطبيق من جهازين مختلفين وشبكتين مختلفتين (وليس نفس الراوتر).
2. الأول ينشئ قاعة خاصة ويشارك الرمز؛ الثاني ينضم.
3. تحقق بالترتيب:
   - شارة الوضع في أعلى القاعة = **«مباشر»** (وليس «تجريبي»).
   - صوت ذهاباً وإياباً واضح (المسير يتكلم افتراضياً).
   - كاميرا المسير تظهر عند الثاني، ودقة البث 480p.
   - رفع يد من الثاني → ظهوره لدى المسير → منح الكلمة → يتكلم وحده.
   - كتم المسير له صوتياً → يصمت فوراً حتى لو أعاد تشغيل مايكه
     (إنفاذ خادمي عبر RoomService).
   - طرد المشارك → تُغلق جلسته فوراً.
   - تجاوز الحد: ثالث يفرض فتح الكاميرا → يُكتم بثّه تلقائياً خلال ≤60
     ثانية (مراقبة حد الكاميرات = 2).
4. راقب الموارد: `docker stats` (LiveKit ~100MB RAM في الاستخدام الخفيف).

## 8) استكشاف الأخطاء

| العرض | السبب الأرجح | الحل |
|---|---|---|
| الشهادة لا تصدر | DNS لم ينتشر أو منفذ 80 مغلق | `docker compose logs caddy` |
| «تعذر الاتصال» لدى الجميع | LIVEKIT_URL خطأ أو 443/udp مغلقة | راجع جدار الحماية |
| صوت يعمل ولا صورة | مدى UDP غير مفتوح بالكامل | 50000:60000/udp |
| اتصال يفشل في شبكة شركة صارمة | حجب UDP+TCP | فعّل قسم TURN في livekit.yaml |

## 9) الصيانة

```bash
docker compose pull && docker compose up -d   # تحديث
docker compose logs --tail=200 livekit        # آخر السجلات
```

نسخ Redis محفوظة في volume باسم `redis-data` — نسخ احتياطي دوري
اختياري لأن حالة الغرف مؤقتة بطبيعتها.
