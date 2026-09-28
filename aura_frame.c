#include "aura_frame.h"
#include <string.h>

uint32_t aura_crc32(const uint8_t *data, size_t len) {
    uint32_t crc = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; ++i) {
        crc ^= data[i];
        for (int j = 0; j < 8; ++j) crc = (crc >> 1) ^ (0xEDB88320u & (-(int)(crc & 1u)));
    }
    return ~crc;
}

size_t aura_build_frame(uint8_t *out, size_t capacity, uint8_t transport,
                        uint16_t flags, uint32_t sequence, uint64_t timestamp_us,
                        uint16_t center_freq_mhz, int8_t rssi_dbm, int8_t noise_dbm,
                        const int8_t *csi, uint16_t csi_len) {
    if (!out || !csi || csi_len > AURA_MAX_CSI || capacity < sizeof(aura_frame_header_t) + csi_len) return 0;
    aura_frame_header_t h = {
        .magic = AURA_MAGIC, .version = AURA_VERSION, .transport = transport,
        .flags = flags, .sequence = sequence, .timestamp_us = timestamp_us,
        .center_freq_mhz = center_freq_mhz, .rssi_dbm = rssi_dbm,
        .noise_dbm = noise_dbm, .csi_len = csi_len, .reserved = 0,
        .payload_crc32 = aura_crc32((const uint8_t*)csi, csi_len)
    };
    memcpy(out, &h, sizeof(h));
    memcpy(out + sizeof(h), csi, csi_len);
    return sizeof(h) + csi_len;
}
