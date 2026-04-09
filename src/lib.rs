mod execute;
mod kernel;
mod protocol;

pub use execute::*;
pub use kernel::*;
pub use protocol::*;

use nvim_oxi::{Dictionary, Function, Object};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{error, info};

static STATE: once_cell::sync::Lazy<parking_lot::RwLock<UranusState>> =
    once_cell::sync::Lazy::new(|| parking_lot::RwLock::new(UranusState::default()));

#[derive(Debug, Clone, Default)]
pub struct UranusState {
    pub backend_running: bool,
    pub kernels: HashMap<String, Arc<Kernel>>,
    pub current_kernel: Option<String>,
    pub config_valid: bool,
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
    let kernel = match Kernel::connect(kernel_name) {
        Ok(k) => k,
        Err(e) => {
            error!("Failed to connect to kernel {}: {}", kernel_name, e);
            return UranusResult::err("KERNEL_CONNECT_FAILED", e.to_string());
        }
    };

    let mut state = STATE.write();
    state
        .kernels
        .insert(kernel_name.to_string(), Arc::new(kernel));
    state.current_kernel = Some(kernel_name.to_string());

    info!("Connected to kernel: {}", kernel_name);
    UranusResult::ok(serde_json::json!({ "kernel": kernel_name }))
}

pub fn disconnect_kernel() -> UranusResult {
    let mut state = STATE.write();
    if let Some(name) = state.current_kernel.take() {
        state.kernels.remove(&name);
        info!("Disconnected from kernel: {}", name);
        UranusResult::ok(serde_json::json!({ "status": "disconnected" }))
    } else {
        UranusResult::err("NO_KERNEL", "No kernel connected")
    }
}

pub fn execute(code: &str) -> UranusResult {
    let state = STATE.read();
    let kernel_name = match &state.current_kernel {
        Some(k) => k.clone(),
        None => return UranusResult::err("NO_KERNEL", "No kernel connected"),
    };

    let kernel = match state.kernels.get(&kernel_name) {
        Some(k) => k.clone(),
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

    Dictionary::from_iter([
        ("start_backend", Object::from(start_backend)),
        ("stop_backend", Object::from(stop_backend)),
        ("status", Object::from(status)),
        ("list_kernels", Object::from(list_kernels)),
        ("connect_kernel", Object::from(connect_kernel)),
        ("disconnect_kernel", Object::from(disconnect_kernel)),
        ("execute", Object::from(execute)),
        ("interrupt", Object::from(interrupt)),
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
