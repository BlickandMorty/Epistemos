/* Copyright © 2023-2024 Apple Inc.                   */
/*                                                    */
/* This file is auto-generated. Do not edit manually. */
/*                                                    */

#include "mlx/c/io.h"
#include "mlx/c/error.h"
#include "mlx/c/private/mlx.h"
#include "mlx/io.h"

#if defined(__clang__) || defined(__GNUC__)
#define MLX_C_USED_SYMBOL __attribute__((used))
#else
#define MLX_C_USED_SYMBOL
#endif

extern "C" int
mlx_load_reader(mlx_array* res, mlx_io_reader in_stream, const mlx_stream s) {
  try {
    mlx_array_set_(
        *res,
        mlx::core::load(mlx_io_reader_get_(in_stream), mlx_stream_get_(s)));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_load(mlx_array* res, const char* file, const mlx_stream s) {
  try {
    mlx_array_set_(
        *res, mlx::core::load(std::string(file), mlx_stream_get_(s)));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_load_safetensors_reader(
    mlx_map_string_to_array* res_0,
    mlx_map_string_to_string* res_1,
    mlx_io_reader in_stream,
    const mlx_stream s) {
  try {
    {
      auto [tpl_0, tpl_1] = mlx::core::load_safetensors(
          mlx_io_reader_get_(in_stream), mlx_stream_get_(s));
      mlx_map_string_to_array_set_(*res_0, tpl_0);
      mlx_map_string_to_string_set_(*res_1, tpl_1);
    };
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_load_safetensors(
    mlx_map_string_to_array* res_0,
    mlx_map_string_to_string* res_1,
    const char* file,
    const mlx_stream s) {
  try {
    {
      auto [tpl_0, tpl_1] =
          mlx::core::load_safetensors(std::string(file), mlx_stream_get_(s));
      mlx_map_string_to_array_set_(*res_0, tpl_0);
      mlx_map_string_to_string_set_(*res_1, tpl_1);
    };
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" MLX_C_USED_SYMBOL int64_t
mlx_safetensors_mmap_advise_routed(int32_t advice, int32_t cold_pct) {
  return mlx::core::safetensors_mmap_advise_routed(advice, cold_pct);
}
extern "C" MLX_C_USED_SYMBOL int64_t mlx_safetensors_mmap_advise_experts(
    int32_t advice,
    const int32_t* layers,
    const int32_t* experts,
    int64_t count) {
  return mlx::core::safetensors_mmap_advise_experts(
      advice, layers, experts, count);
}
extern "C" MLX_C_USED_SYMBOL int64_t
mlx_safetensors_mmap_advise_layer(int32_t advice, int32_t layer) {
  return mlx::core::safetensors_mmap_advise_layer(advice, layer);
}
extern "C" MLX_C_USED_SYMBOL int64_t
mlx_safetensors_mmap_tracked_buffer_bytes(void) {
  return mlx::core::safetensors_mmap_tracked_buffer_bytes();
}
extern "C" MLX_C_USED_SYMBOL int mlx_array_new_mmap_file_region(
    mlx_array* res,
    const char* file,
    uint64_t offset,
    size_t length,
    const int* shape,
    int dim,
    mlx_dtype dtype) {
  try {
    mlx::core::Shape cpp_shape(shape, shape + dim);
    mlx_array_set_(
        *res,
        mlx::core::mmap_file_region(
            std::string(file),
            offset,
            length,
            std::move(cpp_shape),
            mlx_dtype_to_cpp(dtype)));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_save_writer(mlx_io_writer out_stream, const mlx_array a) {
  try {
    mlx::core::save(mlx_io_writer_get_(out_stream), mlx_array_get_(a));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_save(const char* file, const mlx_array a) {
  try {
    mlx::core::save(std::string(file), mlx_array_get_(a));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_save_safetensors_writer(
    mlx_io_writer in_stream,
    const mlx_map_string_to_array param,
    const mlx_map_string_to_string metadata) {
  try {
    mlx::core::save_safetensors(
        mlx_io_writer_get_(in_stream),
        mlx_map_string_to_array_get_(param),
        mlx_map_string_to_string_get_(metadata));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
extern "C" int mlx_save_safetensors(
    const char* file,
    const mlx_map_string_to_array param,
    const mlx_map_string_to_string metadata) {
  try {
    mlx::core::save_safetensors(
        std::string(file),
        mlx_map_string_to_array_get_(param),
        mlx_map_string_to_string_get_(metadata));
  } catch (std::exception& e) {
    mlx_error(e.what());
    return 1;
  }
  return 0;
}
