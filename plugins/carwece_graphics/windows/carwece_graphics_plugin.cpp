#include "carwece_graphics_plugin.h"

#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <flutter_windows.h>

#include <cstdio>
#include <stdexcept>
#include <utility>

namespace carwece_graphics {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableMap& Args(const flutter::MethodCall<EncodableValue>& call) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  if (args == nullptr) throw std::runtime_error("argumentos inválidos");
  return *args;
}

const EncodableValue& Field(const EncodableMap& args, const char* name) {
  auto it = args.find(EncodableValue(name));
  if (it == args.end()) throw std::runtime_error("campo ausente");
  return it->second;
}

int64_t GetInt(const EncodableValue& value) {
  if (const auto* v = std::get_if<int32_t>(&value)) return *v;
  if (const auto* v = std::get_if<int64_t>(&value)) return *v;
  throw std::runtime_error("inteiro inválido");
}

bool GetBool(const EncodableValue& value) {
  if (const auto* v = std::get_if<bool>(&value)) return *v;
  return false;
}

std::string GetString(const EncodableValue& value) {
  if (const auto* v = std::get_if<std::string>(&value)) return *v;
  return "";
}

const std::vector<float>& GetFloats(const EncodableValue& value) {
  if (const auto* v = std::get_if<std::vector<float>>(&value)) return *v;
  throw std::runtime_error("lista de floats inválida");
}

}  // namespace

// One pixel buffer per texture: the Flutter callback fills it from the
// bound renderer. (A single shared static buffer let surfaces overwrite
// each other's dimensions and pixel pointer.)
struct CarWeceGraphicsPlugin::TextureBinding {
  Renderer* renderer = nullptr;
  FlutterDesktopPixelBuffer buffer{};
};

// static
void CarWeceGraphicsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "com.hirumisu.carwece/graphics",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<CarWeceGraphicsPlugin>(registrar);
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

CarWeceGraphicsPlugin::CarWeceGraphicsPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

CarWeceGraphicsPlugin::~CarWeceGraphicsPlugin() {
  for (auto& [id, renderer] : renderers_) renderer->StopThread();
  for (auto& [id, renderer] : renderers_) {
    registrar_->texture_registrar()->UnregisterTexture(id);
  }
}

void CarWeceGraphicsPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    if (call.method_name() == "create") {
      const EncodableMap& args = Args(call);
      const std::vector<float>& world = GetFloats(Field(args, "world"));
      const auto& objects_value = Field(args, "objects");
      const auto* objects_list = std::get_if<EncodableList>(&objects_value);
      if (objects_list == nullptr) throw std::runtime_error("objetos inválidos");
      std::vector<std::vector<float>> objects;
      objects.reserve(objects_list->size());
      for (const EncodableValue& entry : *objects_list) {
        objects.push_back(GetFloats(entry));
      }
      const std::vector<float>& initial = GetFloats(Field(args, "frame"));
      const int width = static_cast<int>(GetInt(Field(args, "width")));
      const int height = static_cast<int>(GetInt(Field(args, "height")));
      const bool showroom = GetBool(Field(args, "showroom"));
      const bool night = GetBool(Field(args, "night"));
      const std::string quality = GetString(Field(args, "quality"));

      auto renderer = std::make_unique<Renderer>();
      std::string error;
      if (!renderer->Init(width, height, world, objects, showroom, night,
                          quality.empty() ? "medium" : quality, &error)) {
        result->Error("graphics_unavailable", error);
        return;
      }
      Renderer* raw = renderer.get();
      auto binding = std::make_unique<TextureBinding>();
      binding->renderer = raw;
      TextureBinding* binding_raw = binding.get();
      auto texture = std::make_unique<flutter::TextureVariant>(
          flutter::PixelBufferTexture(
              [binding_raw](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
                Renderer* r = binding_raw->renderer;
                binding_raw->buffer.buffer = r->LatestPixels();
                binding_raw->buffer.width = static_cast<size_t>(r->width());
                binding_raw->buffer.height = static_cast<size_t>(r->height());
                return &binding_raw->buffer;
              }));
      const int64_t id =
          registrar_->texture_registrar()->RegisterTexture(texture.release());
      raw->on_frame_available = [this, id]() {
        registrar_->texture_registrar()->MarkTextureFrameAvailable(id);
      };
      renderers_[id] = std::move(renderer);
      bindings_[id] = std::move(binding);
      // The first frame also renders on the render thread; create only
      // waits for it (a one-time loading cost), so a shader or device
      // failure still reaches Dart as a create error.
      raw->StartThread();
      raw->PostFrame(initial);
      if (!raw->WaitFirstFrame(5000)) {
        const std::string* failure = raw->TakeAsyncError();
        const std::string message =
            failure != nullptr ? *failure : "Tempo esgotado no primeiro quadro 3D";
        raw->StopThread();
        registrar_->texture_registrar()->UnregisterTexture(id);
        bindings_.erase(id);
        renderers_.erase(id);
        result->Error("graphics_unavailable", message);
        return;
      }
      result->Success(EncodableValue(id));
      return;
    }
    if (call.method_name() == "frame") {
      const EncodableMap& args = Args(call);
      const int64_t id = GetInt(Field(args, "id"));
      auto it = renderers_.find(id);
      if (it == renderers_.end()) {
        result->Success(EncodableValue());
        return;
      }
      const std::vector<float>& data = GetFloats(Field(args, "data"));
      // Rendering happens on the renderer's own thread; this handler only
      // hands over the newest packet and returns at once, so the platform
      // thread stays free for input and UI. A fatal render error is
      // reported on the next call, which makes Dart fall back as before.
      it->second->PostFrame(data);
      if (const std::string* failure = it->second->TakeAsyncError()) {
        result->Success(EncodableValue(*failure));
      } else {
        result->Success(EncodableValue());
      }
      return;
    }
    if (call.method_name() == "fps") {
      const EncodableMap& args = Args(call);
      const int64_t id = GetInt(Field(args, "id"));
      auto it = renderers_.find(id);
      if (it == renderers_.end()) {
        result->Success(EncodableValue());
      } else {
        result->Success(EncodableValue(it->second->PresentedFps()));
      }
      return;
    }
    if (call.method_name() == "info") {
      const EncodableMap& args = Args(call);
      const int64_t id = GetInt(Field(args, "id"));
      auto it = renderers_.find(id);
      if (it == renderers_.end()) {
        result->Success(EncodableValue());
      } else {
        char render_ms[32];
        std::snprintf(render_ms, sizeof(render_ms), "%.1fms",
                      it->second->LastRenderMs());
        result->Success(EncodableValue(it->second->DeviceInfo() +
                                       " | render " + render_ms));
      }
      return;
    }
    if (call.method_name() == "dispose") {
      const EncodableMap& args = Args(call);
      const int64_t id = GetInt(Field(args, "id"));
      auto it = renderers_.find(id);
      if (it != renderers_.end()) {
        it->second->StopThread();
        registrar_->texture_registrar()->UnregisterTexture(id);
        bindings_.erase(id);
        renderers_.erase(it);
      }
      result->Success(EncodableValue());
      return;
    }
    result->NotImplemented();
  } catch (const std::exception& e) {
    result->Error("invalid_graphics", e.what());
  }
}

}  // namespace carwece_graphics
