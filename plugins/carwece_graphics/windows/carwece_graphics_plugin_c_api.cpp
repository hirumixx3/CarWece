#include "include/carwece_graphics/car_wece_graphics_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "carwece_graphics_plugin.h"

void CarWeceGraphicsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  carwece_graphics::CarWeceGraphicsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
