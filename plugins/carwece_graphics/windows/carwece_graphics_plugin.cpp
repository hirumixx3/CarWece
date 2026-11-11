#include "carwece_graphics_plugin.h"

#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <flutter_windows.h>

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
      auto texture = std::make_unique<flutter::TextureVariant>(
          flutter::PixelBufferTexture(
              [raw](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
                static FlutterDesktopPixelBuffer pixel_buffer{};
                pixel_buffer.buffer = raw->LatestPixels();
                pixel_buffer.width = static_cast<size_t>(raw->width());
                pixel_buffer.height = static_cast<size_t>(raw->height());
                return &pixel_buffer;
              }));
      const int64_t id =
          registrar_->texture_registrar()->RegisterTexture(texture.release());
      raw->on_frame_available = [this, id]() {
        registrar_->texture_registrar()->MarkTextureFrameAvailable(id);
      };
      renderers_[id] = std::move(renderer);
      if (const std::string* failure = raw->Render(initial)) {
        renderers_.erase(id);
        registrar_->texture_registrar()->UnregisterTexture(id);
        result->Error("graphics_unavailable", *failure);
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
      if (const std::string* failure = it->second->Render(data)) {
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
    if (call.method_name() == "dispose") {
      const EncodableMap& args = Args(call);
      const int64_t id = GetInt(Field(args, "id"));
      auto it = renderers_.find(id);
      if (it != renderers_.end()) {
        registrar_->texture_registrar()->UnregisterTexture(id);
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
