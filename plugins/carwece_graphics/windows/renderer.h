#pragma once

#include <d3d11.h>
#include <wrl/client.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace carwece_graphics {

struct Bounds {
  float cx = 0, cy = 0, cz = 0, rx = 0, ry = 0, rz = 0;
};

struct Mesh {
  Microsoft::WRL::ComPtr<ID3D11Buffer> vertices;
  uint32_t vertex_count = 0;
  Bounds bounds;
  bool transparent = false;
  bool casts_shadow = false;
};

// Direct3D 11 port of the Android RushGLRenderer: same frame packets, same
// draw order (shadow pass, opaque world/instances, transparent instances
// far-to-near), same material/shadow semantics. Renders offscreen and hands
// the latest RGBA pixels to a Flutter PixelBufferTexture.
class Renderer {
 public:
  std::function<void()> on_frame_available;

  bool Init(int width, int height, const std::vector<float>& world,
            const std::vector<std::vector<float>>& objects, bool showroom,
            bool night, const std::string& quality, std::string* error);

  // Renders one frame packet (15 + count*17 floats). Returns nullptr on
  // success, or a pointer to a persistent error string (fatal only).
  const std::string* Render(const std::vector<float>& frame);

  double PresentedFps() const { return presented_fps_; }
  int width() const { return width_; }
  int height() const { return height_; }
  const uint8_t* LatestPixels();

 private:
  bool CreateDeviceResources(std::string* error);
  bool CreateShaders(std::string* error);
  bool CreateTargets(std::string* error);
  bool Upload(const float* data, size_t floats, Mesh* mesh, std::string* error);
  void SetFrameConstants(const float vp[16], const float light_vp[16],
                         const float* frame);
  void SetModelConstants(const float* model);
  void DrawMesh(const Mesh& mesh, const float* model);
  void Readback();

  int width_ = 0, height_ = 0;
  bool showroom_ = false, night_ = false;
  std::string quality_ = "medium";
  int shadow_size_ = 1024;
  float shadow_quality_ = 1.0f;

  std::vector<Mesh> world_;
  std::vector<Mesh> objects_;

  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
  Microsoft::WRL::ComPtr<ID3D11VertexShader> scene_vs_;
  Microsoft::WRL::ComPtr<ID3D11PixelShader> scene_ps_;
  Microsoft::WRL::ComPtr<ID3D11VertexShader> depth_vs_;
  Microsoft::WRL::ComPtr<ID3D11PixelShader> depth_ps_;
  Microsoft::WRL::ComPtr<ID3D11InputLayout> layout_;
  Microsoft::WRL::ComPtr<ID3D11Buffer> frame_cb_;
  Microsoft::WRL::ComPtr<ID3D11Buffer> model_cb_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> color_tex_;
  Microsoft::WRL::ComPtr<ID3D11RenderTargetView> color_rtv_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> depth_tex_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilView> depth_dsv_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> shadow_tex_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilView> shadow_dsv_;
  Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> shadow_srv_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> staging_;
  Microsoft::WRL::ComPtr<ID3D11RasterizerState> raster_main_;
  Microsoft::WRL::ComPtr<ID3D11RasterizerState> raster_shadow_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilState> depth_write_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilState> depth_no_write_;
  Microsoft::WRL::ComPtr<ID3D11BlendState> blend_alpha_;
  Microsoft::WRL::ComPtr<ID3D11SamplerState> shadow_sampler_;

  std::vector<uint8_t> pixels_[2];
  int latest_pixels_ = 0;
  std::string error_;
  double presented_fps_ = 0.0;
  int64_t fps_window_start_ = 0;
  int presented_ = 0;
};

}  // namespace carwece_graphics
