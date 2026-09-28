#pragma once
#include <stddef.h>
#include <stdint.h>
void aura_ble_init(void);
void aura_ble_send(const uint8_t *frame, size_t len);
