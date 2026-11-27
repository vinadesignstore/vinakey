// Stable C ABI; no STL containers or Rust-owned strings cross this boundary.
#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct OkEngine OkEngine;
typedef struct {
    int32_t input_type, code_table, spelling, quick_telex, modern, restore_invalid;
    int32_t macros, auto_caps_macro, free_mark, upper_first, allow_consonants, quick_start, quick_end;
} OkConfig;
typedef struct {
    uint8_t code, backspaces, count, ext;
    uint32_t chars[32];
    int32_t spelling;
} OkResult;
typedef struct { uint8_t *data; size_t len; int32_t status; } OkBuffer;
// All calls on one handle must be serialized. Destroy each handle/buffer exactly once.
OkEngine *ok_engine_create(void);
void ok_engine_destroy(OkEngine *);
int32_t ok_engine_process(OkEngine *, const OkConfig *, uint32_t event, uint32_t state,
                          uint32_t key, uint32_t caps, int32_t control, int32_t english, OkResult *);
int32_t ok_engine_clear(OkEngine *, const OkConfig *);
int32_t ok_engine_reset(OkEngine *, const OkConfig *, int32_t full);
void ok_engine_option(OkEngine *, uint32_t action, int32_t value);
uint32_t ok_character_code(uint32_t value, uint32_t code);
uint32_t ok_key_character(uint32_t value);
// ok_engine_command operations (values are ABI; see command in ffi.rs).
enum {
    OK_CMD_LOAD_MACROS = 0,
    OK_CMD_SAVE_MACROS = 1,
    OK_CMD_ADD_MACRO = 2,
    OK_CMD_DELETE_MACRO = 3,
    OK_CMD_HAS_MACRO = 4,
    OK_CMD_LIST_MACROS = 5,
    OK_CMD_IMPORT_MACROS = 6,
    OK_CMD_EXPORT_MACROS = 7,
    OK_CMD_LOAD_APPS = 8,
    OK_CMD_SAVE_APPS = 9,
    OK_CMD_GET_APP_LANGUAGE = 10,
    OK_CMD_SET_APP_LANGUAGE = 11,
    OK_CMD_CONVERT = 12,
    OK_CMD_FIND_MACRO = 13,
    OK_CMD_MACRO_DATA = 14,
    OK_CMD_ENCODE = 15,
};
// ok_engine_option actions.
enum { OK_OPTION_SPELLING_BASELINE = 0, OK_OPTION_TEMPORARY_OFF = 1 };
// Returned bytes belong to Rust; release each buffer with ok_buffer_free.
OkBuffer ok_engine_command(OkEngine *, uint32_t operation, const uint8_t *, size_t len, uint32_t code, uint32_t flags);
void ok_buffer_free(OkBuffer);
#ifdef __cplusplus
}
#endif
