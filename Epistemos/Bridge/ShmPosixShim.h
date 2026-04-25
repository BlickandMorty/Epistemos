//
//  ShmPosixShim.h
//  Epistemos
//
//  Fixed-signature wrappers around POSIX shm_open / shm_unlink.
//
//  The Darwin headers declare shm_open as variadic (`int shm_open(const char
//  *, int, ...)`), which Swift's automatic C bridging cannot import. The
//  earlier workaround used `dlopen(nil, RTLD_LAZY)` + `dlsym("shm_open")` to
//  reach the symbol at runtime; while sandbox-safe (the self-handle dlopen
//  does not load an external dylib), the literal `dlopen` / `dlsym` /
//  `RTLD_LAZY` strings in MAS-visible source can attract attention from
//  paranoid App Store review tooling. These wrappers expose the actual
//  fixed ABI so Swift can call them via the normal C bridging layer.
//
//  The shim has no platform-specific behavior; it is identical in MAS and
//  Pro builds.
//

#ifndef EPISTEMOS_SHM_POSIX_SHIM_H
#define EPISTEMOS_SHM_POSIX_SHIM_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Wrapper for POSIX `shm_open` with a fixed three-argument signature.
/// Returns a file descriptor on success, -1 on failure (with `errno` set).
int epistemos_shm_open(const char *name, int oflag, mode_t mode);

/// Wrapper for POSIX `shm_unlink`. Returns 0 on success, -1 on failure
/// (with `errno` set).
int epistemos_shm_unlink(const char *name);

#ifdef __cplusplus
}
#endif

#endif
