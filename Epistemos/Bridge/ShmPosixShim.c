//
//  ShmPosixShim.c
//  Epistemos
//
//  See ShmPosixShim.h for the rationale. These wrappers are paper-thin
//  pass-throughs; the C compiler handles the variadic signature of the
//  underlying POSIX functions correctly because we are calling them
//  with the canonical three-argument (open) and one-argument (unlink)
//  shapes.
//

#include "ShmPosixShim.h"
#include <sys/mman.h>

int epistemos_shm_open(const char *name, int oflag, mode_t mode) {
    return shm_open(name, oflag, mode);
}

int epistemos_shm_unlink(const char *name) {
    return shm_unlink(name);
}
