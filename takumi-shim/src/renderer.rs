use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_uchar, c_void};
use std::ptr::null_mut;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use lru::LruCache;
use once_cell::sync::Lazy;
use serde_json;
use takumi::parley::GenericFamily;
use takumi::{
    GlobalContext,
    resources::{image::ImageSource, task::FetchTask},
};

// Type alias for a shareable renderer context
pub(crate) type SharedRenderer = Arc<Mutex<RendererInner>>;

pub(crate) type ResourceCache = Option<Arc<Mutex<LruCache<FetchTask, Arc<ImageSource>>>>>;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum AnimationOutputFormat {
    Webp,
    Apng,
}

/// Output format for rendered images.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum OutputFormat {
    WebP,
    Avif,
    Png,
    Jpeg,
    Raw,
}

impl From<OutputFormat> for takumi::rendering::ImageOutputFormat {
    fn from(format: OutputFormat) -> Self {
        match format {
            OutputFormat::WebP => takumi::rendering::ImageOutputFormat::WebP,
            OutputFormat::Avif => takumi::rendering::ImageOutputFormat::Avif,
            OutputFormat::Png => takumi::rendering::ImageOutputFormat::Png,
            OutputFormat::Jpeg => takumi::rendering::ImageOutputFormat::Jpeg,
            OutputFormat::Raw => unreachable!("raw format should be handled separately"),
        }
    }
}

/// Status codes for async tasks: 0 = pending, 1 = completed, 2 = error
type AsyncTaskState = (u32, Vec<u8>);
static ASYNC_TASKS: Lazy<Mutex<HashMap<u64, AsyncTaskState>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_TASK_ID: AtomicU64 = AtomicU64::new(1);

/// The inner renderer state (held behind Arc<Mutex<>> for thread-safe sharing)
pub struct RendererInner {
    global: GlobalContext,
    resources_cache: ResourceCache,
}

/// Opaque handle to a renderer (publicly just a voidptr)
pub struct Renderer;

/// Default resource cache capacity used when none is provided.
const DEFAULT_RESOURCE_CACHE_CAPACITY: u32 = 8;

const EMBEDDED_FONTS: &[(&[u8], &str, takumi::parley::GenericFamily)] = &[
    (
        include_bytes!("../../assets/fonts/geist/Geist[wght].woff2"),
        "Geist",
        GenericFamily::SansSerif,
    ),
    (
        include_bytes!("../../assets/fonts/geist/GeistMono[wght].woff2"),
        "Geist Mono",
        GenericFamily::Monospace,
    ),
];

static LAST_ERROR: Lazy<std::sync::Mutex<Option<CString>>> =
    Lazy::new(|| std::sync::Mutex::new(None));

fn set_last_error(msg: impl AsRef<str>) {
    let mut guard = LAST_ERROR.lock().unwrap();
    *guard = Some(CString::new(msg.as_ref()).unwrap_or_else(|_| CString::new("error").unwrap()));
}

fn parse_json_slice(ptr: *const c_uchar, len: usize) -> Result<serde_json::Value, String> {
    if ptr.is_null() {
        return Err("json pointer is null".to_string());
    }
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) };
    serde_json::from_slice(bytes).map_err(|e| format!("failed to parse json: {}", e))
}

fn extract_image_options(
    options: &serde_json::Value,
) -> (takumi::layout::Viewport, OutputFormat, Option<u8>, bool) {
    let viewport = takumi::layout::Viewport {
        width: options
            .get("width")
            .and_then(|v| v.as_u64())
            .map(|n| n as u32),
        height: options
            .get("height")
            .and_then(|v| v.as_u64())
            .map(|n| n as u32),
        font_size: options
            .get("font_size")
            .and_then(|v| v.as_f64())
            .unwrap_or(16.0) as f32,
        device_pixel_ratio: options
            .get("device_pixel_ratio")
            .and_then(|v| v.as_f64())
            .unwrap_or(1.0) as f32,
    };

    let format_str = options
        .get("format")
        .and_then(|v| v.as_str())
        .unwrap_or("png");
    let format = match format_str {
        "webp" => OutputFormat::WebP,
        "avif" => OutputFormat::Avif,
        "jpeg" => OutputFormat::Jpeg,
        "raw" => OutputFormat::Raw,
        _ => OutputFormat::Png,
    };

    let quality = options
        .get("quality")
        .and_then(|v| v.as_u64())
        .map(|q| (q as u8).min(100));

    let draw_debug_border = options
        .get("draw_debug_border")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    (viewport, format, quality, draw_debug_border)
}

fn extract_animation_options(
    options: &serde_json::Value,
) -> (takumi::layout::Viewport, AnimationOutputFormat, bool) {
    let viewport = takumi::layout::Viewport {
        width: options
            .get("width")
            .and_then(|v| v.as_u64())
            .map(|n| n as u32),
        height: options
            .get("height")
            .and_then(|v| v.as_u64())
            .map(|n| n as u32),
        font_size: options
            .get("font_size")
            .and_then(|v| v.as_f64())
            .unwrap_or(16.0) as f32,
        device_pixel_ratio: options
            .get("device_pixel_ratio")
            .and_then(|v| v.as_f64())
            .unwrap_or(1.0) as f32,
    };

    let format_str = options
        .get("format")
        .and_then(|v| v.as_str())
        .unwrap_or("webp");
    let format = match format_str {
        "webp" => AnimationOutputFormat::Webp,
        "apng" => AnimationOutputFormat::Apng,
        _ => AnimationOutputFormat::Webp,
    };

    let draw_debug_border = options
        .get("draw_debug_border")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    (viewport, format, draw_debug_border)
}

fn parse_frames_from_slice(
    ptr: *const c_uchar,
    len: usize,
) -> Result<Vec<(takumi::layout::node::NodeKind, u32)>, String> {
    let frames_value = parse_json_slice(ptr, len)?;
    let arr = frames_value
        .as_array()
        .ok_or_else(|| "frames must be a JSON array".to_string())?;
    if arr.is_empty() {
        return Err("frames array is empty".to_string());
    }

    let mut out = Vec::with_capacity(arr.len());
    for fv in arr {
        let node_val = fv
            .get("node")
            .ok_or_else(|| "frame missing 'node' field".to_string())?;
        let node_kind: takumi::layout::node::NodeKind = serde_json::from_value(node_val.clone())
            .map_err(|e| format!("failed to parse node in frame: {}", e))?;
        let duration_ms = fv
            .get("duration_ms")
            .and_then(|v| v.as_u64())
            .unwrap_or(100) as u32;
        out.push((node_kind, duration_ms));
    }
    Ok(out)
}

fn allocate_buffer_copy(buf: &[u8], out_len: *mut usize) -> *mut c_uchar {
    let buffer_len = buf.len();
    let out_buf = unsafe { libc::malloc(buffer_len) as *mut u8 };
    if out_buf.is_null() {
        if !out_len.is_null() {
            unsafe {
                *out_len = 0;
            }
        }
        return null_mut();
    }

    unsafe {
        std::ptr::copy_nonoverlapping(buf.as_ptr(), out_buf, buffer_len);
        if !out_len.is_null() {
            *out_len = buffer_len;
        }
    }

    out_buf as *mut c_uchar
}

/// Return a pointer to a NUL-terminated C string describing the most recent error.
///
/// ### Warning:
/// - The returned pointer is owned by Rust and remains valid until another FFI call
///   from this library updates the stored last error.
/// - The caller must not attempt to free or modify the returned pointer.
///
/// Returns:
/// - Pointer to a NUL-terminated C string containing the last error message.
/// - Returns NULL when there is no recorded error.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_last_error() -> *const c_char {
    let guard = LAST_ERROR.lock().unwrap();
    guard.as_ref().map(|c| c.as_ptr()).unwrap_or(null_mut())
}

impl RendererInner {
    fn new_with_capacity(resource_cache_capacity: u32, load_default_fonts: bool) -> Self {
        let mut global = GlobalContext::default();

        if load_default_fonts {
            for (font, name, generic) in EMBEDDED_FONTS {
                let _ = global.font_context.load_and_store(
                    font,
                    Some(takumi::parley::fontique::FontInfoOverride {
                        family_name: Some(name),
                        ..Default::default()
                    }),
                    Some(*generic),
                );
            }
        }

        let resources_cache = if resource_cache_capacity > 0 {
            Some(Arc::new(Mutex::new(LruCache::new(
                std::num::NonZeroUsize::new(resource_cache_capacity as usize).unwrap(),
            ))))
        } else {
            None
        };

        RendererInner {
            global,
            resources_cache,
        }
    }
}

/// Create a new renderer and return an opaque handle.
///
/// This allocates and initializes a `Renderer` instance with default settings
/// (including a small resource cache and embedded fonts). The returned pointer
/// is opaque and must be freed with [takumi_renderer_free] when no longer needed.
///
/// ### Warning:
/// - The returned pointer is owned by the caller and must be passed to the
///   corresponding free function ([takumi_renderer_free]) exactly once.
/// - The pointer must not be shared between processes, and must not be used
///   after being freed.
///
/// Returns:
/// - Non-null pointer to an allocated `Renderer` on success.
/// - NULL is not expected for this constructor under normal conditions.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_new() -> *mut Renderer {
    let inner = RendererInner::new_with_capacity(DEFAULT_RESOURCE_CACHE_CAPACITY, true);
    let shared = Arc::new(Mutex::new(inner));
    Box::into_raw(Box::new(shared)) as *mut Renderer
}

/// Frees a [Renderer] allocated with [takumi_renderer_new].
///
/// ### Warning:
/// - `ptr` must be a pointer returned by [takumi_renderer_new] and must not
///   have been freed already. Passing a null pointer is a no-op.
/// - After this call the pointer *__<u>must</u>__* not be used again.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_free(ptr: *mut Renderer) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let boxed = Box::from_raw(ptr as *mut SharedRenderer);
        drop(boxed);
    }
}

/// Store a persistent image in the renderer's persistent image store.
///
/// This writes a copy of [data] into the renderer's persistent image store under
/// the key specified by [src]. The image bytes are copied synchronously and the
/// function returns an integer status code to indicate success or failure.
///
/// Parameters:
/// - `ptr` must be a valid `Renderer` pointer from [takumi_renderer_new].
/// - `src` must be a valid NUL-terminated C string (UTF-8) pointing to the image key.
/// - `data` must point to `data_len` bytes of image data. If `data_len > 0`, `data` must not be NULL.
///
/// Returns:
/// - `0` on success.
/// - Non-zero error code on failure. Call [takumi_last_error] to get a human
///   readable error string when a non-zero code is returned.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_put_persistent_image(
    ptr: *mut Renderer,
    src: *const c_char,
    data: *const c_uchar,
    data_len: usize,
) -> c_int {
    if ptr.is_null() {
        set_last_error("renderer is null");
        return 1;
    }
    if src.is_null() {
        set_last_error("src is null");
        return 2;
    }

    let shared = unsafe { &*(ptr as *mut SharedRenderer) };

    let cstr = unsafe { CStr::from_ptr(src) };
    let src_str = match cstr.to_str() {
        Ok(s) => s.to_owned(),
        Err(e) => {
            set_last_error(format!("invalid src utf8: {:?}", e));
            return 3;
        }
    };

    if data.is_null() && data_len > 0 {
        set_last_error("data pointer is null");
        return 4;
    }

    let slice = unsafe { std::slice::from_raw_parts(data, data_len) };
    let data_vec = slice.to_vec();

    if let Ok(renderer) = shared.lock() {
        let mut task = crate::put_persistent_image_task::PutPersistentImageTask::new(
            src_str,
            &renderer.global.persistent_image_store,
            data_vec,
        );

        match task.compute() {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(e);
                6
            }
        }
    } else {
        set_last_error("failed to lock renderer");
        5
    }
}

/// Load a font from an in-memory buffer into the renderer's font context.
///
/// The font bytes will be copied into the renderer and registered with optional
/// metadata. This allows the renderer to use custom fonts passed from the host.
///
/// Parameters:
/// - [ptr] must be a valid [Renderer] pointer from [takumi_renderer_new].
/// - [data] must point to [data_len] bytes containing a complete font file.
///   If `data_len > 0`, [data] must not be NULL.
/// - [name] is an optional NUL-terminated C string naming the font family.
/// - [weight] and [style] provide optional overrides; negative weight or
///   `u8::MAX` for style indicate "not provided".
///
/// Returns:
/// - `0` on success.
/// - Non-zero on failure; call [takumi_last_error] for details.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_load_font(
    ptr: *mut Renderer,
    data: *const c_uchar,
    data_len: usize,
    name: *const c_char,
    weight: f64,
    style: u8,
) -> c_int {
    if ptr.is_null() {
        set_last_error("renderer is null");
        return 1;
    }

    if data.is_null() && data_len > 0 {
        set_last_error("data pointer is null");
        return 2;
    }

    let name_str = unsafe {
        if name.is_null() {
            None
        } else {
            match CStr::from_ptr(name).to_str() {
                Ok(s) => Some(s.to_owned()),
                Err(_) => {
                    set_last_error("invalid name string");
                    return 3;
                }
            }
        }
    };

    let wweight = if weight < 0.0 { None } else { Some(weight) };

    let sstyle = if style == u8::MAX { None } else { Some(style) };

    let shared = unsafe { &*(ptr as *mut SharedRenderer) };
    let slice = unsafe { std::slice::from_raw_parts(data, data_len) };

    match shared.lock() {
        Ok(mut renderer_guard) => {
            let mut task = crate::load_font_task::LoadFontTask::new(&mut renderer_guard.global);
            task.add_font(
                crate::load_font_task::FontMetadata {
                    name: name_str,
                    weight: wweight,
                    style: sstyle,
                },
                slice.to_vec(),
            );

            match task.compute() {
                Ok(_) => 0,
                Err(e) => {
                    set_last_error(e);
                    3
                }
            }
        }
        Err(e) => {
            set_last_error(format!("failed to lock renderer: {:?}", e));
            4
        }
    }
}

/// Clear all entries from the renderer's persistent image store.
///
/// ### Warning:
/// - [ptr] must be a valid [Renderer] pointer or NULL. Passing NULL is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_clear_image_store(ptr: *mut Renderer) {
    if ptr.is_null() {
        return;
    }
    let shared = unsafe { &*(ptr as *mut SharedRenderer) };
    if let Ok(renderer) = shared.lock() {
        renderer.global.persistent_image_store.clear();
    }
}

/// Purge the in-memory resource cache used by this renderer instance.
///
/// If resource caching was enabled for this renderer, this function will clear
/// any cached items (for example fetched images). It is safe to call from any
/// thread but will attempt to acquire the renderer lock.
///
/// ### Warning:
/// - [ptr] must be a valid [Renderer] pointer or NULL. Passing NULL is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_purge_resource_cache(ptr: *mut Renderer) {
    if ptr.is_null() {
        return;
    }
    let shared = unsafe { &*(ptr as *mut SharedRenderer) };
    if let Ok(renderer) = shared.lock() {
        if let Some(cache) = renderer.resources_cache.as_ref() {
            if let Ok(mut lock) = cache.lock() {
                lock.clear();
            }
        }
    }
}

/// Synchronously render an image described by JSON and return a malloc'd buffer.
///
/// The function blocks until rendering finishes. The rendered bytes are copied
/// into a newly allocated buffer using [libc::malloc]. The caller is responsible
/// for freeing the returned buffer by calling [takumi_free_buffer].
///
/// Parameters:
/// - [ptr] must be a valid `Renderer` pointer.
/// - [node_json] must point to [node_len] bytes containing a JSON object that
///   describes the root layout node. The JSON is parsed by the renderer.
/// - [options_json] must point to [options_len] bytes containing a JSON object
///   with rendering options (width, height, format, etc.).
/// - [out_len] is an out-pointer that will be written with the length of the
///   returned buffer on success, or 0 on error.
///
/// Returns:
/// - Pointer to a malloc'd buffer with image bytes on success (caller must free).
/// - NULL on error. Use [takumi_last_error] to obtain a description of the error.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_render_sync(
    ptr: *mut Renderer,
    node_json: *const c_uchar,
    node_len: usize,
    options_json: *const c_uchar,
    options_len: usize,
    out_len: *mut usize,
) -> *mut c_uchar {
    if ptr.is_null() {
        set_last_error("renderer is null");
        if !out_len.is_null() {
            unsafe {
                *out_len = 0;
            }
        }
        return null_mut();
    }

    let inner = match unsafe { &*(ptr as *mut SharedRenderer) }.lock() {
        Ok(guard) => guard,
        Err(e) => {
            set_last_error(format!("failed to lock renderer: {:?}", e));
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let node_bytes = unsafe { std::slice::from_raw_parts(node_json, node_len) };
    let node_kind = match crate::render_task::parse_node_from_json(node_bytes) {
        Ok(n) => n,
        Err(e) => {
            set_last_error(format!("failed to parse node JSON: {}", e));
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let options = match parse_json_slice(options_json, options_len) {
        Ok(v) => v,
        Err(e) => {
            set_last_error(e);
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let (viewport, format, quality, draw_debug_border) = extract_image_options(&options);

    let mut render_task = crate::render_task::RenderTask::new(
        node_kind,
        &inner.global,
        viewport,
        format,
        quality,
        draw_debug_border,
    );
    let buffer_result = render_task.compute();

    let buffer = match buffer_result {
        Ok(buf) => buf,
        Err(e) => {
            set_last_error(e);
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    allocate_buffer_copy(&buffer, out_len)
}

/// Start an asynchronous render task and return a numeric task handle.
///
/// The render is performed on a background thread. The returned task handle
/// can be polled with [takumi_poll_render_task] to check completion and obtain
/// the rendered bytes. The renderer stores an internal task map until the
/// caller polls and retrieves the result or frees the task via
/// [takumi_free_render_task].
///
/// Safety & Parameters:
/// - [ptr] must be a valid [Renderer] pointer.
/// - [node_json]/[node_len] and [options_json]/[options_len] are pointers to
///   JSON buffers described above for the synchronous API.
///
/// Returns:
/// - A non-zero u64 task handle on success.
/// - `0` on error. Use [takumi_last_error] for a human-readable error message.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_renderer_render(
    ptr: *mut Renderer,
    node_json: *const c_uchar,
    node_len: usize,
    options_json: *const c_uchar,
    options_len: usize,
) -> u64 {
    if ptr.is_null() {
        set_last_error("renderer is null");
        return 0;
    }

    let node_bytes = unsafe { std::slice::from_raw_parts(node_json, node_len) };
    let node_kind = match crate::render_task::parse_node_from_json(node_bytes) {
        Ok(n) => n,
        Err(e) => {
            set_last_error(format!("failed to parse node JSON: {}", e));
            return 0;
        }
    };

    let options = match parse_json_slice(options_json, options_len) {
        Ok(v) => v,
        Err(e) => {
            set_last_error(e);
            return 0;
        }
    };

    let (viewport, format, quality, draw_debug_border) = extract_image_options(&options);

    let task_id: u64 = NEXT_TASK_ID.fetch_add(1, Ordering::SeqCst);

    if let Ok(mut tasks) = ASYNC_TASKS.lock() {
        tasks.insert(task_id, (0u32, Vec::new())); // Status 0 = pending
    } else {
        set_last_error("failed to lock tasks map");
        return 0;
    }

    let renderer_shared = unsafe { (*(ptr as *mut SharedRenderer)).clone() };

    std::thread::spawn(move || {
        if let Ok(inner) = renderer_shared.lock() {
            let mut render_task = crate::render_task::RenderTask::new(
                node_kind,
                &inner.global,
                viewport,
                format,
                quality,
                draw_debug_border,
            );

            if let Some(ref cache) = inner.resources_cache {
                if let Ok(cache_guard) = cache.lock() {
                    for (fetch_task, image_source) in cache_guard.iter() {
                        let key_str = format!("{:?}", fetch_task);
                        render_task.add_fetched_resource(key_str, (**image_source).clone());
                    }
                }
            }

            let buffer_result = render_task.compute();

            let (status, buffer) = match buffer_result {
                Ok(buf) => (1u32, buf),
                Err(e) => {
                    set_last_error(e);
                    (2u32, Vec::new())
                }
            };

            if let Ok(mut tasks) = ASYNC_TASKS.lock() {
                tasks.insert(task_id, (status, buffer));
            }
        } else {
            if let Ok(mut tasks) = ASYNC_TASKS.lock() {
                tasks.insert(task_id, (2u32, Vec::new()));
            }
        }
    });

    task_id
}

/// Poll an asynchronous render task and optionally retrieve its result buffer.
///
/// This checks the internal task map for [task_id]. If the task has completed
/// successfully, it returns a newly allocated buffer containing the rendered
/// bytes and removes the task from the map. If the task is still pending,
/// returns NULL and sets `out_status` to 0. On error, returns NULL and sets
/// [out_status] to 2.
///
/// Parameters:
/// - [task_id] must be a handle previously returned by `takumi_renderer_render`.
/// - [out_len] will receive the buffer length (0 for pending/error).
/// - [out_status] will receive the status code: 0=pending, 1=complete, 2=error.
///
/// Returns:
/// - Pointer to a malloc'd buffer with the result when status == 1 (caller frees it).
/// - NULL if the task is pending, errored, or not found.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_poll_render_task(
    task_id: u64,
    out_len: *mut usize,
    out_status: *mut c_int,
) -> *mut c_uchar {
    let mut tasks = match ASYNC_TASKS.lock() {
        Ok(t) => t,
        Err(_) => {
            if !out_status.is_null() {
                unsafe {
                    *out_status = 2; // error
                }
            }
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    match tasks.get(&task_id) {
        Some((status, buffer)) => {
            if !out_status.is_null() {
                unsafe {
                    *out_status = *status as c_int;
                }
            }

            if *status == 1 {
                let buffer_len = buffer.len();
                let out_buf = unsafe { libc::malloc(buffer_len) as *mut u8 };

                if out_buf.is_null() {
                    if !out_len.is_null() {
                        unsafe {
                            *out_len = 0;
                        }
                    }
                    return null_mut();
                }

                let result = allocate_buffer_copy(&buffer, out_len);

                tasks.remove(&task_id);

                result
            } else {
                if !out_len.is_null() {
                    unsafe {
                        *out_len = 0;
                    }
                }
                null_mut()
            }
        }
        None => {
            if !out_status.is_null() {
                unsafe {
                    *out_status = 2;
                }
            }
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            null_mut()
        }
    }
}

/// Free and drop any state associated with an asynchronous render task.
///
/// This will remove the task entry from the internal task map if present and
/// free any associated buffers. This function is idempotent: calling it for a
/// missing or already-cleared task is a no-op.
///
/// Parameters:
/// - [task_id]: handle previously returned by [takumi_renderer_render].
#[unsafe(no_mangle)]
pub extern "C" fn takumi_free_render_task(task_id: u64) {
    if let Ok(mut tasks) = ASYNC_TASKS.lock() {
        tasks.remove(&task_id);
    }
}

/// Synchronously render an animation (multiple frames) described by JSON.
///
/// The frames JSON must be an array of objects containing a `node` (the node
/// description) and an optional `duration_ms`. The function renders all frames
/// and encodes them into the specified animation format (e.g. WebP/APNG). The
/// resulting bytes are returned in a malloc'd buffer which the caller must free
/// with [takumi_free_buffer].
///
/// Safety & Parameters:
/// - [ptr] must be a valid [Renderer] pointer.
/// - [frames_json]/[frames_len] must point to a JSON array of frames.
/// - [options_json]/[options_len] provide animation options (format, size, etc.).
/// - [out_len] receives the length of the returned buffer on success, or 0 on error.
///
/// Returns:
/// - Pointer to a malloc'd buffer with encoded animation bytes on success.
/// - NULL on error. Use [takumi_last_error] for details.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_render_animation_sync(
    ptr: *mut Renderer,
    frames_json: *const c_uchar,
    frames_len: usize,
    options_json: *const c_uchar,
    options_len: usize,
    out_len: *mut usize,
) -> *mut c_uchar {
    if ptr.is_null() {
        set_last_error("renderer is null");
        if !out_len.is_null() {
            unsafe {
                *out_len = 0;
            }
        }
        return null_mut();
    }

    let inner = match unsafe { &*(ptr as *mut SharedRenderer) }.lock() {
        Ok(guard) => guard,
        Err(e) => {
            set_last_error(format!("failed to lock renderer: {:?}", e));
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let parsed_frames = match parse_frames_from_slice(frames_json, frames_len) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(e);
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let options = match parse_json_slice(options_json, options_len) {
        Ok(v) => v,
        Err(e) => {
            set_last_error(e);
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    let (viewport, format, draw_debug_border) = extract_animation_options(&options);

    let mut render_animation_task = crate::render_animation_task::RenderAnimationTask::new(
        parsed_frames,
        &inner.global,
        viewport,
        format,
        draw_debug_border,
    );

    let buffer = match render_animation_task.compute() {
        Ok(buf) => buf,
        Err(e) => {
            set_last_error(format!("failed to render animation: {:#?}", e));
            if !out_len.is_null() {
                unsafe {
                    *out_len = 0;
                }
            }
            return null_mut();
        }
    };

    allocate_buffer_copy(&buffer, out_len)
}

/// Start an asynchronous animation render and return a numeric task handle.
///
/// Works similarly to [takumi_renderer_render] but accepts an array of frames
/// to compose an animation. The returned task id can be polled with
/// [takumi_poll_render_task] to obtain the encoded animation bytes.
///
/// Parameters:
/// - [ptr] must be a valid [Renderer] pointer.
/// - [frames_json]/[frames_len] and [options_json]/[options_len] are pointers to
///   JSON buffers describing frames and animation options.
///
/// Returns:
/// - A non-zero u64 task handle on success.
/// - `0` on error. Use [takumi_last_error] for a description of the failure.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_render_animation(
    ptr: *mut Renderer,
    frames_json: *const c_uchar,
    frames_len: usize,
    options_json: *const c_uchar,
    options_len: usize,
) -> u64 {
    if ptr.is_null() {
        set_last_error("renderer is null");
        return 0;
    }

    let parsed_frames = match parse_frames_from_slice(frames_json, frames_len) {
        Ok(f) => f,
        Err(e) => {
            set_last_error(e);
            return 0;
        }
    };

    let options = match parse_json_slice(options_json, options_len) {
        Ok(v) => v,
        Err(e) => {
            set_last_error(e);
            return 0;
        }
    };

    let (viewport, format, draw_debug_border) = extract_animation_options(&options);

    let task_id = NEXT_TASK_ID.fetch_add(1, Ordering::SeqCst);

    if let Ok(mut tasks) = ASYNC_TASKS.lock() {
        tasks.insert(task_id, (0u32, Vec::new())); // Status 0 = pending
    } else {
        set_last_error("failed to lock tasks map");
        return 0;
    }

    let renderer_shared = unsafe { (*(ptr as *mut SharedRenderer)).clone() };

    std::thread::spawn(move || {
        if let Ok(inner) = renderer_shared.lock() {
            let mut animation_task = crate::render_animation_task::RenderAnimationTask::new(
                parsed_frames,
                &inner.global,
                viewport,
                format,
                draw_debug_border,
            );

            let buffer_result = animation_task.compute();

            let (status, buffer) = match buffer_result {
                Ok(buf) => (1u32, buf),
                Err(e) => {
                    set_last_error(format!("Failed to render animation: {:?}", e));
                    (2u32, Vec::new())
                }
            };

            if let Ok(mut tasks) = ASYNC_TASKS.lock() {
                tasks.insert(task_id, (status, buffer));
            }
        } else {
            if let Ok(mut tasks) = ASYNC_TASKS.lock() {
                tasks.insert(task_id, (2u32, Vec::new())); // Status 2 = error
            }
        }
    });

    task_id
}

/// Free a buffer that was allocated by this crate (via [libc::malloc]).
///
/// Parameters:
/// - [buf] must be a pointer previously returned by one of this crate's
///   functions (for example [takumi_renderer_render_sync], [takumi_poll_render_task],
///   or animation renderers) and allocated with [libc::malloc].
/// - Passing a NULL pointer is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn takumi_free_buffer(buf: *mut c_void) {
    if buf.is_null() {
        return;
    }
    unsafe {
        libc::free(buf);
    }
}
