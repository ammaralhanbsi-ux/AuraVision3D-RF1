# النشر على Android/iOS

## AndroidManifest.xml

أضف:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
```

واجعل `minSdk` متوافقاً مع إصدار AR plugin/ARCore الذي تستخدمه.

## iOS Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>يستخدم AuraVision الكاميرا لعرض طبقة الواقع المعزز فوق المشهد.</string>
```

## وضع الإنتاج

- ثبّت build mode Release.
- اختبر AR على كل طراز مستهدف قبل النشر.
- عاير مصدر CSI لكل موضع مرسل/مستقبل وسمك جدار.
- لا تعرض نتيجة material كحقيقة هندسية دون معايرة وقياس مرجعي.
