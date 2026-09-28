# صلاحيات الهاتف

## Android

أضف إلى `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

اضبط `minSdk` إلى 21 أو أعلى عند استخدام `flutter_blue_plus`.

## iOS

في `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>يستخدم AuraVision Bluetooth للاتصال بمستشعر CSI الخارجي.</string>
```

UDP لا يحتاج إذن Bluetooth، لكنه يحتاج اتصالاً بالشبكة المحلية. في iOS أضف Local Network usage description عند الحاجة إلى الوصول إلى جهاز LAN.
