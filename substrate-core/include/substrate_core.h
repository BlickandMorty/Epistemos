// substrate-core C ABI. Rust owns canonical entity state.
// EntityId is a u64 (transparent over slotmap::KeyData::as_ffi()).

#ifndef SUBSTRATE_CORE_H
#define SUBSTRATE_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SubstrateStore SubstrateStore;
typedef uint64_t SubstrateEntityId;

SubstrateStore* substrate_store_new(void);
void            substrate_store_free(SubstrateStore* store);

SubstrateEntityId substrate_reserve_id(const SubstrateStore* store);
uint64_t          substrate_len(const SubstrateStore* store);

// Returns 0 on success, non-zero on error (see substrate_last_error).
int substrate_create_note(const SubstrateStore* store,
                          SubstrateEntityId id,
                          const char* title,
                          const char* body,
                          int64_t at);

// Returns owned JSON string or NULL if entity absent.
// Caller MUST free with substrate_string_free.
char* substrate_get_json(const SubstrateStore* store, SubstrateEntityId id);

int substrate_undo(const SubstrateStore* store);
int substrate_redo(const SubstrateStore* store);

// Copy last error into buf (UTF-8, NUL-terminated). Returns message length
// excluding NUL. If buf is NULL, returns required length.
size_t substrate_last_error(char* buf, size_t cap);

void substrate_string_free(char* s);

#ifdef __cplusplus
}
#endif

#endif // SUBSTRATE_CORE_H
