use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::sync::Arc;
use tokio::sync::Mutex;
use serde::{Deserialize, Serialize};
use anyhow::{Result, Context};
use tracing::{info, error, warn};

mod kernel;
mod protocol;
mod zmq_client;

use kernel::KernelManager;
use protocol::{Message, Response, Event};

#[derive(Clone)]
pub struct AppState {
    kernel_manager: Arc<Mutex<KernelManager>>,
    pending_requests: Arc<Mutex<HashMap<String, tokio::sync::oneshot::Sender<Response>>>>,
}

impl AppState {
    fn new() -> Self {
        Self {
            kernel_manager: Arc::new(Mutex::new(KernelManager::new())),
            pending_requests: Arc::new(Mutex::new(HashMap::new())),
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

    // Initialize kernel manager
    {
        let mut kernel_manager = state.kernel_manager.lock().await;
        kernel_manager.discover_kernels().await?;
        info!("Kernel discovery completed");
    }

    // Main message loop
    let stdin = io::stdin();
    let mut stdout = io::stdout();

    for line in stdin.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let response = match process_message(&state, &line).await {
            Ok(resp) => resp,
            Err(e) => {
                error!("Error processing message: {}", e);
                Message::Response(Response {
                    id: "error".to_string(),
                    success: false,
                    error: Some(protocol::Error {
                        code: "INTERNAL_ERROR".to_string(),
                        message: e.to_string(),
                        context: None,
                    }),
                    data: None,
                })
            }
        };

        // Send response back to Lua
        let json_response = serde_json::to_string(&response)?;
        writeln!(stdout, "{}", json_response)?;
        stdout.flush()?;
    }

    info!("Uranus backend shutting down...");
    Ok(())
}

async fn process_message(state: &AppState, line: &str) -> Result<Message> {
    let message: Message = serde_json::from_str(line)
        .context("Failed to parse JSON message")?;

    match message {
        Message::Request(request) => {
            let response = handle_command(state, request).await?;
            Ok(Message::Response(response))
        }
        _ => {
            warn!("Received unexpected message type");
            Ok(Message::Response(Response {
                id: "unknown".to_string(),
                success: false,
                error: Some(protocol::Error {
                    code: "INVALID_MESSAGE".to_string(),
                    message: "Expected request message".to_string(),
                    context: None,
                }),
                data: None,
            }))
        }
    }
}

async fn handle_command(state: &AppState, request: protocol::Request) -> Result<Response> {
    info!("Handling command: {} ({})", request.cmd, request.id);

    match request.cmd.as_str() {
        "list_kernels" => {
            let kernel_manager = state.kernel_manager.lock().await;
            let kernels = kernel_manager.list_kernels().await?;
            Ok(Response {
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

            // Send kernel started event
            if let Some(stdout) = &kernel_info.connection_file {
                let event = Message::Event(Event {
                    event: "kernel_started".to_string(),
                    data: serde_json::json!({
                        "kernel": kernel_name,
                        "connection_file": stdout
                    }),
                });
                // In a real implementation, you'd send this to the event stream
                info!("Kernel started: {}", kernel_name);
            }

            Ok(Response {
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

            Ok(Response {
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

            Ok(Response {
                id: request.id,
                success: true,
                error: None,
                data: Some(serde_json::json!({"status": "shutdown"})),
            })
        }

        _ => {
            warn!("Unknown command: {}", request.cmd);
            Ok(Response {
                id: request.id,
                success: false,
                error: Some(protocol::Error {
                    code: "UNKNOWN_COMMAND".to_string(),
                    message: format!("Unknown command: {}", request.cmd),
                    context: None,
                }),
                data: None,
            })
        }
    }
}
