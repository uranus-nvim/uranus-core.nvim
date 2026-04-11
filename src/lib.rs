mod execute;
mod kernel;
mod protocol;
mod remote;

pub use execute::*;
pub use kernel::*;
pub use remote::*;
pub use protocol::*;

use nvim_oxi::{Dictionary, Function, Object};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{error, info, warn};

static STATE: once_cell::sync::Lazy<parking_lot::RwLock<UranusState>> =
    once_cell::sync::Lazy::new(|| parking_lot::RwLock::new(UranusState::default()));

pub trait KernelTrait: Send + Sync {
    fn execute(&self, code: &str) -> Result<ExecutionResult, anyhow::Error>;
    fn interrupt(&self) -> Result<(), anyhow::Error>;
    fn shutdown(&self) -> Result<(), anyhow::Error>;
    fn inspect(&self, code: &str, cursor_pos: usize) -> Result<InspectResult, anyhow::Error>;
    fn kernel_type(&self) -> &str;
}

pub struct UranusState {
    pub backend_running: bool,
    pub kernels: HashMap<String, Arc<dyn KernelTrait>>,
    pub current_kernel: Option<String>,
    pub config_valid: bool,
}

impl Default for UranusState {
    fn default() -> Self {
        Self {
            backend_running: false,
            kernels: HashMap::new(),
            current_kernel: None,
            config_valid: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusResult {
    pub success: bool,
    pub data: Option<serde_json::Value>,
    pub error: Option<UranusError>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusError {
    pub code: String,
    pub message: String,
}

impl UranusResult {
    pub fn ok(data: serde_json::Value) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err(code: &str, message: impl Into<String>) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(UranusError {
                code: code.to_string(),
                message: message.into(),
            }),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KernelInfo {
    pub name: String,
    pub language: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionResult {
    pub execution_count: i32,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
    pub data: HashMap<String, String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InspectResult {
    pub found: bool,
    pub name: String,
    pub type_name: String,
    pub value: Option<String>,
    pub docstring: Option<String>,
}

pub fn start_backend() -> UranusResult {
    info!("Starting Uranus backend");
    let mut state = STATE.write();
    state.backend_running = true;
    UranusResult::ok(serde_json::json!({ "status": "started" }))
}

pub fn stop_backend() -> UranusResult {
    info!("Stopping Uranus backend");
    let mut state = STATE.write();
    state.backend_running = false;
    state.kernels.clear();
    state.current_kernel = None;
    UranusResult::ok(serde_json::json!({ "status": "stopped" }))
}

pub fn status() -> UranusResult {
    let state = STATE.read();
    UranusResult::ok(serde_json::json!({
        "version": env!("CARGO_PKG_VERSION"),
        "backend_running": state.backend_running,
        "current_kernel": state.current_kernel,
        "config_valid": state.config_valid,
    }))
}

pub fn list_kernels() -> UranusResult {
    match discover_local_kernels_sync() {
        Ok(kernels) => UranusResult::ok(serde_json::json!({ "kernels": kernels })),
        Err(e) => UranusResult::err("LIST_KERNELS_FAILED", e.to_string()),
    }
}

pub fn connect_kernel(kernel_name: &str) -> UranusResult {
    let kernel = match kernel::connect_kernel(kernel_name) {
        Ok(k) => Arc::new(k) as Arc<dyn KernelTrait>,
        Err(e) => {
            error!("Failed to connect to kernel {}: {}", kernel_name, e);
            return UranusResult::err("KERNEL_CONNECT_FAILED", e.to_string());
        }
    };

    let mut state = STATE.write();
    state
        .kernels
        .insert(kernel_name.to_string(), kernel);
    state.current_kernel = Some(kernel_name.to_string());

    info!("Connected to kernel: {}", kernel_name);
    UranusResult::ok(serde_json::json!({ "kernel": kernel_name }))
}

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

pub fn list_remote_kernels(server_url: &str) -> UranusResult {
    match discover_remote_kernels(server_url) {
        Ok(kernels) => UranusResult::ok(serde_json::json!({ "kernels": kernels })),
        Err(e) => UranusResult::err("LIST_REMOTE_KERNELS_FAILED", e.to_string()),
    }
}

pub fn connect_remote_kernel(server_url: &str, kernel_id: &str) -> UranusResult {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build();
    
    match runtime {
        Ok(rt) => {
            match rt.block_on(async { remote::RemoteKernelHandle::connect(server_url, kernel_id).await }) {
                Ok(kernel) => {
                    let key = format!("remote:{}:{}", server_url, kernel_id);
                    let mut state = STATE.write();
                    state.kernels.insert(key.clone(), Arc::new(kernel) as Arc<dyn KernelTrait>);
                    state.current_kernel = Some(key);
                    info!("Connected to remote kernel: {} on {}", kernel_id, server_url);
                    UranusResult::ok(serde_json::json!({ "kernel": kernel_id, "server": server_url }))
                }
                Err(e) => {
                    error!("Failed to connect to remote kernel: {}", e);
                    UranusResult::err("REMOTE_CONNECT_FAILED", e.to_string())
                }
            }
        }
        Err(e) => {
            UranusResult::err("RUNTIME_ERROR", e.to_string())
        }
    }
}

#[nvim_oxi::plugin]
fn uranus() -> Dictionary {
    let start_backend = Function::from_fn(|_: ()| {
        let result = start_backend();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let stop_backend = Function::from_fn(|_: ()| {
        let result = stop_backend();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let status = Function::from_fn(|_: ()| {
        let result = status();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let list_kernels = Function::from_fn(|_: ()| {
        let result = list_kernels();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let connect_kernel = Function::from_fn(|name: String| {
        let result = connect_kernel(&name);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let disconnect_kernel = Function::from_fn(|_: ()| {
        let result = disconnect_kernel();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let execute = Function::from_fn(|code: String| {
        let result = execute(&code);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let interrupt = Function::from_fn(|_: ()| {
        let result = interrupt();
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let inspect = Function::from_fn(|args: String| {
        let code = args.clone();
        let result = inspect(&code, 0);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let list_remote_kernels = Function::from_fn(|server_url: String| {
        let result = list_remote_kernels(&server_url);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    let connect_remote_kernel = Function::from_fn(|args: String| {
        let parts: Vec<&str> = args.splitn(2, "|").collect();
        let (server_url, kernel_id) = if parts.len() == 2 {
            (parts[0], parts[1])
        } else {
            ("http://localhost:8888", parts[0])
        };
        let result = connect_remote_kernel(server_url, kernel_id);
        Object::from(serde_json::to_string(&result).unwrap())
    });

    Dictionary::from_iter([
        ("start_backend", Object::from(start_backend)),
        ("stop_backend", Object::from(stop_backend)),
        ("status", Object::from(status)),
        ("list_kernels", Object::from(list_kernels)),
        ("connect_kernel", Object::from(connect_kernel)),
        ("disconnect_kernel", Object::from(disconnect_kernel)),
        ("execute", Object::from(execute)),
        ("interrupt", Object::from(interrupt)),
        ("inspect", Object::from(inspect)),
        ("list_remote_kernels", Object::from(list_remote_kernels)),
        ("connect_remote_kernel", Object::from(connect_remote_kernel)),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_result_ok() {
        let result = UranusResult::ok(serde_json::json!({"value": 42}));
        assert!(result.success);
        assert!(result.error.is_none());
    }

    #[test]
    fn test_result_err() {
        let result = UranusResult::err("TEST", "test error");
        assert!(!result.success);
        assert!(result.error.is_some());
    }
}
