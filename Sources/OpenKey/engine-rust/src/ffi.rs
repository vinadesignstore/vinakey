use crate::{engine::Engine, text, Config};
use std::{
    panic::{catch_unwind, AssertUnwindSafe},
    slice,
};

/// `ok_engine_command` operations. These values are ABI; `OpenKeyRust.h` mirrors them (checked in tests).
pub mod command {
    /// Replace macros from persisted bytes; empty input clears them.
    pub const LOAD_MACROS: u32 = 0;
    /// Persisted macro bytes, sorted by encoded key.
    pub const SAVE_MACROS: u32 = 1;
    /// Input is `name\0content`.
    pub const ADD_MACRO: u32 = 2;
    pub const DELETE_MACRO: u32 = 3;
    pub const HAS_MACRO: u32 = 4;
    /// Same format as `SAVE_MACROS`; used to list macros.
    pub const LIST_MACROS: u32 = 5;
    /// UniKey-compatible text; `flags != 0` appends.
    pub const IMPORT_MACROS: u32 = 6;
    pub const EXPORT_MACROS: u32 = 7;
    pub const LOAD_APPS: u32 = 8;
    pub const SAVE_APPS: u32 = 9;
    /// Returns the stored i32, or -1 after storing `flags` for a new app.
    pub const GET_APP_LANGUAGE: u32 = 10;
    pub const SET_APP_LANGUAGE: u32 = 11;
    /// `flags`: bits 24.. source table, 1 upper, 2 lower, 4 sentence, 8 words, 16 remove marks.
    pub const CONVERT: u32 = 12;
    /// Input is little-endian u32 key codes; returns u32 content.
    pub const FIND_MACRO: u32 = 13;
    /// u32 content of the last macro replacement.
    pub const MACRO_DATA: u32 = 14;
    /// Text as u32 key codes for `code`.
    pub const ENCODE: u32 = 15;
}
/// `ok_engine_option` actions.
pub mod option {
    /// Spelling setting restored after a temporary toggle.
    pub const SPELLING_BASELINE: u32 = 0;
    /// Pause composition until the next word boundary.
    pub const TEMPORARY_OFF: u32 = 1;
}
#[repr(C)]
#[derive(Default)]
pub struct ResultState {
    pub code: u8,
    pub backspaces: u8,
    pub count: u8,
    pub ext: u8,
    pub chars: [u32; 32],
    pub spelling: i32,
}
#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub status: i32,
}
impl Buffer {
    fn fail() -> Self {
        Self {
            data: std::ptr::null_mut(),
            len: 0,
            status: 0,
        }
    }
    fn new(bytes: Vec<u8>) -> Self {
        let mut bytes = bytes.into_boxed_slice();
        let result = Self {
            data: bytes.as_mut_ptr(),
            len: bytes.len(),
            status: 1,
        };
        std::mem::forget(bytes);
        result
    }
}
/// The caller owns the handle and must serialize calls to it.
#[no_mangle]
pub extern "C" fn ok_engine_create() -> *mut Engine {
    Box::into_raw(Box::new(Engine::default()))
}
/// # Safety
/// `engine` must be null or a live handle returned by `ok_engine_create`, freed once.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_destroy(engine: *mut Engine) {
    if !engine.is_null() {
        unsafe {
            drop(Box::from_raw(engine));
        }
    }
}
/// # Safety
/// All non-null pointers must be live, aligned, and exclusively accessible for this call.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_process(
    engine: *mut Engine,
    config: *const Config,
    event: u32,
    state: u32,
    key: u32,
    caps: u32,
    control: i32,
    english: i32,
    out: *mut ResultState,
) -> i32 {
    if engine.is_null() || config.is_null() || out.is_null() {
        return 0;
    }
    let config = unsafe { *config };
    if !config.valid() || event > 1 || state > 3 || key > 256 || caps > 2 {
        unsafe {
            *out = ResultState::default();
        }
        return 0;
    }
    let engine = unsafe { &mut *engine };
    let result = catch_unwind(AssertUnwindSafe(|| {
        engine.cfg = config;
        if english != 0 {
            engine.english(state, key, caps != 0, control != 0);
        } else {
            engine.event(event, state, key, caps, control != 0);
        }
        let h = &engine.hook;
        unsafe {
            *out = ResultState {
                code: h.code,
                backspaces: h.backspaces,
                count: h.count,
                ext: h.ext,
                chars: h.chars,
                spelling: engine.cfg.spelling,
            };
        }
    }));
    if result.is_err() {
        engine.new_session();
        unsafe {
            *out = ResultState::default();
        }
        return 0;
    }
    1
}
/// # Safety
/// Handle and configuration must be live and exclusively accessible.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_reset(
    engine: *mut Engine,
    config: *const Config,
    full: i32,
) -> i32 {
    if engine.is_null() || config.is_null() {
        return 0;
    }
    let config = unsafe { *config };
    if !config.valid() {
        return 0;
    }
    let engine = unsafe { &mut *engine };
    engine.cfg = config;
    if full != 0 {
        engine.reset();
    } else {
        engine.new_session();
    }
    1
}
/// # Safety
/// Handle must be live and exclusively accessible. Action 0 changes spelling baseline; 1 pauses composition.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_option(engine: *mut Engine, action: u32, value: i32) {
    if let Some(engine) = unsafe { engine.as_mut() } {
        match action {
            option::SPELLING_BASELINE => engine.spelling_before = value != 0,
            option::TEMPORARY_OFF => engine.temporary_off = value != 0,
            _ => {}
        }
    }
}
#[no_mangle]
pub extern "C" fn ok_character_code(value: u32, code: u32) -> u32 {
    text::character_code(value, code as usize)
}
#[no_mangle]
pub extern "C" fn ok_key_character(value: u32) -> u32 {
    text::key_character(value)
}

/// # Safety
/// Handle is exclusive. `input` must cover `len` readable bytes (or be null when len is zero).
/// Returned buffer must be released with `ok_buffer_free`, including empty successful results.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_command(
    engine: *mut Engine,
    operation: u32,
    input: *const u8,
    len: usize,
    code: u32,
    flags: u32,
) -> Buffer {
    if engine.is_null() || len > 64 * 1024 * 1024 || (input.is_null() && len != 0) || code >= 5 {
        return Buffer::fail();
    }
    let engine = unsafe { &mut *engine };
    let input = if len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(input, len) }
    };
    let result = catch_unwind(AssertUnwindSafe(|| -> Option<Vec<u8>> {
        let string = || std::str::from_utf8(input).ok();
        match operation {
            command::LOAD_MACROS => {
                if input.is_empty() {
                    engine.macros = text::Macros::default();
                    Some(vec![])
                } else {
                    engine.macros.load(input).then(Vec::new)
                }
            }
            command::SAVE_MACROS | command::LIST_MACROS => Some(engine.macros.save(code as usize)),
            command::ADD_MACRO => {
                let (key, value) = string()?.split_once('\0')?;
                engine.macros.add(key, value).then(Vec::new)
            }
            command::DELETE_MACRO => engine.macros.remove(string()?).then(Vec::new),
            command::HAS_MACRO => engine.macros.contains(string()?).then(Vec::new),
            command::IMPORT_MACROS => engine.macros.import(string()?, flags != 0).then(Vec::new),
            command::EXPORT_MACROS => Some(engine.macros.export().into_bytes()),
            command::LOAD_APPS => {
                let next = if input.is_empty() {
                    Default::default()
                } else {
                    text::load_apps(input)?
                };
                engine.apps = next;
                Some(vec![])
            }
            command::SAVE_APPS => Some(text::save_apps(&engine.apps)),
            command::GET_APP_LANGUAGE => {
                let name = string()?;
                if name.is_empty() || name.len() > 255 || flags > 9 {
                    return None;
                }
                let value = if let Some(value) = engine.apps.get(name) {
                    i32::from(*value)
                } else {
                    if engine.apps.len() >= 65535 {
                        return None;
                    }
                    engine.apps.insert(name.to_string(), flags as u8);
                    -1
                };
                Some(value.to_le_bytes().to_vec())
            }
            command::SET_APP_LANGUAGE => {
                let name = string()?;
                if name.is_empty()
                    || name.len() > 255
                    || flags > 9
                    || engine.apps.len() >= 65535 && !engine.apps.contains_key(name)
                {
                    return None;
                }
                engine.apps.insert(name.to_string(), flags as u8);
                Some(vec![])
            }
            command::CONVERT => {
                let from = (flags >> 24) as usize;
                Some(text::convert(string()?, from, code as usize, flags & 0xffffff).into_bytes())
            }
            command::FIND_MACRO => {
                if input.len() % 4 != 0 {
                    return None;
                }
                let key: Vec<u32> = input
                    .as_chunks::<4>()
                    .0
                    .iter()
                    .map(|x| u32::from_le_bytes(*x))
                    .collect();
                engine
                    .macros
                    .find(&key, code as usize, flags != 0)
                    .map(|data| data.into_iter().flat_map(u32::to_le_bytes).collect())
            }
            command::MACRO_DATA => Some(
                engine
                    .hook
                    .macro_data
                    .iter()
                    .flat_map(|x| x.to_le_bytes())
                    .collect(),
            ),
            command::ENCODE => Some(
                text::encode(string()?, code as usize)
                    .into_iter()
                    .flat_map(u32::to_le_bytes)
                    .collect(),
            ),
            _ => None,
        }
    }));
    match result {
        Ok(Some(bytes)) => Buffer::new(bytes),
        _ => Buffer::fail(),
    }
}
/// # Safety
/// Buffer must be exactly an unmodified return value from `ok_engine_command`, freed once.
#[no_mangle]
pub unsafe extern "C" fn ok_buffer_free(buffer: Buffer) {
    if !buffer.data.is_null() {
        unsafe {
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                buffer.data,
                buffer.len,
            )));
        }
    }
}

/// Clear a field/session boundary without discarding saved macros or app preferences.
/// # Safety
/// Handle and configuration must be live and exclusively accessible.
#[no_mangle]
pub unsafe extern "C" fn ok_engine_clear(engine: *mut Engine, config: *const Config) -> i32 {
    if engine.is_null() || config.is_null() {
        return 0;
    }
    let config = unsafe { *config };
    if !config.valid() {
        return 0;
    }
    unsafe { &mut *engine }.clear_composition(config);
    1
}
