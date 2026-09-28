# AuraVision ESP32-C6/C5 CSI Bridge

هذه الوحدة تستخرج CSI من ESP-IDF وترسل الإطار إلى تطبيق AuraVision عبر UDP وBLE.

## البروتوكول

الرأس ثابت 32 بايت Little Endian:

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | `0x41565246` = AVRF |
| 4 | 1 | version = 1 |
| 5 | 1 | transport: 1 UDP / 2 BLE |
| 6 | 2 | flags |
| 8 | 4 | sequence |
| 12 | 8 | timestamp_us |
| 20 | 2 | center_frequency_mhz |
| 22 | 1 | RSSI dBm |
| 23 | 1 | noise-floor dBm |
| 24 | 2 | CSI byte length |
| 26 | 2 | reserved |
| 28 | 4 | CRC32 للـCSI payload |

الـpayload: `Imag0,Real0,Imag1,Real1,...` وكل قيمة `signed int8`.

BLE يستخدم NUS-compatible UUIDs، لكن الإطار ليس نصاً؛ characteristic الخاصة بـTX ترسل chunks بالشكل:

`sequence16 | offset16 | total16 | frame bytes...`

## البناء

ثبت ESP-IDF 5.x ثم:

```bash
idf.py set-target esp32c6
idf.py menuconfig
idf.py build
idf.py -p PORT flash monitor
```

ولـC5:

```bash
idf.py set-target esp32c5
idf.py build
```

في `menuconfig` اضبط `AURA_UDP_HOST` على عنوان الهاتف داخل شبكة ESP32، والافتراضي `192.168.4.2`.

## ملاحظة RF مهمة

CSI لا يأتي من BLE؛ BLE هنا قناة نقل فقط. CSI نفسه يستخرجه Wi-Fi PHY. يجب أن تصل إطارات Wi-Fi مناسبة إلى مستقبل ESP32 حتى يظهر callback، وقد تحتاج sniffer/promiscuous أو مرسل/نقطة وصول ثابتة للحصول على معدل عينات مفيد.
