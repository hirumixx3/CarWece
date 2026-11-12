#include "renderer.h"

#include <d3dcompiler.h>
#include <dxgi.h>
#include <windows.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <limits>
#include <unordered_map>

#include "shaders_hlsl.h"

namespace carwece_graphics {
namespace {

using Microsoft::WRL::ComPtr;

// All renderers share one immediate context, which is not thread-safe:
// renders from different render threads are serialized through this lock.
std::mutex g_context_mutex;

constexpr int kMaxInstances = 128;
constexpr uint32_t kStride = 48;  // 12 floats per vertex, as on the wire.

// ---------------------------------------------------------------------------
// Column-major 4x4 helpers, mirroring android.opengl.Matrix exactly: the
// game's packets and the Kotlin renderer use that convention end to end.
// ---------------------------------------------------------------------------
void MatPerspective(float fov_y_deg, float aspect, float near_z, float far_z,
                    float out[16]) {
  std::memset(out, 0, sizeof(float) * 16);
  const float f = 1.0f / std::tan(fov_y_deg * 3.14159265f / 360.0f);
  out[0] = f / aspect;
  out[5] = f;
  out[10] = (far_z + near_z) / (near_z - far_z);
  out[11] = -1.0f;
  out[14] = 2.0f * far_z * near_z / (near_z - far_z);
}

void MatLookAt(const float eye[3], const float center[3], const float up[3],
               float out[16]) {
  float fx = center[0] - eye[0], fy = center[1] - eye[1], fz = center[2] - eye[2];
  const float fl = std::sqrt(fx * fx + fy * fy + fz * fz);
  fx /= fl; fy /= fl; fz /= fl;
  float sx = fy * up[2] - fz * up[1], sy = fz * up[0] - fx * up[2],
        sz = fx * up[1] - fy * up[0];
  const float sl = std::sqrt(sx * sx + sy * sy + sz * sz);
  sx /= sl; sy /= sl; sz /= sl;
  const float ux = sy * fz - sz * fy, uy = sz * fx - sx * fz, uz = sx * fy - sy * fx;
  out[0] = sx;  out[1] = ux;  out[2] = -fx; out[3] = 0;
  out[4] = sy;  out[5] = uy;  out[6] = -fy; out[7] = 0;
  out[8] = sz;  out[9] = uz;  out[10] = -fz; out[11] = 0;
  out[12] = -(sx * eye[0] + sy * eye[1] + sz * eye[2]);
  out[13] = -(ux * eye[0] + uy * eye[1] + uz * eye[2]);
  out[14] = fx * eye[0] + fy * eye[1] + fz * eye[2];
  out[15] = 1;
}

void MatOrtho(float l, float r, float b, float t, float n, float f,
              float out[16]) {
  std::memset(out, 0, sizeof(float) * 16);
  out[0] = 2.0f / (r - l);
  out[5] = 2.0f / (t - b);
  out[10] = 2.0f / (n - f);
  out[12] = (r + l) / (l - r);
  out[13] = (t + b) / (b - t);
  out[14] = (f + n) / (n - f);
  out[15] = 1;
}

// out = a * b (apply b first), column-major.
void MatMultiply(const float a[16], const float b[16], float out[16]) {
  float r[16];
  for (int col = 0; col < 4; col++) {
    for (int row = 0; row < 4; row++) {
      r[col * 4 + row] = a[row] * b[col * 4] + a[4 + row] * b[col * 4 + 1] +
                         a[8 + row] * b[col * 4 + 2] +
                         a[12 + row] * b[col * 4 + 3];
    }
  }
  std::memcpy(out, r, sizeof(r));
}

// Converts a GL clip matrix to Direct3D clip space: z' = 0.5*z + 0.5*w.
void MatRemapZ(const float m[16], float out[16]) {
  std::memcpy(out, m, sizeof(float) * 16);
  for (int col = 0; col < 4; col++) {
    out[col * 4 + 2] = 0.5f * m[col * 4 + 2] + 0.5f * m[col * 4 + 3];
  }
}

// Gribb-Hartmann planes from a column-major VP, ported from RenderGeometry.
struct Frustum {
  float planes[6][4];
  void Set(const float m[16]) {
    for (int axis = 0; axis < 3; axis++) {
      for (int side = 0; side < 2; side++) {
        const float sign = side == 0 ? 1.0f : -1.0f;
        float* p = planes[axis * 2 + side];
        for (int k = 0; k < 4; k++) p[k] = m[k * 4 + 3] + sign * m[k * 4 + axis];
      }
    }
  }
  bool Visible(const Bounds& b, const float* model = nullptr) const {
    float x = b.cx, y = b.cy, z = b.cz, rx = b.rx, ry = b.ry, rz = b.rz;
    if (model != nullptr) {
      x = model[0] * b.cx + model[4] * b.cy + model[8] * b.cz + model[12];
      y = model[1] * b.cx + model[5] * b.cy + model[9] * b.cz + model[13];
      z = model[2] * b.cx + model[6] * b.cy + model[10] * b.cz + model[14];
      rx = std::abs(model[0]) * b.rx + std::abs(model[4]) * b.ry +
           std::abs(model[8]) * b.rz;
      ry = std::abs(model[1]) * b.rx + std::abs(model[5]) * b.ry +
           std::abs(model[9]) * b.rz;
      rz = std::abs(model[2]) * b.rx + std::abs(model[6]) * b.ry +
           std::abs(model[10]) * b.rz;
    }
    for (const auto& p : planes) {
      if (p[0] * x + p[1] * y + p[2] * z + p[3] + std::abs(p[0]) * rx +
              std::abs(p[1]) * ry + std::abs(p[2]) * rz <
          0.0f) {
        return false;
      }
    }
    return true;
  }
};

Bounds BoundsOf(const float* data, size_t begin, size_t end) {
  const float inf = std::numeric_limits<float>::infinity();
  float ax = inf, ay = inf, az = inf;
  float bx = -inf, by = -inf, bz = -inf;
  for (size_t i = begin; i < end; i += 12) {
    ax = std::min(ax, data[i]); ay = std::min(ay, data[i + 1]); az = std::min(az, data[i + 2]);
    bx = std::max(bx, data[i]); by = std::max(by, data[i + 1]); bz = std::max(bz, data[i + 2]);
  }
  return Bounds{(ax + bx) * .5f, (ay + by) * .5f, (az + bz) * .5f,
                (bx - ax) * .5f + .01f, (by - ay) * .5f + .01f,
                (bz - az) * .5f + .01f};
}

bool IsTransparent(const float* data, size_t floats) {
  for (size_t i = 11; i < floats; i += 12) {
    const int m = static_cast<int>(data[i]);
    if (m == 11 || m == 12 || m == 17) return true;
  }
  return false;
}

bool CastsShadow(const float* data, size_t floats) {
  for (size_t i = 11; i < floats; i += 12) {
    const int m = static_cast<int>(data[i]);
    if (m != 11 && m != 12 && m != 17 && m != 18) return true;
  }
  return false;
}

// transpose(inverse(mat3(model))) written out as three float4 columns.
void NormalColumns(const float* m, float out[12]) {
  // Mathematical elements A(row, col) = m[col*4 + row].
  const float a = m[0], b = m[4], c = m[8];
  const float d = m[1], e = m[5], f = m[9];
  const float g = m[2], h = m[6], i = m[10];
  const float det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  const float s = det != 0.0f ? 1.0f / det : 0.0f;
  // N = cofactor(A) / det; column j of N is (N(0,j), N(1,j), N(2,j)).
  out[0] = (e * i - f * h) * s; out[1] = (f * g - d * i) * s; out[2] = (d * h - e * g) * s;
  out[3] = 0;
  out[4] = (c * h - b * i) * s; out[5] = (a * i - c * g) * s; out[6] = (b * g - a * h) * s;
  out[7] = 0;
  out[8] = (b * f - c * e) * s; out[9] = (c * d - a * f) * s; out[10] = (a * e - b * d) * s;
  out[11] = 0;
}

int64_t NowNs() {
  return std::chrono::duration_cast<std::chrono::nanoseconds>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

std::string NarrowWide(const wchar_t* value) {
  if (value == nullptr) return "desconhecido";
  const int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0,
                                       nullptr, nullptr);
  if (size <= 1) return "desconhecido";
  std::string out(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, -1, out.data(), size, nullptr,
                      nullptr);
  return out;
}

}  // namespace

bool Renderer::Init(int width, int height, const std::vector<float>& world,
                    const std::vector<std::vector<float>>& objects,
                    bool showroom, bool night, const std::string& quality,
                    std::string* error) {
  width_ = std::clamp(width, 320, 1920);
  height_ = std::clamp(height, 180, 1200);
  showroom_ = showroom;
  night_ = night;
  quality_ = quality;
  shadow_size_ = quality == "high" ? 2048 : quality == "low" ? 512
                 : quality == "auto" ? 768
                                     : 1024;
  shadow_quality_ = quality == "low" ? 0.0f : quality == "high" ? 2.0f : 1.0f;
  if (world.empty() || world.size() % 36 != 0) {
    *error = "Malha 3D inválida: cenário";
    return false;
  }
  for (const float v : world) {
    if (!std::isfinite(v)) {
      *error = "Malha 3D inválida: cenário";
      return false;
    }
  }
  if (!CreateDeviceResources(error)) return false;
  if (!CreateShaders(error)) return false;
  if (!CreateTargets(error)) return false;

  // World upload in spatial chunks of at most 4096 triangles, like
  // RenderGeometry.forEachChunk (cell 160 on x/z by triangle centroid).
  {
    std::unordered_map<int64_t, size_t> cell_index;
    std::vector<std::vector<int>> cells;
    const size_t triangles = world.size() / 36;
    for (size_t t = 0; t < triangles; t++) {
      const size_t i = t * 36;
      const int cx = static_cast<int>(std::floor(
          (world[i] + world[i + 12] + world[i + 24]) / 3.0f / 160.0f));
      const int cz = static_cast<int>(std::floor(
          (world[i + 2] + world[i + 14] + world[i + 26]) / 3.0f / 160.0f));
      const int64_t key = (static_cast<int64_t>(cx) << 32) ^
                          (static_cast<int64_t>(cz) & 0xffffffffLL);
      auto [it, inserted] = cell_index.try_emplace(key, cells.size());
      if (inserted) cells.emplace_back();
      cells[it->second].push_back(static_cast<int>(t));
    }
    std::vector<float> block;
    for (const auto& cell : cells) {
      for (size_t start = 0; start < cell.size(); start += 4096) {
        const size_t count = std::min<size_t>(4096, cell.size() - start);
        block.resize(count * 36);
        for (size_t j = 0; j < count; j++) {
          const float* src = world.data() + static_cast<size_t>(cell[start + j]) * 36;
          std::memcpy(block.data() + j * 36, src, sizeof(float) * 36);
        }
        Mesh mesh;
        if (!Upload(block.data(), block.size(), &mesh, error)) return false;
        world_.push_back(std::move(mesh));
      }
    }
  }
  for (const auto& data : objects) {
    if (data.empty() || data.size() % 36 != 0) {
      *error = "Malha 3D inválida: objeto";
      return false;
    }
    Mesh mesh;
    if (!Upload(data.data(), data.size(), &mesh, error)) return false;
    objects_.push_back(std::move(mesh));
  }
  for (auto& buffer : pixels_) buffer.assign(width_ * height_ * 4, 0);
  return true;
}

bool Renderer::CreateDeviceResources(std::string* error) {
  static ComPtr<ID3D11Device> shared_device;
  static ComPtr<ID3D11DeviceContext> shared_context;
  static std::string shared_error;
  static std::string shared_device_info;
  static bool attempted = false;
  if (!attempted) {
    attempted = true;
    // Shader model 5.0 requires feature level 11_0; WARP provides it even
    // without a suitable GPU, so there is no lower-level fallback path.
    // O tipo de driver é registrado: se o notebook cair no WARP
    // (renderização por software), cada quadro custa dezenas de ms e
    // nenhum anel de readback resolve — o diagnóstico precisa mostrar isso.
    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0};
    D3D_FEATURE_LEVEL chosen;
    const char* driver = "HARDWARE";
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                                   0, levels, 1, D3D11_SDK_VERSION,
                                   &shared_device, &chosen, &shared_context);
    if (FAILED(hr)) {
      driver = "WARP";
      hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0, levels,
                             1, D3D11_SDK_VERSION, &shared_device, &chosen,
                             &shared_context);
    }
    if (FAILED(hr)) {
      shared_error = "Direct3D 11 não disponível";
    } else {
      std::string adapter_name = "desconhecido";
      ComPtr<IDXGIDevice> dxgi_device;
      ComPtr<IDXGIAdapter> adapter;
      if (SUCCEEDED(shared_device.As(&dxgi_device)) &&
          SUCCEEDED(dxgi_device->GetAdapter(&adapter))) {
        DXGI_ADAPTER_DESC desc{};
        if (SUCCEEDED(adapter->GetDesc(&desc))) {
          adapter_name = NarrowWide(desc.Description);
        }
      }
      shared_device_info = std::string(driver) + " | " + adapter_name +
                           " | FL 11.0";
    }
  }
  if (!shared_device) {
    *error = shared_error;
    return false;
  }
  device_ = shared_device;
  context_ = shared_context;
  device_info_ = shared_device_info;
  return true;
}

bool Renderer::CreateShaders(std::string* error) {
  auto compile = [&](const char* source, const char* entry,
                     const char* target, ComPtr<ID3DBlob>* blob) {
    ComPtr<ID3DBlob> errors;
    const HRESULT hr = D3DCompile(source, std::strlen(source), nullptr, nullptr,
                                  nullptr, entry, target, 0, 0, blob->GetAddressOf(),
                                  &errors);
    if (FAILED(hr)) {
      *error = "Shader: ";
      if (errors) {
        error->append(static_cast<const char*>(errors->GetBufferPointer()),
                      errors->GetBufferSize());
      } else {
        *error += "falha ao compilar";
      }
      return false;
    }
    return true;
  };
  ComPtr<ID3DBlob> scene_vs, scene_ps, depth_vs, depth_ps;
  if (!compile(kSceneShader, "VSMain", "vs_5_0", &scene_vs)) return false;
  if (!compile(kSceneShader, "PSMain", "ps_5_0", &scene_ps)) return false;
  if (!compile(kDepthShader, "VSMain", "vs_5_0", &depth_vs)) return false;
  if (!compile(kDepthShader, "PSMain", "ps_5_0", &depth_ps)) return false;
  if (FAILED(device_->CreateVertexShader(scene_vs->GetBufferPointer(),
                                         scene_vs->GetBufferSize(), nullptr,
                                         &scene_vs_)) ||
      FAILED(device_->CreatePixelShader(scene_ps->GetBufferPointer(),
                                        scene_ps->GetBufferSize(), nullptr,
                                        &scene_ps_)) ||
      FAILED(device_->CreateVertexShader(depth_vs->GetBufferPointer(),
                                         depth_vs->GetBufferSize(), nullptr,
                                         &depth_vs_)) ||
      FAILED(device_->CreatePixelShader(depth_ps->GetBufferPointer(),
                                        depth_ps->GetBufferSize(), nullptr,
                                        &depth_ps_))) {
    *error = "Falha ao criar shaders";
    return false;
  }
  const D3D11_INPUT_ELEMENT_DESC elements[] = {
      {"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,
       D3D11_INPUT_PER_VERTEX_DATA, 0},
      {"NORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 12,
       D3D11_INPUT_PER_VERTEX_DATA, 0},
      {"COLOR", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 24,
       D3D11_INPUT_PER_VERTEX_DATA, 0},
      {"TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 36,
       D3D11_INPUT_PER_VERTEX_DATA, 0},
      {"TEXCOORD", 1, DXGI_FORMAT_R32_FLOAT, 0, 44,
       D3D11_INPUT_PER_VERTEX_DATA, 0},
  };
  if (FAILED(device_->CreateInputLayout(
          elements, 5, scene_vs->GetBufferPointer(), scene_vs->GetBufferSize(),
          &layout_))) {
    *error = "Falha ao criar layout de vértices";
    return false;
  }
  D3D11_BUFFER_DESC desc{};
  desc.Usage = D3D11_USAGE_DYNAMIC;
  desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
  desc.ByteWidth = 208;  // FrameCB: 13 float4.
  if (FAILED(device_->CreateBuffer(&desc, nullptr, &frame_cb_))) {
    *error = "Falha ao criar constantes";
    return false;
  }
  desc.ByteWidth = 128;  // ModelCB: 8 float4.
  if (FAILED(device_->CreateBuffer(&desc, nullptr, &model_cb_))) {
    *error = "Falha ao criar constantes";
    return false;
  }
  return true;
}

bool Renderer::CreateTargets(std::string* error) {
  D3D11_TEXTURE2D_DESC tex{};
  tex.Width = width_;
  tex.Height = height_;
  tex.MipLevels = 1;
  tex.ArraySize = 1;
  tex.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  tex.SampleDesc.Count = 1;
  tex.Usage = D3D11_USAGE_DEFAULT;
  tex.BindFlags = D3D11_BIND_RENDER_TARGET;
  if (FAILED(device_->CreateTexture2D(&tex, nullptr, &color_tex_)) ||
      FAILED(device_->CreateRenderTargetView(color_tex_.Get(), nullptr,
                                             &color_rtv_))) {
    *error = "Alvo gráfico indisponível";
    return false;
  }
  tex.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
  tex.BindFlags = D3D11_BIND_DEPTH_STENCIL;
  if (FAILED(device_->CreateTexture2D(&tex, nullptr, &depth_tex_)) ||
      FAILED(device_->CreateDepthStencilView(depth_tex_.Get(), nullptr,
                                             &depth_dsv_))) {
    *error = "Alvo gráfico indisponível";
    return false;
  }
  D3D11_TEXTURE2D_DESC shadow{};
  shadow.Width = shadow_size_;
  shadow.Height = shadow_size_;
  shadow.MipLevels = 1;
  shadow.ArraySize = 1;
  shadow.Format = DXGI_FORMAT_R24G8_TYPELESS;
  shadow.SampleDesc.Count = 1;
  shadow.Usage = D3D11_USAGE_DEFAULT;
  shadow.BindFlags = D3D11_BIND_DEPTH_STENCIL | D3D11_BIND_SHADER_RESOURCE;
  if (FAILED(device_->CreateTexture2D(&shadow, nullptr, &shadow_tex_))) {
    *error = "Mapa de sombras indisponível";
    return false;
  }
  D3D11_DEPTH_STENCIL_VIEW_DESC dsv{};
  dsv.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
  dsv.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
  if (FAILED(device_->CreateDepthStencilView(shadow_tex_.Get(), &dsv,
                                             &shadow_dsv_))) {
    *error = "Mapa de sombras indisponível";
    return false;
  }
  D3D11_SHADER_RESOURCE_VIEW_DESC srv{};
  srv.Format = DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
  srv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  srv.Texture2D.MipLevels = 1;
  if (FAILED(device_->CreateShaderResourceView(shadow_tex_.Get(), &srv,
                                               &shadow_srv_))) {
    *error = "Mapa de sombras indisponível";
    return false;
  }
  D3D11_TEXTURE2D_DESC staging{};
  staging.Width = width_;
  staging.Height = height_;
  staging.MipLevels = 1;
  staging.ArraySize = 1;
  staging.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  staging.SampleDesc.Count = 1;
  staging.Usage = D3D11_USAGE_STAGING;
  staging.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  for (auto& slot : staging_) {
    if (FAILED(device_->CreateTexture2D(&staging, nullptr, &slot))) {
      *error = "Alvo gráfico indisponível";
      return false;
    }
  }
  D3D11_RASTERIZER_DESC raster{};
  raster.FillMode = D3D11_FILL_SOLID;
  raster.CullMode = D3D11_CULL_NONE;
  // Matches the Kotlin front-face choice: GL_CCW (showroom) and GL_CW
  // (mirrored race projection) map to these D3D settings for the same
  // image on screen.
  raster.FrontCounterClockwise = showroom_ ? TRUE : FALSE;
  raster.DepthClipEnable = TRUE;
  if (FAILED(device_->CreateRasterizerState(&raster, &raster_main_))) {
    *error = "Falha ao criar rasterizador";
    return false;
  }
  raster.DepthBias = 2;
  raster.SlopeScaledDepthBias = 1.3f;
  if (FAILED(device_->CreateRasterizerState(&raster, &raster_shadow_))) {
    *error = "Falha ao criar rasterizador";
    return false;
  }
  D3D11_DEPTH_STENCIL_DESC depth{};
  depth.DepthEnable = TRUE;
  depth.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
  depth.DepthFunc = D3D11_COMPARISON_LESS_EQUAL;
  if (FAILED(device_->CreateDepthStencilState(&depth, &depth_write_))) {
    *error = "Falha ao criar estado de profundidade";
    return false;
  }
  depth.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ZERO;
  if (FAILED(device_->CreateDepthStencilState(&depth, &depth_no_write_))) {
    *error = "Falha ao criar estado de profundidade";
    return false;
  }
  D3D11_BLEND_DESC blend{};
  blend.RenderTarget[0].BlendEnable = TRUE;
  blend.RenderTarget[0].SrcBlend = D3D11_BLEND_SRC_ALPHA;
  blend.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
  blend.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
  blend.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_SRC_ALPHA;
  blend.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
  blend.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
  blend.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
  if (FAILED(device_->CreateBlendState(&blend, &blend_alpha_))) {
    *error = "Falha ao criar estado de mistura";
    return false;
  }
  D3D11_SAMPLER_DESC sampler{};
  sampler.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
  sampler.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
  sampler.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
  sampler.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
  if (FAILED(device_->CreateSamplerState(&sampler, &shadow_sampler_))) {
    *error = "Falha ao criar amostrador";
    return false;
  }
  return true;
}

bool Renderer::Upload(const float* data, size_t floats, Mesh* mesh,
                      std::string* error) {
  D3D11_BUFFER_DESC desc{};
  desc.Usage = D3D11_USAGE_IMMUTABLE;
  desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
  desc.ByteWidth = static_cast<UINT>(floats * sizeof(float));
  D3D11_SUBRESOURCE_DATA initial{};
  initial.pSysMem = data;
  if (FAILED(device_->CreateBuffer(&desc, &initial, &mesh->vertices))) {
    *error = "Falha ao enviar malha 3D";
    return false;
  }
  mesh->vertex_count = static_cast<uint32_t>(floats / 12);
  mesh->bounds = BoundsOf(data, 0, floats);
  mesh->transparent = IsTransparent(data, floats);
  mesh->casts_shadow = CastsShadow(data, floats);
  return true;
}

void Renderer::SetFrameConstants(const float vp[16], const float light_vp[16],
                                 const float* frame) {
  D3D11_MAPPED_SUBRESOURCE mapped;
  if (FAILED(context_->Map(frame_cb_.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0,
                           &mapped))) {
    return;
  }
  float* f = static_cast<float*>(mapped.pData);
  std::memcpy(f, vp, sizeof(float) * 16);
  std::memcpy(f + 16, light_vp, sizeof(float) * 16);
  f[32] = frame[0]; f[33] = frame[1]; f[34] = frame[2]; f[35] = 0;
  f[36] = -0.52f; f[37] = 0.76f; f[38] = -0.39f; f[39] = 0;
  if (night_) {
    f[40] = 0.62f; f[41] = 0.76f; f[42] = 1.10f;
    f[44] = 0.17f; f[45] = 0.26f; f[46] = 0.47f;
  } else {
    f[40] = 1.14f; f[41] = 1.01f; f[42] = 0.87f;
    f[44] = 0.46f; f[45] = 0.62f; f[46] = 0.76f;
  }
  f[43] = 0; f[47] = 0;
  f[48] = frame[9];
  f[49] = night_ ? 1.0f : 0.0f;
  f[50] = 1.0f / static_cast<float>(shadow_size_);
  f[51] = shadow_quality_;
  context_->Unmap(frame_cb_.Get(), 0);
}

void Renderer::SetModelConstants(const float* model) {
  D3D11_MAPPED_SUBRESOURCE mapped;
  if (FAILED(context_->Map(model_cb_.Get(), 0, D3D11_MAP_WRITE_DISCARD, 0,
                           &mapped))) {
    return;
  }
  float* f = static_cast<float*>(mapped.pData);
  std::memcpy(f, model, sizeof(float) * 16);
  NormalColumns(model, f + 16);
  std::memset(f + 28, 0, sizeof(float) * 4);
  context_->Unmap(model_cb_.Get(), 0);
}

void Renderer::DrawMesh(const Mesh& mesh, const float* model) {
  SetModelConstants(model);
  ID3D11Buffer* buffer = mesh.vertices.Get();
  const UINT stride = kStride, offset = 0;
  context_->IASetVertexBuffers(0, 1, &buffer, &stride, &offset);
  context_->Draw(mesh.vertex_count, 0);
}

const std::string* Renderer::Render(const std::vector<float>& data) {
  std::lock_guard<std::mutex> context_lock(g_context_mutex);
  if (!error_.empty()) return &error_;
  if (data.size() < 15) return nullptr;
  for (const float v : data) {
    if (!std::isfinite(v)) return nullptr;
  }
  const int count = std::clamp(static_cast<int>(data[14]), 0, kMaxInstances);
  if (data.size() != static_cast<size_t>(15 + count * 17)) return nullptr;
  const float* frame = data.data();
  // Medido aqui porque o custo que importa é o da thread de plataforma:
  // desenho + readback. É ele que decide se teclado/mouse têm folga.
  const int64_t render_start_ns = NowNs();

  float projection[16], view[16], vp[16], vp_d3d[16];
  MatPerspective(showroom_ ? 40.0f : 50.0f,
                 static_cast<float>(width_) / static_cast<float>(height_),
                 showroom_ ? 0.1f : 0.18f, 2600.0f, projection);
  if (!showroom_) projection[0] = -projection[0];
  const float eye[3] = {frame[0], frame[1], frame[2]};
  const float target[3] = {frame[3], frame[4], frame[5]};
  const float up[3] = {frame[6], frame[7], frame[8]};
  MatLookAt(eye, target, up, view);
  MatMultiply(projection, view, vp);
  MatRemapZ(vp, vp_d3d);
  Frustum camera_frustum;
  camera_frustum.Set(vp);

  const float light_dir[3] = {-0.52f, 0.76f, -0.39f};
  const float center[3] = {frame[10], frame[11], frame[12]};
  const float light_eye[3] = {center[0] + light_dir[0] * 230.0f,
                              center[1] + light_dir[1] * 230.0f,
                              center[2] + light_dir[2] * 230.0f};
  const float world_up[3] = {0, 1, 0};
  float light_view[16], light_projection[16], light_vp[16], light_vp_d3d[16];
  MatLookAt(light_eye, center, world_up, light_view);
  const float span = showroom_ ? 9.0f : 105.0f;
  MatOrtho(-span, span, -span, span, 1.0f, 650.0f, light_projection);
  MatMultiply(light_projection, light_view, light_vp);
  MatRemapZ(light_vp, light_vp_d3d);
  Frustum shadow_frustum;
  shadow_frustum.Set(light_vp);

  static const float kIdentity[16] = {1, 0, 0, 0, 0, 1, 0, 0,
                                      0, 0, 1, 0, 0, 0, 0, 1};
  SetFrameConstants(vp_d3d, light_vp_d3d, frame);
  ID3D11Buffer* cbuffers[2] = {frame_cb_.Get(), model_cb_.Get()};
  context_->IASetInputLayout(layout_.Get());
  context_->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
  context_->VSSetConstantBuffers(0, 2, cbuffers);
  context_->OMSetBlendState(nullptr, nullptr, 0xffffffff);
  context_->OMSetDepthStencilState(depth_write_.Get(), 0);

  // Shadow pass.
  D3D11_VIEWPORT viewport{};
  viewport.Width = static_cast<float>(shadow_size_);
  viewport.Height = static_cast<float>(shadow_size_);
  viewport.MaxDepth = 1.0f;
  context_->RSSetViewports(1, &viewport);
  context_->RSSetState(raster_shadow_.Get());
  context_->OMSetRenderTargets(0, nullptr, shadow_dsv_.Get());
  context_->ClearDepthStencilView(shadow_dsv_.Get(), D3D11_CLEAR_DEPTH, 1.0f, 0);
  context_->VSSetShader(depth_vs_.Get(), nullptr, 0);
  context_->PSSetShader(depth_ps_.Get(), nullptr, 0);
  for (const Mesh& mesh : world_) {
    if (mesh.casts_shadow && shadow_frustum.Visible(mesh.bounds)) {
      DrawMesh(mesh, kIdentity);
    }
  }
  for (int i = 0; i < count; i++) {
    const int offset = 15 + i * 17;
    const int mesh_index = static_cast<int>(frame[offset]);
    if (mesh_index < 0 || mesh_index >= static_cast<int>(objects_.size())) {
      continue;
    }
    const Mesh& mesh = objects_[mesh_index];
    if (!mesh.transparent && mesh.casts_shadow &&
        shadow_frustum.Visible(mesh.bounds, frame + offset + 1)) {
      DrawMesh(mesh, frame + offset + 1);
    }
  }

  // Main pass.
  viewport.Width = static_cast<float>(width_);
  viewport.Height = static_cast<float>(height_);
  context_->RSSetViewports(1, &viewport);
  context_->RSSetState(raster_main_.Get());
  ID3D11RenderTargetView* rtv = color_rtv_.Get();
  context_->OMSetRenderTargets(1, &rtv, depth_dsv_.Get());
  const float clear[4] = {showroom_ ? 0.046f : night_ ? 0.10f : 0.40f,
                          showroom_ ? 0.078f : night_ ? 0.15f : 0.53f,
                          showroom_ ? 0.125f : night_ ? 0.26f : 0.63f, 1.0f};
  context_->ClearRenderTargetView(color_rtv_.Get(), clear);
  context_->ClearDepthStencilView(depth_dsv_.Get(), D3D11_CLEAR_DEPTH, 1.0f, 0);
  context_->VSSetShader(scene_vs_.Get(), nullptr, 0);
  context_->PSSetShader(scene_ps_.Get(), nullptr, 0);
  context_->PSSetConstantBuffers(0, 1, cbuffers);
  ID3D11ShaderResourceView* srv = shadow_srv_.Get();
  context_->PSSetShaderResources(0, 1, &srv);
  ID3D11SamplerState* sampler = shadow_sampler_.Get();
  context_->PSSetSamplers(0, 1, &sampler);
  for (const Mesh& mesh : world_) {
    if (camera_frustum.Visible(mesh.bounds)) DrawMesh(mesh, kIdentity);
  }
  std::vector<int> order(count);
  for (int i = 0; i < count; i++) order[i] = i;
  for (int pass = 0; pass < 2; pass++) {
    if (pass == 1) {
      std::sort(order.begin(), order.end(), [&](int a, int b) {
        const float* ma = frame + 15 + a * 17 + 1;
        const float* mb = frame + 15 + b * 17 + 1;
        const float da = (ma[12] - eye[0]) * (ma[12] - eye[0]) +
                         (ma[13] - eye[1]) * (ma[13] - eye[1]) +
                         (ma[14] - eye[2]) * (ma[14] - eye[2]);
        const float db = (mb[12] - eye[0]) * (mb[12] - eye[0]) +
                         (mb[13] - eye[1]) * (mb[13] - eye[1]) +
                         (mb[14] - eye[2]) * (mb[14] - eye[2]);
        return da > db;
      });
      context_->OMSetBlendState(blend_alpha_.Get(), nullptr, 0xffffffff);
      context_->OMSetDepthStencilState(depth_no_write_.Get(), 0);
    }
    for (const int i : order) {
      const int offset = 15 + i * 17;
      const int mesh_index = static_cast<int>(frame[offset]);
      if (mesh_index < 0 || mesh_index >= static_cast<int>(objects_.size())) {
        continue;
      }
      const Mesh& mesh = objects_[mesh_index];
      if (mesh.transparent != (pass == 1)) continue;
      if (!camera_frustum.Visible(mesh.bounds, frame + offset + 1)) continue;
      DrawMesh(mesh, frame + offset + 1);
    }
  }
  context_->OMSetBlendState(nullptr, nullptr, 0xffffffff);
  context_->OMSetDepthStencilState(depth_write_.Get(), 0);
  ID3D11ShaderResourceView* null_srv = nullptr;
  context_->PSSetShaderResources(0, 1, &null_srv);

  Readback();
  if (!error_.empty()) return &error_;
  last_render_ms_ =
      static_cast<double>(NowNs() - render_start_ns) / 1000000.0;
  presented_++;
  const int64_t now = NowNs();
  if (fps_window_start_ == 0) fps_window_start_ = now;
  if (now - fps_window_start_ >= 1000000000LL) {
    presented_fps_ =
        presented_ * 1000000000.0 / static_cast<double>(now - fps_window_start_);
    presented_ = 0;
    fps_window_start_ = now;
  }
  if (on_frame_available) on_frame_available();
  return nullptr;
}

void Renderer::Readback() {
  // Copy the fresh frame into the ring, then read the slot copied two
  // frames ago. Mapping the texture that was just copied blocks until
  // the GPU finishes the entire frame; doing that on the platform
  // thread froze the game and starved keyboard and mouse input, which
  // the Windows embedder also delivers on that thread.
  const int write = staging_cursor_;
  context_->CopyResource(staging_[write].Get(), color_tex_.Get());
  staging_cursor_ = (staging_cursor_ + 1) % 3;
  frames_rendered_++;
  if (frames_rendered_ < 3) return;
  const int read = staging_cursor_;
  D3D11_MAPPED_SUBRESOURCE mapped;
  if (FAILED(context_->Map(staging_[read].Get(), 0, D3D11_MAP_READ, 0,
                           &mapped))) {
    error_ = "Falha ao apresentar quadro Direct3D";
    return;
  }
  const int back = 1 - latest_pixels_;
  uint8_t* dst = pixels_[back].data();
  const uint8_t* src = static_cast<const uint8_t*>(mapped.pData);
  const size_t row = static_cast<size_t>(width_) * 4;
  for (int y = 0; y < height_; y++) {
    std::memcpy(dst + y * row, src + y * mapped.RowPitch, row);
  }
  context_->Unmap(staging_[read].Get(), 0);
  latest_pixels_ = back;
}

const uint8_t* Renderer::LatestPixels() {
  return pixels_[latest_pixels_.load()].data();
}

Renderer::~Renderer() { StopThread(); }

void Renderer::StartThread() {
  if (thread_.joinable()) return;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = false;
    has_pending_ = false;
    first_done_ = false;
    async_error_.clear();
  }
  thread_ = std::thread(&Renderer::ThreadMain, this);
}

void Renderer::StopThread() {
  if (!thread_.joinable()) return;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = true;
  }
  cv_.notify_all();
  thread_.join();
}

void Renderer::PostFrame(const std::vector<float>& frame) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    pending_ = frame;
    has_pending_ = true;
  }
  cv_.notify_one();
}

bool Renderer::WaitFirstFrame(int timeout_ms) {
  std::unique_lock<std::mutex> lock(mutex_);
  cv_.wait_for(lock, std::chrono::milliseconds(timeout_ms),
               [&] { return first_done_ || stop_; });
  return first_done_ && async_error_.empty();
}

const std::string* Renderer::TakeAsyncError() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (async_error_.empty()) return nullptr;
  reported_error_ = async_error_;
  async_error_.clear();
  return &reported_error_;
}

void Renderer::ThreadMain() {
  std::unique_lock<std::mutex> lock(mutex_);
  while (!stop_) {
    if (!has_pending_) {
      cv_.wait(lock);
      continue;
    }
    std::vector<float> data = std::move(pending_);
    has_pending_ = false;
    lock.unlock();
    const std::string* failure = Render(data);
    lock.lock();
    if (failure != nullptr) async_error_ = *failure;
    if (!first_done_) {
      first_done_ = true;
      cv_.notify_all();
    }
  }
}

}  // namespace carwece_graphics
