#pragma once
#include <stddef.h>
#include <stdint.h>
void aura_udp_init(void);
void aura_udp_send(const uint8_t *frame, size_t len);
