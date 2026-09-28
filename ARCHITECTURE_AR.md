# المعمارية

```text
ARCore / ARKit ──────┐
                     ├── Flutter HUD ── CustomPainter
CSI Adapter ──► C++ DSP ──► Dart FFI ──► Pose/Material pipeline
                     └── Telemetry

CSI Adapter يمكن أن يكون:
ESP-CSI / مستقبل Linux / NIC متوافق / تدفق UDP أو BLE
```

## دورة الإطار

1. وصول frame خام: real/imag + sample rate + carrier frequency.
2. تحويل amplitude/phase.
3. استخراج dynamic score وphase-rate.
4. تقدير Doppler تقريبي.
5. تمرير 17 نقطة إلى exponential smoothing.
6. تصنيف أولي: dynamic / void / concrete / metal / unknown.
7. الرسم في HUD وعلى طبقة AR المرئية.

## استبدال مصدر Demo

استبدل `SyntheticRfSource` بتطبيق `RfFrameSource` يقرأ:

- BLE packets من عقدة CSI.
- UDP datagrams من خدمة على الحاسوب.
- USB serial عبر مكوّن native مناسب للمنصة.

لا تغيّر `ScannerController` إذا حافظ الـadapter على نفس `RfFrame`.

## عقد نموذج الـ17 نقطة

`Tflite17PoseAdapter` يقبل نموذجاً يعيد 51 قيمة (`17×x,y,z`) أو 68 قيمة (`17×x,y,z,confidence`). هذا لا يفرض بنية شبكة بعينها؛ أي نموذج يجب أن يلتزم بعقد الخرج بعد تدريب/تصدير النموذج.
