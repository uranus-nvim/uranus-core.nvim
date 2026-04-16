//! Global Tokio runtime management for Uranus.
//!
//! This module provides a singleton global Tokio runtime for async operations
//! throughout the plugin. The runtime is lazily initialized on first use.

use std::sync::Arc;

use once_cell::sync::OnceCell;
use parking_lot::RwLock;
use tokio::runtime::{Builder, Runtime};

/// Global runtime stored as Option to allow shutdown.
static GLOBAL_RUNTIME: OnceCell<Arc<RwLock<Option<Runtime>>>> = OnceCell::new();

/// Initializes the global Tokio runtime.
///
/// Creates a multi-threaded runtime with 4 worker threads if not already initialized.
/// Returns a reference to the runtime wrapper.
pub fn init_global_runtime() -> &'static Arc<RwLock<Option<Runtime>>> {
    GLOBAL_RUNTIME.get_or_init(|| {
        let runtime = Builder::new_multi_thread()
            .worker_threads(4)
            .enable_all()
            .build()
            .expect("Failed to create global runtime");

        Arc::new(RwLock::new(Some(runtime)))
    })
}

/// Gets the global runtime reference if initialized.
pub fn get_runtime() -> Option<Arc<RwLock<Option<Runtime>>>> {
    GLOBAL_RUNTIME.get().cloned()
}

/// Runs a synchronous function with the global runtime.
///
/// # Errors
///
/// Returns an error string if the runtime is not initialized or available.
pub fn with_runtime<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce(&Runtime) -> R,
{
    let runtime_lock = GLOBAL_RUNTIME
        .get()
        .ok_or_else(|| "Runtime not initialized".to_string())?;

    let runtime_guard = runtime_lock.read();
    let runtime = runtime_guard
        .as_ref()
        .ok_or_else(|| "Runtime not available".to_string())?;

    Ok(f(runtime))
}

/// Runs a blocking async function with the runtime.
pub fn with_runtime_blocking<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce() -> R + Send + 'static,
{
    with_runtime(|rt| rt.block_on(async { f() }))
}

/// Spawns a future on the global runtime.
pub fn spawn<F>(future: F) -> Result<tokio::task::JoinHandle<()>, String>
where
    F: std::future::Future<Output = ()> + Send + 'static,
{
    with_runtime(|rt| rt.spawn(future))
}

/// Spawns a blocking task on the global runtime.
pub fn spawn_blocking<F, R>(f: F) -> Result<tokio::task::JoinHandle<R>, String>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    with_runtime(|rt| rt.spawn_blocking(f))
}

/// Returns the current runtime status.
pub fn status() -> RuntimeStatus {
    match GLOBAL_RUNTIME.get() {
        Some(runtime_lock) => {
            let guard = runtime_lock.read();
            match guard.as_ref() {
                Some(_) => RuntimeStatus {
                    initialized: true,
                    worker_threads: 4,
                },
                None => RuntimeStatus {
                    initialized: false,
                    worker_threads: 0,
                },
            }
        }
        None => RuntimeStatus {
            initialized: false,
            worker_threads: 0,
        },
    }
}

/// Status information for the global runtime.
#[derive(Debug, Clone, serde::Serialize)]
pub struct RuntimeStatus {
    /// Whether the runtime is initialized.
    pub initialized: bool,
    /// Number of worker threads.
    pub worker_threads: usize,
}

/// Shuts down the global runtime gracefully.
///
/// Runs shutdown with a 5-second timeout.
pub fn shutdown() {
    if let Some(runtime_lock) = GLOBAL_RUNTIME.get() {
        let mut guard = runtime_lock.write();
        if let Some(runtime) = guard.take() {
            runtime.shutdown_timeout(std::time::Duration::from_secs(5));
        }
    }
}

/// Module-level runtime initialization for backward compatibility.
#[macro_export]
macro_rules! with_runtime {
    ($f:expr) => {
        $crate::runtime::with_runtime($f)
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_runtime_status_not_initialized() {
        let status = RuntimeStatus {
            initialized: false,
            worker_threads: 0,
        };
        assert!(!status.initialized);
        assert_eq!(status.worker_threads, 0);
    }

    #[test]
    fn test_runtime_status_initialized() {
        let status = RuntimeStatus {
            initialized: true,
            worker_threads: 4,
        };
        assert!(status.initialized);
        assert_eq!(status.worker_threads, 4);
    }

    #[test]
    fn test_runtime_serialization() {
        let status = RuntimeStatus {
            initialized: true,
            worker_threads: 4,
        };
        let json = serde_json::to_string(&status).unwrap();
        assert!(json.contains("initialized"));
        assert!(json.contains("worker_threads"));
    }
}
