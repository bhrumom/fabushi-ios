use mahayana_app_host::{AppHostFeatureMode, HostResponse, default_app_data_dir};
use mahayana_unified_app_host::{UnifiedAppHost, dispatch_json};
use std::ffi::{CStr, CString, c_char};
use std::path::PathBuf;

#[path = "../../../../internal/host-extensions.rs"]
mod host_extensions;
#[path = "../../../../internal/scheduling.rs"]
mod scheduling;

#[path = "../../../../host/process-crash-guard.rs"]
mod process_crash_guard;
#[path = "../../../../host/notify-drain-gate.rs"]
mod notify_drain_gate;
#[path = "../../../../host/mcp-auth/mcp-auth-wait-registry.rs"]
mod mcp_auth_wait_registry;
#[path = "../../../../host/box/box-env.rs"]
mod box_env;
#[path = "../../../../host/box/box-capabilities.rs"]
mod box_capabilities;
#[path = "../../../../host/box/box-shell-command.rs"]
mod box_shell_command;
#[path = "../../../../host/host-request-context.rs"]
mod host_request_context;
#[path = "../../../../host/agent-isolation/conversation-blob-db.rs"]
mod conversation_blob_db;
#[path = "../../../../host/agent-isolation/conversation-blob-gc.rs"]
mod conversation_blob_gc;
#[path = "../../../../host/agent-isolation/legacy-blob-retirement.rs"]
mod legacy_blob_retirement;
#[path = "../../../../host/agent-isolation/conversation-blob-store.rs"]
mod conversation_blob_store;
#[path = "../../../../host/agent-isolation/agent-store-worker.rs"]
mod agent_store_worker;
#[path = "../../../../host/agent-isolation/agent-worker-pool.rs"]
mod agent_worker_pool;
#[path = "../../../../host/agent-isolation/worker-blob-store.rs"]
mod worker_blob_store;
#[path = "../../../../host/box/box-monitor-layout.rs"]
mod box_monitor_layout;
#[path = "../../../../host/box/box-store-backend-policy.rs"]
mod box_store_backend_policy;
#[path = "../../../../host/box/protected-path-guard.rs"]
mod protected_path_guard;
#[path = "../../../../host/box/box-mcp.rs"]
mod box_mcp;
#[path = "../../../../host/box/box-factory.rs"]
mod box_factory;
#[path = "../../../../host/box/box-windows.rs"]
mod box_windows;
#[path = "../../../../host/box/box-file-transfer.rs"]
mod box_file_transfer;
#[path = "../../../../host/box/box-transfer.rs"]
mod box_transfer;
#[path = "../../../../host/box/exec-daemon-process.rs"]
mod exec_daemon_process;
#[path = "../../../../host/box/box-remote-accessor.rs"]
mod box_remote_accessor;
#[path = "../../../../host/box/generated-production.rs"]
mod generated_production;
#[path = "../../../../host/box/loopback-sand-box.rs"]
mod loopback_sand_box;
#[path = "../../../../host/box/shared-desktop-sand-box.rs"]
mod shared_desktop_sand_box;
#[path = "../../../../host/box/production.rs"]
mod production;


#[path = "../../../../host/extensions/local-exec/local-exec-error.rs"]
mod local_exec_error;
#[path = "../../../../host/extensions/cloud-agents/cloud-agent-launch-error.rs"]
mod cloud_agent_launch_error;
#[path = "../../../../host/runner/tools/tool-input-error.rs"]
mod tool_input_error;
#[path = "../../../../host/runner/sand-prompt-markers.rs"]
mod sand_prompt_markers;
#[path = "../../../../host/extensions/box-store-sync/box-store-sync-error.rs"]
mod box_store_sync_error;
#[path = "../../../../host/sha256.rs"]
mod sha256;
#[path = "../../../../host/storage/folder-id.rs"]
mod folder_id;
#[path = "../../../../host/extensions/transcript/channel-delivery-unregistered-error.rs"]
mod channel_delivery_unregistered_error;
#[path = "../../../../host/extensions/transcript/send-not-persisted-error.rs"]
mod send_not_persisted_error;
#[path = "../../../../host/runner/agent-state.rs"]
mod agent_state;
#[path = "../../../../host/extensions/session/conversation-blobs-path.rs"]
mod conversation_blobs_path;
#[path = "../../../../host/automations/automation-id.rs"]
mod automation_id;
#[path = "../../../../host/attachment-paths.rs"]
mod attachment_paths;
#[path = "../../../../host/durable-file-policy.rs"]
mod durable_file_policy;


#[path = "../../../../host/ports/product-analytics.rs"]
mod product_analytics;
#[path = "../../../../host/ports/sand-analytics-types.rs"]
mod sand_analytics_types;
#[path = "../../../../host/host-diagnostics.rs"]
mod host_diagnostics;
#[path = "../../../../host/extensions/session/session-diagnostics.rs"]
mod session_diagnostics;
#[path = "../../../../host/transcript-mutation-events.rs"]
mod transcript_mutation_events;
#[path = "../../../../host/ports/user-computer.rs"]
mod user_computer;
#[path = "../../../../host/ports/transport.rs"]
mod transport;
#[path = "../../../../host/sand-user-identity.rs"]
mod sand_user_identity;
#[path = "../../../../host/runner/clock-skew-guard.rs"]
mod clock_skew_guard;
#[path = "../../../../host/selected-image-inputs.rs"]
mod selected_image_inputs;
#[path = "../../../../host/extensions/extension-ids.generated.rs"]
mod extension_ids_generated;
#[path = "../../../../host/runner/video-container.rs"]
mod video_container;
#[path = "../../../../host/extensions/telemetry/send-trace-sampler.rs"]
mod send_trace_sampler;

fn host_fault_response(fault: process_crash_guard::HostFault) -> String {
    serde_json::to_string(&HostResponse {
        id: None,
        ok: false,
        result: None,
        error: Some(format!("host_fault[{}]: {}", fault.scope, fault.message)),
    })
    .unwrap_or_else(|_| "{\"ok\":false,\"error\":\"host fault\"}".to_owned())
}

/// Creates a native app-host handle.
///
/// # Safety
/// If `app_data_dir` is non-null, it must point to a valid NUL-terminated C string
/// for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_create(
    app_data_dir: *const c_char,
) -> *mut UnifiedAppHost {
    let path = if app_data_dir.is_null() {
        default_app_data_dir()
    } else {
        PathBuf::from(
            unsafe { CStr::from_ptr(app_data_dir) }
                .to_string_lossy()
                .into_owned(),
        )
    };
    match UnifiedAppHost::new(path) {
        Ok(host) => Box::into_raw(Box::new(host)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Creates a production native app-host with a stable storage passphrase supplied
/// by the platform Keychain/Keystore bridge. The passphrase is consumed in memory
/// and never written to the Rust app-data directory.
///
/// # Safety
/// Both pointers must reference valid NUL-terminated strings for this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_create_with_storage_passphrase(
    app_data_dir: *const c_char,
    storage_passphrase: *const c_char,
) -> *mut UnifiedAppHost {
    if storage_passphrase.is_null() {
        return std::ptr::null_mut();
    }
    let path = if app_data_dir.is_null() {
        default_app_data_dir()
    } else {
        PathBuf::from(
            unsafe { CStr::from_ptr(app_data_dir) }
                .to_string_lossy()
                .into_owned(),
        )
    };
    let passphrase = unsafe { CStr::from_ptr(storage_passphrase) }
        .to_string_lossy()
        .into_owned();
    if passphrase.is_empty() {
        return std::ptr::null_mut();
    }
    match UnifiedAppHost::new_with_feature_mode_and_storage_passphrase(
        path,
        AppHostFeatureMode::Production,
        passphrase,
    ) {
        Ok(host) => Box::into_raw(Box::new(host)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Creates a native app-host handle backed by the deterministic FeatureHost test mode.
/// This is used only by explicit UI/instrumentation test harnesses; normal app
/// creation continues to use the production mode.
///
/// # Safety
/// `app_data_dir` must follow the same contract as `mahayana_app_host_create`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_create_test(
    app_data_dir: *const c_char,
) -> *mut UnifiedAppHost {
    let path = if app_data_dir.is_null() {
        default_app_data_dir()
    } else {
        PathBuf::from(
            unsafe { CStr::from_ptr(app_data_dir) }
                .to_string_lossy()
                .into_owned(),
        )
    };
    match UnifiedAppHost::new_with_feature_mode(path, AppHostFeatureMode::Test) {
        Ok(host) => Box::into_raw(Box::new(host)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Dispatches one JSON request through an existing native app-host handle.
///
/// # Safety
/// `host` must be a live pointer returned by `mahayana_app_host_create`, and
/// `request_json` must point to a valid NUL-terminated C string for this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_dispatch_with_handle(
    host: *mut UnifiedAppHost,
    request_json: *const c_char,
) -> *mut c_char {
    if host.is_null() || request_json.is_null() {
        return CString::new("{\"ok\":false,\"error\":\"null host or request\"}")
            .unwrap()
            .into_raw();
    }
    let input = unsafe { CStr::from_ptr(request_json) }.to_string_lossy();
    let host_ref = unsafe { &*host };
    let output = match process_crash_guard::catch_host_fault("mahayana-app-host", || {
        dispatch_json(host_ref, &input)
    }) {
        Ok(output) => output,
        Err(fault) => host_fault_response(fault),
    };
    CString::new(output)
        .unwrap_or_else(|_| CString::new("{\"ok\":false,\"error\":\"invalid response\"}").unwrap())
        .into_raw()
}

/// Destroys a native app-host handle.
///
/// # Safety
/// `host` must be null or a live pointer returned by `mahayana_app_host_create`
/// that has not previously been destroyed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_destroy(host: *mut UnifiedAppHost) {
    if !host.is_null() {
        unsafe {
            drop(Box::from_raw(host));
        }
    }
}

/// Dispatches one JSON request using a temporary default app-host.
///
/// # Safety
/// `request_json` must point to a valid NUL-terminated C string for this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_dispatch(request_json: *const c_char) -> *mut c_char {
    if request_json.is_null() {
        return CString::new("{\"ok\":false,\"error\":\"null request\"}")
            .unwrap()
            .into_raw();
    }
    let input = unsafe { CStr::from_ptr(request_json) }.to_string_lossy();
    let output = match UnifiedAppHost::new(default_app_data_dir()) {
        Ok(host) => match process_crash_guard::catch_host_fault("mahayana-app-host-temporary", || {
            dispatch_json(&host, &input)
        }) {
            Ok(output) => output,
            Err(fault) => host_fault_response(fault),
        },
        Err(error) => serde_json::to_string(&HostResponse {
            id: None,
            ok: false,
            result: None,
            error: Some(error.to_string()),
        })
        .unwrap(),
    };
    CString::new(output)
        .unwrap_or_else(|_| CString::new("{\"ok\":false,\"error\":\"invalid response\"}").unwrap())
        .into_raw()
}

/// Frees a response string returned by this FFI module.
///
/// # Safety
/// `pointer` must be null or a pointer returned by a Mahayana app-host dispatch
/// function that has not previously been freed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mahayana_app_host_free_string(pointer: *mut c_char) {
    if !pointer.is_null() {
        unsafe {
            drop(CString::from_raw(pointer));
        }
    }
}

#[cfg(target_os = "android")]
mod android_jni {
    use super::*;
    use jni::JNIEnv;
    use jni::objects::{JObject, JString};
    use jni::sys::{jlong, jstring};

    #[unsafe(no_mangle)]
    pub extern "system" fn Java_com_ombhrum_fabushi_core_MahayanaHost_nativeCreate(
        mut env: JNIEnv,
        _object: JObject,
        app_data_dir: JString,
        storage_passphrase: JString,
    ) -> jlong {
        let path = match env.get_string(&app_data_dir) {
            Ok(value) => PathBuf::from(value.to_string_lossy().into_owned()),
            Err(_) => return 0,
        };
        let passphrase = match env.get_string(&storage_passphrase) {
            Ok(value) => value.to_string_lossy().into_owned(),
            Err(_) => return 0,
        };
        if passphrase.is_empty() {
            return 0;
        }
        match UnifiedAppHost::new_with_feature_mode_and_storage_passphrase(
            path,
            AppHostFeatureMode::Production,
            passphrase,
        ) {
            Ok(host) => Box::into_raw(Box::new(host)) as jlong,
            Err(_) => 0,
        }
    }

    #[unsafe(no_mangle)]
    pub extern "system" fn Java_com_ombhrum_fabushi_core_MahayanaHost_nativeCreateTest(
        mut env: JNIEnv,
        _object: JObject,
        app_data_dir: JString,
    ) -> jlong {
        let path = match env.get_string(&app_data_dir) {
            Ok(value) => PathBuf::from(value.to_string_lossy().into_owned()),
            Err(_) => return 0,
        };
        match UnifiedAppHost::new_with_feature_mode(path, AppHostFeatureMode::Test) {
            Ok(host) => Box::into_raw(Box::new(host)) as jlong,
            Err(_) => 0,
        }
    }

    #[unsafe(no_mangle)]
    pub extern "system" fn Java_com_ombhrum_fabushi_core_MahayanaHost_nativeDispatch(
        mut env: JNIEnv,
        _object: JObject,
        handle: jlong,
        request_json: JString,
    ) -> jstring {
        if handle == 0 {
            return env
                .new_string("{\"ok\":false,\"error\":\"native host is not initialized\"}")
                .map(|value| value.into_raw())
                .unwrap_or(std::ptr::null_mut());
        }
        let input = match env.get_string(&request_json) {
            Ok(value) => value.to_string_lossy().into_owned(),
            Err(error) => format!("{{\"ok\":false,\"error\":\"invalid request: {error}\"}}"),
        };
        let host = unsafe { &*(handle as *mut UnifiedAppHost) };
        env.new_string(dispatch_json(host, &input))
            .map(|value| value.into_raw())
            .unwrap_or(std::ptr::null_mut())
    }

    #[unsafe(no_mangle)]
    pub extern "system" fn Java_com_ombhrum_fabushi_core_MahayanaHost_nativeDestroy(
        _env: JNIEnv,
        _object: JObject,
        handle: jlong,
    ) {
        if handle != 0 {
            unsafe {
                drop(Box::from_raw(handle as *mut UnifiedAppHost));
            }
        }
    }
}
