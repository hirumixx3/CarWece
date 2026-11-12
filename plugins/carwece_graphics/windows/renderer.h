#pragma once

#include <d3d11.h>
#include <wrl/client.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
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

  ~Renderer();

  bool Init(int width, int height, const std::vector<float>& world,
            const std::vector<std::vector<float>>& objects, bool showroom,
            bool night, const std::string& quality, std::string* error);

  // Renders one frame packet (15 + count*17 floats). Returns nullptr on
  // success, or a pointer to a persistent error string (fatal only).
  // Runs on the render thread (see below); external callers use PostFrame.
  const std::string* Render(const std::vector<float>& frame);

  // Dedicated render thread: the Android renderer draws on its own GL
  // thread, and so does this one. Rendering synchronously on the Windows
  // platform thread — the thread that also delivers keyboard and mouse
  // input — starved the whole game whenever a frame was expensive.
  // PostFrame only stores the newest packet and returns immediately;
  // stale packets are dropped, never queued.
  void StartThread();
  void StopThread();
  void PostFrame(const std::vector<float>& frame);
  // Waits for the first posted frame to finish rendering (create path).
  bool WaitFirstFrame(int timeout_ms);
  // Returns the last fatal render error reported by the render thread,
  // exactly once, or nullptr. The pointer stays valid until the next call.
  const std::string* TakeAsyncError();

  double PresentedFps() const { return presented_fps_.load(); }
  // "HARDWARE | <adapter> | FL 11.0" ou "WARP | ..." — vazio até Init.
  std::string DeviceInfo() const { return device_info_; }
  // Tempo do último Render (desenho + readback), em ms, na thread de desenho.
  double LastRenderMs() const { return last_render_ms_.load(); }
  int width() const { return width_; }
  int height() const { return height_; }
  const uint8_t* LatestPixels();

 private:
  void ThreadMain();
  bool CreateDeviceResources(std::string* error);
  bool CreateShaders(std::string* error);
  bool CreateTargets(std::string* error);
  // Color/depth/readback targets at the CURRENT width_/height_ (the base
  // size scaled by the render budget). Created into temporaries and only
  // swapped in on success, so a failed resize keeps the old targets.
  bool CreateSizeTargets(std::string* error);
  bool Upload(const float* data, size_t floats, Mesh* mesh, std::string* error);
  void SetFrameConstants(const float vp[16], const float light_vp[16],
                         const float* frame);
  void SetModelConstants(const float* model);
  void DrawMesh(const Mesh& mesh, const float* model);
  void Readback();
  // The Android RenderBudget, ported 1:1 (same scales and thresholds):
  // feeds each frame's cost and returns true when the level changed and
  // the targets must be recreated at the new scale.
  bool BudgetSample(double cost_ms, double cadence_ms);
  void BudgetReset() {
    budget_average_ = 16.0;
    budget_samples_ = 0;
    budget_slow_ = 0;
    budget_fast_ = 0;
  }
  bool ResizeTargets();

  int width_ = 0, height_ = 0;
  int base_width_ = 0, base_height_ = 0;
  D3D_FEATURE_LEVEL feature_level_ = D3D_FEATURE_LEVEL_11_0;
  bool automatic_ = false;
  int budget_level_ = 2;
  double budget_average_ = 16.0;
  int budget_samples_ = 0, budget_slow_ = 0, budget_fast_ = 0;
  int64_t last_render_start_ns_ = 0;
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
  // Ring of readback targets: the frame handler copies into one slot and
  // maps the slot written two frames earlier, so Map never waits for the
  // frame that was just rendered.
  Microsoft::WRL::ComPtr<ID3D11Texture2D> staging_[3];
  int staging_cursor_ = 0;
  int frames_rendered_ = 0;
  Microsoft::WRL::ComPtr<ID3D11RasterizerState> raster_main_;
  Microsoft::WRL::ComPtr<ID3D11RasterizerState> raster_shadow_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilState> depth_write_;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilState> depth_no_write_;
  Microsoft::WRL::ComPtr<ID3D11BlendState> blend_alpha_;
  Microsoft::WRL::ComPtr<ID3D11SamplerState> shadow_sampler_;

  std::vector<uint8_t> pixels_[2];
  std::atomic<int> latest_pixels_{0};
  std::string error_;
  std::string device_info_;
  std::atomic<double> last_render_ms_{0.0};
  std::atomic<double> presented_fps_{0.0};
  int64_t fps_window_start_ = 0;
  int presented_ = 0;

  std::thread thread_;
  std::mutex mutex_;
  std::condition_variable cv_;
  std::vector<float> pending_;
  bool has_pending_ = false;
  bool stop_ = false;
  bool first_done_ = false;
  std::string async_error_;
  std::string reported_error_;
};

}  // namespace carwece_graphics
