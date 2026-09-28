#include "aura_udp.h"
#include "esp_log.h"
#include "lwip/sockets.h"
#include "lwip/inet.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

#define TAG "AURA_UDP"
#ifndef CONFIG_AURA_UDP_HOST
#define CONFIG_AURA_UDP_HOST "192.168.4.2"
#endif
#ifndef CONFIG_AURA_UDP_PORT
#define CONFIG_AURA_UDP_PORT 8765
#endif
#define AURA_CONTROL_PORT 8766

static int s_tx = -1;
static int s_rx = -1;
static struct sockaddr_in s_dest;

static void control_rx_task(void *arg) {
    (void)arg;
    uint8_t buf[64];
    struct sockaddr_in from;
    socklen_t from_len = sizeof(from);
    while (1) {
        const int n = recvfrom(s_rx, buf, sizeof(buf), 0, (struct sockaddr*)&from, &from_len);
        if (n <= 0) { vTaskDelay(pdMS_TO_TICKS(20)); continue; }
        /* وصول keepalive من الهاتف يضمن وجود uplink Wi-Fi مستمر وبالتالي يتيح للـPHY استقبال CSI. */
    }
}

void aura_udp_init(void) {
    s_tx = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    s_rx = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (s_tx < 0 || s_rx < 0) { ESP_LOGE(TAG, "UDP socket failed"); return; }

    memset(&s_dest, 0, sizeof(s_dest));
    s_dest.sin_family = AF_INET;
    s_dest.sin_port = htons(CONFIG_AURA_UDP_PORT);
    inet_pton(AF_INET, CONFIG_AURA_UDP_HOST, &s_dest.sin_addr.s_addr);

    struct sockaddr_in local = {0};
    local.sin_family = AF_INET;
    local.sin_port = htons(AURA_CONTROL_PORT);
    local.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(s_rx, (struct sockaddr*)&local, sizeof(local)) < 0) {
        ESP_LOGE(TAG, "control UDP bind failed");
    } else {
        xTaskCreate(control_rx_task, "aura_udp_rx", 3072, NULL, 3, NULL);
    }
    ESP_LOGI(TAG, "UDP TX -> %s:%d, control RX :%d", CONFIG_AURA_UDP_HOST, CONFIG_AURA_UDP_PORT, AURA_CONTROL_PORT);
}

void aura_udp_send(const uint8_t *frame, size_t len) {
    if (s_tx < 0 || !frame || len == 0) return;
    if (sendto(s_tx, frame, len, 0, (struct sockaddr*)&s_dest, sizeof(s_dest)) < 0) {
        ESP_LOGW(TAG, "sendto failed");
    }
}
