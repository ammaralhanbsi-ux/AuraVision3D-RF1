#pragma once
#include <stdint.h>
#include <stddef.h>

#define AURA_MAGIC 0x41565246u /* ASCII: AVRF */
#define AURA_VERSION 1u
#define AURA_TRANSPORT_UDP 1u
#define AURA_TRANSPORT_BLE 2u
#define AURA_MAX_CSI 512u

/*
 * جميع الحقول متعددة البايت Little Endian. رأس الإطار ثابت 32 بايت.
 * CSI payload هو بايتات signed int8 كما تأتي من ESP-IDF: Imaginary0,Real0,Imaginary1,Real1,...
 */
#pragma pack(push, 1)
typedef struct {
    uint32_t magic;
    uint8_t version;
    uint8_t transport;
    uint16_t flags;
    uint32_t sequence;
    uint64_t timestamp_us;
    uint16_t center_freq_mhz;
    int8_t rssi_dbm;
    int8_t noise_dbm;
    uint16_t csi_len;
    uint16_t reserved;
    uint32_t payload_crc32;
} aura_frame_header_t;
#pragma pack(pop)

_Static_assert(sizeof(aura_frame_header_t) == 32, "Aura frame header must be 32 bytes");

uint32_t aura_crc32(const uint8_t *data, size_t len);
size_t aura_build_frame(uint8_t *out, size_t capacity, uint8_t transport,
                        uint16_t flags, uint32_t sequence, uint64_t timestamp_us,
                        uint16_t center_freq_mhz, int8_t rssi_dbm, int8_t noise_dbm,
                        const int8_t *csi, uint16_t csi_len);
