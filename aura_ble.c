#include "aura_ble.h"
#include "esp_log.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "os/os_mbuf.h"
#include "esp_nimble_hci.h"
#include <string.h>

#define TAG "AURA_BLE"
#define CHUNK_DATA 180
static uint16_t s_conn = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_val_handle;
static uint8_t s_addr_type;
static const ble_uuid128_t svc_uuid = BLE_UUID128_INIT(0x9e,0xca,0xdc,0x24,0x0e,0xe5,0xa9,0xe0,0x93,0xf3,0xa3,0xb5,0x01,0x00,0x40,0x6e);
static const ble_uuid128_t chr_uuid = BLE_UUID128_INIT(0x9e,0xca,0xdc,0x24,0x0e,0xe5,0xa9,0xe0,0x93,0xf3,0xa3,0xb5,0x03,0x00,0x40,0x6e);

static int gatt_access(uint16_t conn, uint16_t attr, struct ble_gatt_access_ctxt *ctxt, void *arg) {
    (void)conn; (void)attr; (void)arg;
    return 0;
}
static const struct ble_gatt_svc_def svcs[] = {
    { .type = BLE_GATT_SVC_TYPE_PRIMARY, .uuid = &svc_uuid.u, .characteristics = (struct ble_gatt_chr_def[]){
        { .uuid = &chr_uuid.u, .access_cb = gatt_access, .val_handle = &s_val_handle, .flags = BLE_GATT_CHR_F_NOTIFY },
        { 0 }
    }}, { 0 }
};
static int gap_event(struct ble_gap_event *e, void *arg) {
    (void)arg;
    if (e->type == BLE_GAP_EVENT_CONNECT) {
        if (e->connect.status == 0) s_conn = e->connect.conn_handle;
        else ble_gap_adv_start(s_addr_type, NULL, BLE_HS_FOREVER, NULL, gap_event, NULL);
    } else if (e->type == BLE_GAP_EVENT_DISCONNECT) {
        s_conn = BLE_HS_CONN_HANDLE_NONE;
        ble_gap_adv_start(s_addr_type, NULL, BLE_HS_FOREVER, NULL, gap_event, NULL);
    }
    return 0;
}
static void advertise(void) {
    struct ble_gap_adv_params p = {0};
    p.conn_mode = BLE_GAP_CONN_MODE_UND;
    p.disc_mode = BLE_GAP_DISC_MODE_GEN;
    ble_gap_adv_start(s_addr_type, NULL, BLE_HS_FOREVER, &p, gap_event, NULL);
}
static void on_sync(void) {
    ble_hs_id_infer_auto(0, &s_addr_type);
    ble_svc_gap_device_name_set("AuraVision-CSI");
    advertise();
}
static void host_task(void *param) { (void)param; nimble_port_run(); nimble_port_freertos_deinit(); }

void aura_ble_init(void) {
    ESP_ERROR_CHECK(esp_nimble_hci_and_controller_init());
    nimble_port_init();
    ble_svc_gap_init(); ble_svc_gatt_init();
    ble_gatts_count_cfg(svcs); ble_gatts_add_svcs(svcs);
    ble_hs_cfg.sync_cb = on_sync;
    nimble_port_freertos_init(host_task);
    ESP_LOGI(TAG, "BLE GATT notifications ready");
}

void aura_ble_send(const uint8_t *frame, size_t len) {
    if (s_conn == BLE_HS_CONN_HANDLE_NONE || !frame || len == 0) return;
    /* بروتوكول BLE: [seq16][offset16][total16][chunk...]، ويسمح للهاتف بإعادة تجميع الإطار. */
    if (len > 0xFFFFu) return;
    const uint8_t *p = frame; uint16_t seq = frame[8] | ((uint16_t)frame[9] << 8);
    uint16_t total = (uint16_t)len;
    for (uint16_t off = 0; off < total; ) {
        uint16_t n = total - off; if (n > CHUNK_DATA) n = CHUNK_DATA;
        uint8_t buf[6 + CHUNK_DATA];
        buf[0]=seq&255; buf[1]=seq>>8; buf[2]=off&255; buf[3]=off>>8; buf[4]=total&255; buf[5]=total>>8;
        memcpy(buf+6,p+off,n);
        struct os_mbuf *om = ble_hs_mbuf_from_flat(buf, n+6);
        if (om) ble_gatts_notify_custom(s_conn, s_val_handle, om);
        off += n;
    }
}
