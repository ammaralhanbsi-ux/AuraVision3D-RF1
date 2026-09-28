# Platform snippets

هذه المقاطع تذهب إلى الملفات التي ينشئها `flutter create`.

## AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
```

## ios/Runner/Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>الكاميرا مطلوبة لعرض الواقع المعزز.</string>
```
