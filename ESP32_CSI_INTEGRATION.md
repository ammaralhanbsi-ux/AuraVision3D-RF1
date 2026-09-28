# تكامل ESP32 مع AuraVision

## المسار

```text
Wi-Fi PHY
   │ CSI callback
   ▼
ESP32-C6/C5 queue
   │
   ├── UDP ───────────────► هاتف Android/iOS :8765
   │
   └── BLE GATT notify ──► AuraVisionBleSource
                              │
                              ▼
                         AuraRfPacket
                              │
                              ▼
                         AuraRfEngine
                              │
                              ▼
                           HUD / AR
```

ESP-IDF يوفّر `esp_wifi_set_csi_rx_cb()` و`esp_wifi_set_csi_config()` و`esp_wifi_set_csi()` لاستخراج CSI، وينفّذ callback ضمن مهمة Wi-Fi؛ لذلك تنسخ الوحدة البيانات إلى queue ولا تنفذ DSP ثقيل داخل callback.

## UDP

1. اجعل ESP32 في شبكة يمكن للهاتف الوصول إليها.
2. اجعل `CONFIG_AURA_UDP_HOST` عنوان الهاتف.
3. افتح UDP port 8765 في التطبيق.
4. استخدم `UdpRfSource` كمصدر `RfFrameSource`.

## BLE

الهاتف يبحث عن `AuraVision-CSI`، ثم يشترك في characteristic:

`6e400003-b5a3-f393-e0a9-e50e24dcca9e`

الخدمة:

`6e400001-b5a3-f393-e0a9-e50e24dcca9e`

## القيود

- BLE أقل ملاءمة من UDP لتدفق CSI عالي المعدل بسبب MTU/الإشعارات.
- `sampleRateHz` في Flutter مضبوط افتراضياً على 60Hz كمعلمة تشغيلية، وليس قياساً زمنياً للـCSI PHY. يجب لاحقاً استخراج معدل الإطارات من timestamp/sequence أو إضافة حقل sampling interval إلى protocol v2.
- لا تعتبر `motionScore` أو `material` في النسخة الحالية كشفاً مؤكداً لشخص أو مادة؛ إنها features احتمالية تحتاج معايرة وdataset حقيقي.
