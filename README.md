# AuraVision 3D RF

نواة تطبيق Flutter باسم **AuraVision 3D RF** لدمج بيانات RF/CSI مع تتبع الفضاء ثلاثي الأبعاد وواجهة HUD مستقبلية.

> **حدود تقنية مهمة:** الهاتف وحده لا يتحول تلقائياً إلى رادار/ماسح خلال الجدران لمجرد وجود Wi‑Fi. التطبيق هنا يوفّر طبقة CSI قابلة للعمل مع بيانات تأتي من مستقبل/مجس خارجي مثل ESP32 الذي يدعم CSI، إضافة إلى وضع Demo اصطناعي. ARCore/ARKit مسؤولان عن تتبع الهاتف والعالم المرئي، وليس عن استخراج CSI الخام.

## ما الذي يعمل في هذا المستودع؟

- Flutter/Riverpod HUD عربي.
- Dart FFI حديث عبر `@Native` وbuild hooks.
- محرك C++ لمعالجة CSI: amplitude/phase، طاقة التغير، تقدير Doppler، تنعيم هيكل 17 نقطة وتصنيف أولي للمواد.
- مصدر RF اصطناعي حتمي لاختبار الواجهة دون عتاد.
- طبقة AR مبنية على `ar_flutter_plugin_plus` لدعم ARCore/ARKit.
- `CustomPainter` لكونتور RF وتراكب skeleton.
- اختبارات C++ وخط أساس لاختبارات Dart.

## التشغيل

هذا المستودع لا يحتوي على الملفات التي ينشئها `flutter create` تلقائياً حتى لا نكرر ملفات SDK المتغيرة. استخدم:

```bash
flutter create --platforms=android,ios .
```

ثم اجعل الملفات الموجودة هنا هي المصدر الأساسي للـ`lib/` و`packages/` و`assets/`، أو شغّل:

```bash
bash tool/bootstrap.sh
```

بعدها:

```bash
flutter pub get
flutter run
```

### ملاحظات المنصة

- Android: ARCore يتطلب جهازاً مدعوماً. راجع قائمة الأجهزة الرسمية.
- iOS: يلزم جهاز متوافق مع ARKit وإذن الكاميرا.
- ضع ملف النموذج `pose_17.tflite` في `assets/models/` عند الانتقال من Demo إلى نموذج pose فعلي. الكود الحالي يملك واجهة Adapter ولا يدّعي امتلاك أوزان النموذج.

## مصدر CSI الحقيقي

الموصل المطلوب هو Adapter يخرج مصفوفات CSI الخام: real/imag لكل subcarrier مع timestamp وsample rate وcarrier frequency. مثال عملي مناسب هو ESP-CSI، الذي يوفّر CSI عبر واجهات Wi‑Fi الخاصة بـESP-IDF.

يمكن ربط ESP32 عبر BLE/UDP/USB إلى التطبيق، أو استخدام حاسوب/مستقبل Wi‑Fi خارجي ليقدّم frames للتطبيق.

## معادلة Doppler

يطبق المحرك تقريباً:

`Δf = (2 v / λ) cos(θ)`

حيث `λ = c / f_c`. هذه صيغة تقريب monostatic؛ في إعداد Wi‑Fi bistatic الحقيقي يعتمد التحول على هندسة مسار المرسل/المستقبل، لذلك نتيجة المحرك يجب أن تعامل كتقدير وليس قياساً رادارياً مطلقاً.

## الألوان

- أخضر: فراغ/تجاويف محتملة في نموذج التصنيف.
- رمادي: كتلة صلبة/خرسانة محتملة.
- أحمر: استجابة معدن محتملة.
- أصفر: حركة ديناميكية.

هذه الألوان **تصنيف احتمالي للإشارة** وليست دليلاً هندسياً على وجود تجويف أو شخص.

## الخصوصية

لا يوجد في النواة أي تعرّف على هوية الأشخاص أو مطابقة وجوه. البيانات الافتراضية محلية، والـDemo يولّد جسماً اصطناعياً فقط.

## إصدارات التبعية التي بُني عليها القالب

الهيكل يستهدف Flutter 3.38+ وDart 3.7+ لاستخدام بنية FFI الحديثة. استخدمت Riverpod 3.4.x و`ar_flutter_plugin_plus` 1.1.x و`ffi` 2.2.x و`tflite_flutter` 0.12.x كما كانت إصداراتها المستقرة/المعلنة أثناء إعداد هذا القالب في سبتمبر 2026.

## ESP32-C6/C5 live CSI bridge

تمت إضافة `firmware/esp32_csi_bridge` وموصلات Flutter التالية:

- `lib/features/scanner/data/aura_rf_protocol.dart`
- `lib/features/scanner/data/udp_rf_source.dart`
- `lib/features/scanner/data/ble_rf_source.dart`

المصدر الافتراضي في `ScannerController` أصبح UDP. وللتبديل إلى BLE:

```dart
await ref.read(scannerControllerProvider.notifier).useBle();
```

ولتحديد UDP:

```dart
ref.read(scannerControllerProvider.notifier).useUdp();
```

التفاصيل الكاملة في `docs/ESP32_CSI_INTEGRATION.md` و`firmware/esp32_csi_bridge/README.md`.

## SAM M50 PRO Router Source

The project includes `SamM50ProSource`, a read-only local telemetry adapter for the SAM M50 PRO management interface at `http://192.168.8.1`.

It probes the management page and common read-only status endpoints, parses JSON or simple HTML values, and maps available values such as network type, RSSI/RSRP/RSRQ/SINR, battery, TX/RX rate, connected clients, SSID, channel and bandwidth into `RouterTelemetry`.

Flutter usage:

```dart
ref.read(scannerControllerProvider.notifier).useSamM50Pro();
```

If the firmware requires authentication, pass credentials or an existing cookie header:

```dart
ref.read(scannerControllerProvider.notifier).useSamM50Pro(
  username: 'admin',
  password: passwordFromSecureStorage,
);
```

The adapter performs GET requests only. It does not change Wi-Fi, APN, band, password, reboot, or modem settings.

Important: router telemetry is not CSI. AuraVision displays it as network telemetry and does not feed it into the CSI/Doppler engine as if it were raw channel measurements.
