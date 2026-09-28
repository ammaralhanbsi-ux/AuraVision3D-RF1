#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "aura_frame.h"
#include "aura_udp.h"
#include "aura_ble.h"
#include <string.h>

#define TAG "AURA_CSI"
#define QUEUE_DEPTH 8
#define CSI_COPY_MAX AURA_MAX_CSI

typedef struct {
    uint16_t len; int8_t rssi; int8_t noise; uint16_t freq_mhz; uint64_t ts_us; int8_t csi[CSI_COPY_MAX];
} csi_item_t;
static QueueHandle_t q;
static uint32_t sequence;

static void csi_cb(void *ctx, wifi_csi_info_t *data) {
    QueueHandle_t queue = (QueueHandle_t)ctx;
    if (!data || !data->buf || data->len == 0) return;
    csi_item_t item = {0};
    item.len = data->len > CSI_COPY_MAX ? CSI_COPY_MAX : data->len;
    item.rssi = data->rx_ctrl.rssi;
    item.noise = data->rx_ctrl.noise_floor;
    item.freq_mhz = data->rx_ctrl.channel ? (uint16_t)(2407 + 5 * data->rx_ctrl.channel) : 0;
    item.ts_us = esp_timer_get_time();
    memcpy(item.csi, data->buf, item.len);
    xQueueSendFromISR(queue, &item, NULL);
}

static void sender_task(void *arg) {
    (void)arg; csi_item_t item; uint8_t frame[sizeof(aura_frame_header_t)+CSI_COPY_MAX];
    while (xQueueReceive(q, &item, portMAX_DELAY) == pdTRUE) {
        size_t n = aura_build_frame(frame, sizeof(frame), AURA_TRANSPORT_UDP, 0, sequence++, item.ts_us,
                                     item.freq_mhz, item.rssi, item.noise, item.csi, item.len);
        if (!n) continue;
        aura_udp_send(frame, n);
        aura_ble_send(frame, n);
    }
}

static void wifi_init(void) {
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_ap();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    wifi_config_t ap = {0};
    memcpy(ap.ap.ssid, "AuraVision-RF", 13);
    memcpy(ap.ap.password, "auravision123", 13);
    ap.ap.ssid_len = 13;
    ap.ap.channel = 6;
    ap.ap.max_connection = 4;
    ap.ap.authmode = WIFI_AUTH_WPA2_PSK;
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &ap));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(true));

    wifi_csi_config_t c = {
        .lltf_en = true,
        .htltf_en = true,
        .stbc_htltf2_en = true,
        .ltf_merge_en = true,
        .channel_filter_en = true,
        .manu_scale = false,
        .shift = false,
        .dump_ack_en = false
    };
    ESP_ERROR_CHECK(esp_wifi_set_csi_config(&c));
    ESP_ERROR_CHECK(esp_wifi_set_csi_rx_cb(csi_cb, q));
    ESP_ERROR_CHECK(esp_wifi_set_csi(true));
    ESP_LOGI(TAG, "CSI enabled; connect phone to AuraVision-RF / auravision123");
}

void app_main(void) {
    esp_err_t r = nvs_flash_init(); if (r == ESP_ERR_NVS_NO_FREE_PAGES || r == ESP_ERR_NVS_NEW_VERSION_FOUND) { nvs_flash_erase(); nvs_flash_init(); }
    q = xQueueCreate(QUEUE_DEPTH, sizeof(csi_item_t));
    configASSERT(q);
    wifi_init();
    aura_udp_init();
    aura_ble_init();
    xTaskCreate(sender_task, "aura_sender", 8192, NULL, 5, NULL);
    ESP_LOGI(TAG, "AuraVision CSI bridge online");
}
