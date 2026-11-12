#ifndef FLUTTER_PLUGIN_CARWECE_GRAPHICS_PLUGIN_H_
#define FLUTTER_PLUGIN_CARWECE_GRAPHICS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <map>
#include <memory>

#include "renderer.h"

namespace carwece_graphics {

class CarWeceGraphicsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit CarWeceGraphicsPlugin(flutter::PluginRegistrarWindows* registrar);

  ~CarWeceGraphicsPlugin() override;

  CarWeceGraphicsPlugin(const CarWeceGraphicsPlugin&) = delete;
  CarWeceGraphicsPlugin& operator=(const CarWeceGraphicsPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  struct TextureBinding;

  flutter::PluginRegistrarWindows* registrar_;
  std::map<int64_t, std::unique_ptr<Renderer>> renderers_;
  std::map<int64_t, std::unique_ptr<TextureBinding>> bindings_;
};

}  // namespace carwece_graphics

#endif  // FLUTTER_PLUGIN_CARWECE_GRAPHICS_PLUGIN_H_
