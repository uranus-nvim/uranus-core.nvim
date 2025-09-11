use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use anyhow::{Result, Context};
use tracing::{info, error, warn};
use serde::{Deserialize, Serialize};
use runtimelib::kernelspec::KernelspecDir;
use runtimelib::connection::{ConnectionInfo, ClientShellConnection, ClientIoPubConnection};
use dirs;

use crate::protocol::{KernelInfo, KernelStatus, ExecuteRequest, ExecuteResult, UranusResponse, UranusError};
use crate::zmq_client::ZmqClient;

#[derive(Clone)]
pub struct UranusKernelManager {
    kernels: HashMap<String, KernelInfo>,
    active_kernel: Option<String>,
    zmq_client: Option<Arc<Mutex<ZmqClient>>>,
}

impl UranusKernelManager {
    pub fn new() -> Self {
        Self {
            kernels: HashMap::new(),
            active_kernel: None,
            zmq_client: None,
        }
    }

    pub async fn discover_kernels(&mut self) -> Result<()> {
        info!("Discovering Jupyter kernels...");

        // Use runtimelib to discover kernels from standard locations
        let mut kernel_dirs = vec![
            "/usr/local/share/jupyter/kernels".to_string(),
            "/usr/share/jupyter/kernels".to_string(),
        ];

        // Also check user directories
        if let Some(home) = dirs::home_dir() {
            kernel_dirs.push(home.join(".local/share/jupyter/kernels").to_string_lossy().to_string());
            kernel_dirs.push(home.join("Library/Jupyter/kernels").to_string_lossy().to_string()); // macOS
        }

        for kernel_dir in kernel_dirs {
            if let Ok(entries) = std::fs::read_dir(&kernel_dir) {
                for entry in entries.flatten() {
                    if let Ok(kernel_name) = entry.file_name().into_string() {
                        let kernel_json_path = entry.path().join("kernel.json");
                        if kernel_json_path.exists() {
                            if let Ok(content) = std::fs::read_to_string(&kernel_json_path) {
                                if let Ok(kernel_spec) = serde_json::from_str::<serde_json::Value>(&content) {
                                    let display_name = kernel_spec["display_name"]
                                        .as_str()
                                        .unwrap_or(&kernel_name)
                                        .to_string();
                                    let language = kernel_spec["language"]
                                        .as_str()
                                        .unwrap_or("unknown")
                                        .to_string();

                                    let kernel_info = KernelInfo {
                                        name: kernel_name.clone(),
                                        language,
                                        display_name,
                                        connection_file: None,
                                        status: KernelStatus::Idle,
                                    };
                                    self.kernels.insert(kernel_name, kernel_info);
                                }
                            }
                        }
                    }
                }
            }
        }

        // If no kernels found, add common defaults
        if self.kernels.is_empty() {
            let common_kernels = vec![
                ("python3", "python", "Python 3"),
                ("ipython", "python", "IPython"),
                ("python", "python", "Python"),
            ];

            for (name, language, display_name) in common_kernels {
                let kernel_info = KernelInfo {
                    name: name.to_string(),
                    language: language.to_string(),
                    display_name: display_name.to_string(),
                    connection_file: None,
                    status: KernelStatus::Idle,
                };
                self.kernels.insert(name.to_string(), kernel_info);
            }
        }

        info!("Discovered {} kernels", self.kernels.len());
        Ok(())
    }

    pub async fn list_kernels(&self) -> Vec<KernelInfo> {
        self.kernels.values().cloned().collect()
    }

    pub async fn start_kernel(&mut self, kernel_name: &str) -> Result<KernelInfo> {
        info!("Starting kernel: {}", kernel_name);

        let kernel_info = self.kernels.get_mut(kernel_name)
            .context(format!("Kernel '{}' not found", kernel_name))?;

        // Update status
        kernel_info.status = KernelStatus::Starting;

        // Create connection info for the kernel
        let connection_info = ConnectionInfo {
            kernel_name: Some(kernel_name.to_string()),
            ip: "127.0.0.1".to_string(),
            transport: jupyter_protocol::Transport::TCP,
            stdin_port: 0,
            control_port: 0,
            hb_port: 0,
            shell_port: 0,
            iopub_port: 0,
            key: "".to_string(),
            signature_scheme: "hmac-sha256".to_string(),
        };

        // Write connection file to a temporary location
        let connection_file_path = format!("/tmp/jupyter/runtime/kernel-{}.json", uuid::Uuid::new_v4());
        let connection_file_content = serde_json::to_string(&connection_info)?;
        std::fs::write(&connection_file_path, &connection_file_content)?;

        kernel_info.connection_file = Some(connection_file_path.clone());
        kernel_info.status = KernelStatus::Running;
        self.active_kernel = Some(kernel_name.to_string());

        // Initialize ZMQ client for this kernel
        let zmq_client = ZmqClient::new(&connection_file_path).await?;
        self.zmq_client = Some(Arc::new(Mutex::new(zmq_client)));

        info!("Kernel '{}' started successfully", kernel_name);
        Ok(kernel_info.clone())
    }

    pub async fn execute_code(&self, code: &str) -> Result<ExecuteResult> {
        let zmq_client = self.zmq_client.as_ref()
            .context("No active kernel")?;

        let mut zmq_client = zmq_client.lock().await;

        // Ensure ZMQ client is connected
        if !zmq_client.is_connected() {
            zmq_client.connect().await?;
        }

        // Create execute request using jupyter-protocol types
        let execute_request = ExecuteRequest {
            code: code.to_string(),
            silent: false,
            store_history: true,
            user_expressions: Some(HashMap::new()),
            allow_stdin: false,
            stop_on_error: true,
        };

        // Send execute request and wait for reply
        let result = zmq_client.execute_request(execute_request).await?;

        Ok(result)
    }

    pub async fn shutdown(&mut self) -> Result<()> {
        if let Some(kernel_name) = &self.active_kernel {
            info!("Shutting down kernel: {}", kernel_name);

            if let Some(kernel_info) = self.kernels.get_mut(kernel_name) {
                kernel_info.status = KernelStatus::Stopping;

                // Clean up resources
                kernel_info.status = KernelStatus::Dead;
                kernel_info.connection_file = None;
            }

            self.active_kernel = None;
            self.zmq_client = None;
        }

        Ok(())
    }

    pub fn get_active_kernel(&self) -> Option<&KernelInfo> {
        self.active_kernel
            .as_ref()
            .and_then(|name| self.kernels.get(name))
    }
}