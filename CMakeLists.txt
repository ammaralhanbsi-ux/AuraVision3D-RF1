cmake_minimum_required(VERSION 3.16)
project(auravision_native_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(auravision_native_tests
  main.cpp
  ../packages/aura_rf_ffi/src/aura_rf_engine.cpp
)

target_include_directories(auravision_native_tests PRIVATE
  ../packages/aura_rf_ffi/src
idf_component_register(
  SRCS "main.c" "aura_frame.c" "aura_ble.c" "aura_udp.c"
  INCLUDE_DIRS "."
  REQUIRES esp_wifi esp_event nvs_flash esp_netif bt
)
