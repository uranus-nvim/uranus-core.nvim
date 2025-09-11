use std::collections::HashMap;
use std::sync::Arc;
use std::io::Write;
use tokio::sync::Mutex;
use anyhow::{Result, Context};
use tracing::{info, error, warn};
use serde_json;

use uranus_rs::kernel::UranusKernelManager;
use uranus_rs::protocol::{UranusRequest, UranusResponse, UranusError};

#[derive(Clone)]
pub struct AppState {
    kernel_manager: Arc<Mutex<UranusKernelManager>>,
    pending_requests: Arc<Mutex<HashMap<String, tokio::sync::oneshot::Sender<UranusResponse>>>>,
}

impl AppState {
    fn new() -> Self {
        Self {
            kernel_manager: Arc::new(Mutex::new(UranusKernelManager::new())),
            pending_requests: Arc::<Mutex<HashMap<String, tokio::sync::oneshot::Sender<UranusResponse>>>>::new(Mutex::new(HashMap::new())),
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    info!("Uranus backend starting...");

    let state = AppState::new();

    // Initialize kernel manager and discover kernels
    {
        let mut kernel_manager = state.kernel_manager.lock().await;
        kernel_manager.discover_kernels().await?;
        info!("Kernel discovery completed");
    }

    // Main message loop
    let stdin = std::io::stdin();
    let mut stdout = std::io::stdout();

    for line in stdin.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let response = match process_message(&state, &line).await {
            Ok(resp) => resp,
            Err(e) => {
                error!("Error processing message: {}", e);
                UranusResponse {
                    id: "error".to_string(),
                    success: false,
                    error: Some(UranusError {
                        code: "INTERNAL_ERROR".to_string(),
                        message: e.to_string(),
                        context: None,
                    }),
                    data: None,
                }
            }
        };

        // Send response back to Lua
        let json_response = serde_json::to_string(&response)?;
        println!("{}", json_response);
        stdout.flush()?;
    }

    info!("Uranus backend shutting down...");
    Ok(())
}

async fn process_message(state: &AppState, line: &str) -> Result<UranusResponse> {
    let request: UranusRequest = serde_json::from_str(line)
        .context("Failed to parse JSON message")?;

    handle_command(state, request).await
}

async fn handle_command(state: &AppState, request: UranusRequest) -> Result<UranusResponse> {
    info!("Handling command: {} ({})", request.cmd, request.id);

    match request.cmd.as_str() {
        "list_kernels" => {
            let kernel_manager = state.kernel_manager.lock().await;
            let kernels = kernel_manager.list_kernels().await;
            Ok(UranusResponse {
                id: request.id,
                success: true,
                error: None,
                data: Some(serde_json::json!({
                    "kernels": kernels
                })),
            })
        }

        "start_kernel" => {
            let kernel_name = request.data
                .as_ref()
                .and_then(|d| d.get("kernel"))
                .and_then(|k| k.as_str())
                .context("Missing kernel name")?;

            let mut kernel_manager = state.kernel_manager.lock().await;
            let kernel_info = kernel_manager.start_kernel(kernel_name).await?;

            Ok(UranusResponse {
                id: request.id,
                success: true,
                error: None,
                data: Some(serde_json::json!({
                    "kernel_info": kernel_info
                })),
            })
        }

        "execute" => {
            let code = request.data
                .as_ref()
                .and_then(|d| d.get("code"))
                .and_then(|c| c.as_str())
                .context("Missing code to execute")?;

            let kernel_manager = state.kernel_manager.lock().await;
            let result = kernel_manager.execute_code(code).await?;

            Ok(UranusResponse {
                id: request.id,
                success: true,
                error: None,
                data: Some(serde_json::json!({
                    "result": result
                })),
            })
        }

        "shutdown" => {
            let mut kernel_manager = state.kernel_manager.lock().await;
            kernel_manager.shutdown().await?;

            Ok(UranusResponse {
                id: request.id,
                success: true,
                error: None,
                data: Some(serde_json::json!({"status": "shutdown"})),
            })
        }

        _ => {
            warn!("Unknown command: {}", request.cmd);
            Ok(UranusResponse {
                id: request.id,
                success: false,
                error: Some(UranusError {
                    code: "UNKNOWN_COMMAND".to_string(),
                    message: format!("Unknown command: {}", request.cmd),
                    context: None,
                }),
                data: None,
            })
        }
    }
}
