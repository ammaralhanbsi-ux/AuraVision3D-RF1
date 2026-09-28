idf_component_register(
  SRCS "main.c" "aura_frame.c" "aura_ble.c" "aura_udp.c"
  INCLUDE_DIRS "."
  REQUIRES esp_wifi esp_event nvs_flash esp_netif bt
)
