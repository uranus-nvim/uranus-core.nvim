//! Uranus - A Neovim plugin with a Rust backend for Jupyter kernel
//! communication.
//!
//! This crate provides a Neovim plugin with a Rust backend for communicating
//! with Jupyter kernels. It supports both local kernels (via ZeroMQ using
//! runtimelib) and remote kernels (via Jupyter Server WebSocket).
//!
//! # Architecture
//!
//! - **Local kernels**: Connect via ZeroMQ using [`runtimelib`] and
//!   [`jupyter_protocol`]
//! - **Remote kernels**: Connect via WebSocket using
//!   [`jupyter_websocket_client`]
//! - **Neovim integration**: Uses [`nvim_oxi`] for plugin API
//! - **Notebook support**: Parses .ipynb files using [`nbformat`]
//!
//! # Usage
//!
//! ```lua
//! local uranus = require("uranus")
//! uranus.start_backend()
//! uranus.list_kernels()  -- Returns available kernels
//! uranus.connect_kernel("python3")
//! uranus.execute("print('Hello, World!')")
//! ```
//!
//! [`runtimelib`]: https://docs.rs/runtimelib/1.5.0
//! [`jupyter_protocol`]: https://docs.rs/jupyter-protocol/1.4.0
//! [`jupyter_websocket_client`]: https://docs.rs/jupyter-websocket-client/1.1.0
//! [`nvim_oxi`]: https://docs.rs/nvim-oxi/0.6.0
//! [`nbformat`]: https://docs.rs/nbformat/1.2.2

// ============================================================================
// Module Declarations
// ============================================================================

// Error handling module
mod error;

// Kernel management modules
mod kernel;
mod kernel_pool;
mod remote;

// Protocol and Messaging modules
mod messages;
mod notebook;
mod protocol;

// Runtime and execution modules
mod async_bridge;
mod connection;
mod execute;
mod parallel;
mod runtime;

// ============================================================================
// Re-exports for Public API
// ============================================================================
use std::{collections::HashMap, sync::Arc};

pub use error::{ErrorCode, ErrorResponse, UranusError};
pub use kernel::KernelHandle;
pub use kernel_pool::{KernelPool, PoolStats, PooledKernel};
pub use messages::{JupyterMessage, MessageBuffer, ZeroCopyParser};
pub use notebook::{Notebook, NotebookCell};
use once_cell::sync::Lazy;
pub use parallel::{run_parallel, run_sequential, ParallelExecutor};
use parking_lot::RwLock;
pub use remote::RemoteKernelHandle;
pub use runtime::{init_global_runtime, RuntimeStatus};
use serde::{Deserialize, Serialize};
use tracing::{error, info, warn};

/// Global plugin state managed via Lazy to ensure initialization order.
static STATE: Lazy<RwLock<UranusState>> = Lazy::new(|| RwLock::new(UranusState::default()));

/// Result type for all public API functions.
///
/// This is the primary return type for all plugin commands exposed to Neovim.
/// It provides a consistent JSON-serializable structure with success/error
/// status.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[must_use]
pub struct UranusResult {
    /// Whether the operation succeeded.
    pub success: bool,
    /// Result data if successful.
    pub data: Option<serde_json::Value>,
    /// Error information if failed.
    pub error: Option<serde_json::Value>,
}

impl UranusResult {
    /// Creates a successful result with data.
    #[inline]
    pub fn ok(data: impl Into<serde_json::Value>) -> Self {
        Self {
            success: true,
            data: Some(data.into()),
            error: None,
        }
    }

    /// Creates an error result with code and message.
    #[inline]
    pub fn err(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(serde_json::json!({
                "code": code.into(),
                "message": message.into()
            })),
        }
    }

    /// Returns `true` if the result is successful.
    #[inline]
    pub fn is_ok(&self) -> bool {
        self.success
    }

    /// Returns `true` if the result is an error.
    #[inline]
    pub fn is_err(&self) -> bool {
        !self.success
    }
}

/// Kernel information returned from discovery.
///
/// Contains basic metadata about a discovered kernel.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KernelInfo {
    /// Kernel name (e.g., "python3").
    pub name: String,
    /// Programming language (e.g., "python").
    pub language: String,
    /// Current status (e.g., "available", "remote").
    pub status: String,
}

/// Result of code execution from a kernel.
///
/// Contains all output from executing code in a Jupyter kernel.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ExecutionResult {
    /// Execution count (incrementing counter).
    pub execution_count: i32,
    /// Standard output text.
    pub stdout: Option<String>,
    /// Standard error text.
    pub stderr: Option<String>,
    /// Rich output data keyed by MIME type (text/plain, image/png, etc.).
    pub data: HashMap<String, String>,
    /// Error message if execution failed.
    pub error: Option<String>,
}

/// Result of variable inspection.
///
/// Contains type and value information for an inspected variable.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct InspectResult {
    /// Whether the variable was found.
    pub found: bool,
    /// Variable name.
    pub name: String,
    /// Type name as string.
    pub type_name: String,
    /// String representation of value.
    pub value: Option<String>,
    /// Docstring if available.
    pub docstring: Option<String>,
}

/// Kernel trait defining the interface for all kernel implementations.
///
/// This trait must be implemented by both local and remote kernel handles
/// to provide a unified interface for kernel operations.
pub trait KernelTrait: Send + Sync {
    /// Executes code in the kernel.
    ///
    /// # Errors
    ///
    /// Returns an error if execution fails.
    fn execute(&self, code: &str) -> Result<ExecutionResult, UranusError>;

    /// Interrupts kernel execution.
    ///
    /// # Errors
    ///
    /// Returns an error if interruption fails.
    fn interrupt(&self) -> Result<(), UranusError>;

    /// Shuts down the kernel.
    ///
    /// # Errors
    ///
    /// Returns an error if shutdown fails.
    fn shutdown(&self) -> Result<(), UranusError>;

    /// Inspects a variable at the given cursor position.
    ///
    /// # Errors
    ///
    /// Returns an error if inspection fails.
    fn inspect(&self, code: &str, cursor_pos: usize) -> Result<InspectResult, UranusError>;

    /// Returns the kernel type ("local" or "remote").
    fn kernel_type(&self) -> &str;
}

/// Internal plugin state.
#[derive(Default)]
struct UranusState {
    /// Whether the backend is running.
    backend_running: bool,
    /// Connected kernels indexed by name.
    kernels: HashMap<String, Arc<dyn KernelTrait>>,
    /// Current active kernel name.
    current_kernel: Option<String>,
    /// Whether configuration is valid.
    config_valid: bool,
}

// ============================================================================
// Public API Functions
// ============================================================================

/// Starts the Uranus backend.
///
/// Initializes the global Tokio runtime and sets up the plugin state.
pub fn start_backend() -> UranusResult {
    info!("Starting Uranus backend");
    let _ = init_global_runtime();
    let mut state = STATE.write();
    state.backend_running = true;
    UranusResult::ok(serde_json::json!({ "status": "started" }))
}

/// Stops the Uranus backend.
///
/// Shuts down all connected kernels and cleans up the plugin state.
pub fn stop_backend() -> UranusResult {
    info!("Stopping Uranus backend");
    let mut state = STATE.write();
    state.backend_running = false;
    state.kernels.clear();
    state.current_kernel = None;
    UranusResult::ok(serde_json::json!({ "status": "stopped" }))
}

/// Returns the current backend status.
pub fn status() -> UranusResult {
    let state = STATE.read();
    UranusResult::ok(serde_json::json!({
        "version": env!("CARGO_PKG_VERSION"),
        "backend_running": state.backend_running,
        "current_kernel": state.current_kernel,
        "config_valid": state.config_valid,
    }))
}

/// Lists all available local kernels.
pub fn list_kernels() -> UranusResult {
    match kernel::discover_local_kernels_sync() {
        Ok(kernels) => UranusResult::ok(serde_json::json!({ "kernels": kernels })),
        Err(e) => UranusResult::err("LIST_KERNELS_FAILED", e.to_string()),
    }
}

/// Connects to a local kernel by name.
pub fn connect_kernel(kernel_name: &str) -> UranusResult {
    let kernel = match kernel::connect_kernel(kernel_name) {
        Ok(k) => Arc::new(k) as Arc<dyn KernelTrait>,
        Err(e) => {
            error!("Failed to connect to kernel {}: {}", kernel_name, e);
            return UranusResult::err("KERNEL_CONNECT_FAILED", e.to_string());
        }
    };
    let mut state = STATE.write();
    state.kernels.insert(kernel_name.to_string(), kernel);
    state.current_kernel = Some(kernel_name.to_string());
    info!("Connected to kernel: {}", kernel_name);
    UranusResult::ok(serde_json::json!({ "kernel": kernel_name }))
}

/// Disconnects from the current kernel.
pub fn disconnect_kernel() -> UranusResult {
    let mut state = STATE.write();
    if let Some(name) = state.current_kernel.take() {
        if let Some(kernel) = state.kernels.remove(&name) {
            if let Err(e) = kernel.shutdown() {
                warn!("Failed to shutdown kernel: {}", e);
            }
        }
        info!("Disconnected from kernel: {}", name);
        UranusResult::ok(serde_json::json!({ "status": "disconnected" }))
    } else {
        UranusResult::err("NO_KERNEL", "No kernel connected")
    }
}

/// Executes code in the current kernel.
pub fn execute(code: &str) -> UranusResult {
    let mut state = STATE.write();
    let kernel_name = match &state.current_kernel {
        Some(k) => k.clone(),
        None => return UranusResult::err("NO_KERNEL", "No kernel connected"),
    };
    let kernel = match state.kernels.get_mut(&kernel_name) {
        Some(k) => k,
        None => return UranusResult::err("KERNEL_NOT_FOUND", "Kernel not found"),
    };
    match kernel.execute(code) {
        Ok(result) => UranusResult::ok(serde_json::to_value(result).unwrap()),
        Err(e) => UranusResult::err("EXECUTION_FAILED", e.to_string()),
    }
}

/// Interrupts the current kernel execution.
pub fn interrupt() -> UranusResult {
    let state = STATE.read();
    if let Some(kernel) = state
        .kernels
        .get(state.current_kernel.as_ref().unwrap_or(&String::new()))
    {
        if let Err(e) = kernel.interrupt() {
            return UranusResult::err("INTERRUPT_FAILED", e.to_string());
        }
    }
    UranusResult::ok(serde_json::json!({ "status": "interrupted" }))
}

/// Inspects a variable in the current kernel.
pub fn inspect(code: &str, cursor_pos: usize) -> UranusResult {
    let state = STATE.read();
    let kernel_name = match &state.current_kernel {
        Some(k) => k.clone(),
        None => return UranusResult::err("NO_KERNEL", "No kernel connected"),
    };
    let kernel = match state.kernels.get(&kernel_name) {
        Some(k) => k,
        None => return UranusResult::err("KERNEL_NOT_FOUND", "Kernel not found"),
    };
    match kernel.inspect(code, cursor_pos) {
        Ok(result) => UranusResult::ok(serde_json::to_value(result).unwrap()),
        Err(e) => UranusResult::err("INSPECT_FAILED", e.to_string()),
    }
}

/// Lists remote kernels on a Jupyter server.
pub fn list_remote_kernels(server_url: &str) -> UranusResult {
    match remote::discover_remote_kernels(server_url) {
        Ok(kernels) => UranusResult::ok(serde_json::json!({ "kernels": kernels })),
        Err(e) => UranusResult::err("LIST_REMOTE_KERNELS_FAILED", e.to_string()),
    }
}

/// Connects to a remote kernel on a Jupyter server.
pub fn connect_remote_kernel(server_url: &str, kernel_id: &str) -> UranusResult {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build();
    match runtime {
        Ok(rt) => match rt
            .block_on(async { remote::RemoteKernelHandle::connect(server_url, kernel_id).await })
        {
            Ok(kernel) => {
                let key = format!("remote:{}:{}", server_url, kernel_id);
                let mut state = STATE.write();
                state
                    .kernels
                    .insert(key.clone(), Arc::new(kernel) as Arc<dyn KernelTrait>);
                state.current_kernel = Some(key);
                info!(
                    "Connected to remote kernel: {} on {}",
                    kernel_id, server_url
                );
                UranusResult::ok(serde_json::json!({"kernel": kernel_id, "server": server_url}))
            }
            Err(e) => {
                error!("Failed to connect to remote kernel: {}", e);
                UranusResult::err("REMOTE_CONNECT_FAILED", e.to_string())
            }
        },
        Err(e) => UranusResult::err("RUNTIME_ERROR", e.to_string()),
    }
}

/// Plugin entry point for nvim-oxi.
///
/// This function is marked with #[plugin] and is the entry point called by
/// Neovim when loading the plugin. It registers all commands with Neovim's Lua
/// API.
#[nvim_oxi::plugin]
fn uranus() -> nvim_oxi::Dictionary {
    use nvim_oxi::{Function, Object};

    let start_backend_fn = Function::from_fn(|_: ()| {
        let result = start_backend();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let stop_backend_fn = Function::from_fn(|_: ()| {
        let result = stop_backend();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let status_fn = Function::from_fn(|_: ()| {
        let result = status();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let list_kernels_fn = Function::from_fn(|_: ()| {
        let result = list_kernels();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let connect_kernel_fn = Function::from_fn(|name: String| {
        let result = connect_kernel(&name);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let disconnect_kernel_fn = Function::from_fn(|_: ()| {
        let result = disconnect_kernel();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let execute_fn = Function::from_fn(|code: String| {
        let result = execute(&code);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let interrupt_fn = Function::from_fn(|_: ()| {
        let result = interrupt();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let inspect_fn = Function::from_fn(|args: String| {
        let code = args.clone();
        let result = inspect(&code, 0);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let list_remote_kernels_fn = Function::from_fn(|server_url: String| {
        let result = list_remote_kernels(&server_url);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let connect_remote_kernel_fn = Function::from_fn(|args: String| {
        let parts: Vec<&str> = args.splitn(2, '|').collect();
        let (server_url, kernel_id) = if parts.len() == 2 {
            (parts[0], parts[1])
        } else {
            ("http://localhost:8888", parts[0])
        };
        let result = connect_remote_kernel(server_url, kernel_id);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    nvim_oxi::Dictionary::from_iter([
        ("start_backend", Object::from(start_backend_fn)),
        ("stop_backend", Object::from(stop_backend_fn)),
        ("status", Object::from(status_fn)),
        ("list_kernels", Object::from(list_kernels_fn)),
        ("connect_kernel", Object::from(connect_kernel_fn)),
        ("disconnect_kernel", Object::from(disconnect_kernel_fn)),
        ("execute", Object::from(execute_fn)),
        ("interrupt", Object::from(interrupt_fn)),
        ("inspect", Object::from(inspect_fn)),
        ("list_remote_kernels", Object::from(list_remote_kernels_fn)),
        (
            "connect_remote_kernel",
            Object::from(connect_remote_kernel_fn),
        ),
    ])
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_result_ok() {
        let result = UranusResult::ok(serde_json::json!({"value": 42}));
        assert!(result.success);
        assert!(result.data.is_some());
        assert!(result.error.is_none());
    }

    #[test]
    fn test_result_err() {
        let result = UranusResult::err("TEST_ERROR", "test error message");
        assert!(!result.success);
        assert!(result.data.is_none());
        assert!(result.error.is_some());
    }

    #[test]
    fn test_execution_result_default() {
        let result = ExecutionResult::default();
        assert_eq!(result.execution_count, 0);
    }

    #[test]
    fn test_inspect_result_default() {
        let result = InspectResult::default();
        assert!(!result.found);
    }

    #[test]
    fn test_kernel_info() {
        let info = KernelInfo {
            name: "python3".to_string(),
            language: "python".to_string(),
            status: "available".to_string(),
        };
        assert_eq!(info.name, "python3");
        assert_eq!(info.language, "python");
    }

    #[test]
    fn test_kernel_trait_object() {
        fn _assert_kerneltrait_impl<T: KernelTrait>() {}
        _assert_kerneltrait_impl::<KernelHandle>();
    }
}
