//! Remote Jupyter kernel management via WebSocket.
//!
//! This module provides the `RemoteKernelHandle` for connecting to and executing code
//! in remote Jupyter kernels via the Jupyter Server WebSocket protocol.

#![allow(dead_code)]

use std::collections::HashMap;

use futures::{SinkExt as _, StreamExt as _};
use jupyter_protocol::{messaging::JupyterMessageContent, KernelInfoRequest};
use jupyter_websocket_client::{JupyterWebSocket, RemoteServer};
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;

use crate::error::UranusError;
use crate::{ExecutionResult, InspectResult, KernelInfo, KernelTrait};

/// Handle for a connected remote Jupyter kernel.
///
/// Manages the kernel lifecycle via WebSocket connection.
/// Thread-safe via Send + Sync.
#[derive(Clone)]
pub struct RemoteKernelHandle {
    /// The kernel WebSocket connection.
    inner: Arc<Mutex<JupyterWebSocket>>,
    /// Kernel ID.
    name: String,
    /// Programming language.
    language: String,
    /// Jupyter server URL.
    server_url: String,
}

impl RemoteKernelHandle {
    /// Connects to a remote kernel.
    ///
    /// # Errors
    ///
    /// Returns an error if connection fails.
    pub async fn connect(server_url: &str, kernel_id: &str) -> Result<Self, UranusError> {
        let server = RemoteServer::from_url(server_url)
            .map_err(|e| UranusError::connection(e.to_string()))?;
        let (socket, _response) = server
            .connect_to_kernel(kernel_id)
            .await
            .map_err(|e| UranusError::connection(e.to_string()))?;

        let kernel_name = kernel_id.to_string();
        let mut language = "python".to_string();

        let (mut w, mut r) = socket.split();

        w.send(KernelInfoRequest {}.into())
            .await
            .map_err(|e| UranusError::connection(e.to_string()))?;

        if let Some(Ok(resp)) = r.next().await {
            if let JupyterMessageContent::KernelInfoReply(reply) = resp.content {
                language = reply.language_info.name;
            }
        }

        let socket = w
            .reunite(r)
            .map_err(|_| UranusError::connection("Failed to reunite socket"))?;

        Ok(Self {
            inner: Arc::new(Mutex::new(socket)),
            name: kernel_name,
            language,
            server_url: server_url.to_string(),
        })
    }

    /// Executes code asynchronously.
    ///
    /// # Errors
    ///
    /// Returns an error if execution fails.
    pub async fn execute_async(&self, code: &str) -> Result<ExecutionResult, UranusError> {
        use jupyter_protocol::messaging::ExecuteRequest;

        let mut kernel = self.inner.lock().await;

        let session_id = Uuid::new_v4().to_string();
        let request = ExecuteRequest::new(code.to_string());
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();

        message.header.session = session_id;

        kernel
            .send(message)
            .await
            .map_err(|e| UranusError::execution(e.to_string()))?;

        let mut stdout_content = String::new();
        let mut stderr_content: Option<String> = None;
        let mut execution_count = 0;
        let mut data = HashMap::new();
        let mut error_msg: Option<String> = None;

        let mut waits = 0;
        loop {
            waits += 1;
            tokio::select! {
                                        msg = kernel.next() => {
                                            match msg {
                                                Some(Ok(response)) => {
                                                    match response.content {
                                                        JupyterMessageContent::StreamContent(stream) => {
                                                            use jupyter_protocol::messaging::Stdio;
                                                            match stream.name {
                                                                Stdio::Stdout => stdout_content.push_str(&stream.text),
                                                                Stdio::Stderr => {
                                                                    stderr_content.get_or_insert_with(String::new).push_str(&stream.text);
                                                                }
                                                            }
                                                        }
                                                        JupyterMessageContent::ExecuteInput(_) => {}
                                                        JupyterMessageContent::ExecuteResult(ref result) => {
                                                            execution_count = result.execution_count.0 as i32;
                                                            for media_type in &result.data.content {
                                                                use jupyter_protocol::media::MediaType;
                                                                match media_type {
                                                                    MediaType::Plain(text) => {
                                                                        data.insert("text/plain".to_string(), text.clone());
                                                                    }
                                                                    MediaType::Html(html) => {
                                                                        data.insert("text/html".to_string(), html.clone());
                                                                    }
                                                                    MediaType::Png(png) => {
                                                                        data.insert("image/png".to_string(), png.clone());
                                                                    }
                                                                    MediaType::Jpeg(jpeg) => {
                                                                        data.insert("image/jpeg".to_string(), jpeg.clone());
                                                                    }
                                                                    MediaType::Svg(svg) => {
                                                                        data.insert("image/svg+xml".to_string(), svg.clone());
                                                                    }
                                                                    _ => {}
                                                                }
                                                            }
                                                        }
                                                        JupyterMessageContent::ErrorOutput(err) => {
                                                            error_msg = Some(err.evalue.clone());
                                                        }
            #[allow(clippy::collapsible_if)]
            JupyterMessageContent::Status(status) => {
              if status.execution_state == jupyter_protocol::messaging::ExecutionState::Idle && waits > 1 {
                break;
              }
            }
                                                        JupyterMessageContent::ExecuteReply(reply) => {
                                                            if reply.status == jupyter_protocol::messaging::ReplyStatus::Error {
                                                                error_msg = reply.error.as_ref().map(|e| e.evalue.clone());
                                                            } else {
                                                                execution_count = reply.execution_count.0 as i32;
                                                            }
                                                        }
                                                        _ => {}
                                                    }
                                                }
                                                Some(Err(_)) => {}
                                                None => break,
                                            }
                                        }
                                        _ = tokio::time::sleep(std::time::Duration::from_millis(500)) => {
                                            if waits > 10 {
                                                break;
                                            }
                                        }
                                    }
        }

        Ok(ExecutionResult {
            execution_count,
            stdout: if stdout_content.is_empty() {
                None
            } else {
                Some(stdout_content)
            },
            stderr: stderr_content,
            data,
            error: error_msg,
        })
    }

    /// Interrupts execution asynchronously.
    pub async fn interrupt_async(&self) -> Result<(), UranusError> {
        use jupyter_protocol::messaging::InterruptRequest;

        let mut kernel = self.inner.lock().await;
        let session_id = Uuid::new_v4().to_string();
        let request = InterruptRequest {};
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();
        message.header.session = session_id;
        kernel
            .send(message)
            .await
            .map_err(|e| UranusError::execution(e.to_string()))?;
        Ok(())
    }

    /// Shuts down the kernel asynchronously.
    pub async fn shutdown_async(&self) -> Result<(), UranusError> {
        use jupyter_protocol::messaging::ShutdownRequest;

        let mut kernel = self.inner.lock().await;
        let session_id = Uuid::new_v4().to_string();
        let request = ShutdownRequest { restart: false };
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();
        message.header.session = session_id;
        let _ = kernel.send(message).await;
        Ok(())
    }

    /// Inspects a variable asynchronously.
    pub async fn inspect_async(
        &self,
        code: &str,
        _cursor_pos: usize,
    ) -> Result<InspectResult, UranusError> {
        let inspect_code = format!(
            "import json; __info = {{}}; exec('try: {{__info[\"type\"] = type({}).__name__; __info[\"value\"] = repr({}); __info[\"doc\"] = {}.__doc__ or \"\"}} except Exception as e: {{__info[\"error\"] = str(e)}}'); print(json.dumps(__info))",
            code, code, code
        );

        let result = self.execute_async(&inspect_code).await?;

        if let Some(output) = result.stdout {
            if let Ok(ok) = serde_json::from_str::<serde_json::Value>(output.trim()) {
                return Ok(InspectResult {
                    found: true,
                    name: code.to_string(),
                    type_name: ok
                        .get("type")
                        .and_then(|v| v.as_str())
                        .unwrap_or("unknown")
                        .to_string(),
                    value: ok.get("value").and_then(|v| v.as_str()).map(String::from),
                    docstring: ok.get("doc").and_then(|v| v.as_str()).map(String::from),
                });
            }
        }

        Ok(InspectResult {
            found: false,
            name: code.to_string(),
            type_name: String::new(),
            value: result.error,
            docstring: None,
        })
    }
}

impl KernelTrait for RemoteKernelHandle {
    fn execute(&self, code: &str) -> Result<ExecutionResult, UranusError> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| UranusError::runtime(e.to_string()))?;
        runtime.block_on(async { self.execute_async(code).await })
    }

    fn interrupt(&self) -> Result<(), UranusError> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| UranusError::runtime(e.to_string()))?;
        runtime.block_on(async { self.interrupt_async().await })
    }

    fn shutdown(&self) -> Result<(), UranusError> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| UranusError::runtime(e.to_string()))?;
        runtime.block_on(async { self.shutdown_async().await })
    }

    fn inspect(&self, code: &str, cursor_pos: usize) -> Result<InspectResult, UranusError> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|e| UranusError::runtime(e.to_string()))?;
        runtime.block_on(async { self.inspect_async(code, cursor_pos).await })
    }

    fn kernel_type(&self) -> &str {
        "remote"
    }
}

/// Response from Jupyter server API.
#[derive(serde::Deserialize)]
struct JupyterServerKernels {
    kernels: Vec<JupyterServerKernel>,
}

/// Kernel info from Jupyter server API.
#[derive(serde::Deserialize)]
struct JupyterServerKernel {
    id: String,
    name: String,
    #[serde(rename = "kernel_spec")]
    kernel_spec: KernelSpecInfo,
}

/// Kernel spec info from Jupyter server API.
#[derive(serde::Deserialize)]
struct KernelSpecInfo {
    language: Option<String>,
}

/// Discovers remote kernels asynchronously.
pub async fn discover_remote_kernels_async(
    server_url: &str,
) -> Result<Vec<KernelInfo>, UranusError> {
    let client = reqwest::Client::new();

    let mut url = server_url.trim_end_matches('/').to_string();
    url.push_str("/api/kernels");

    let response = client
        .get(&url)
        .send()
        .await
        .map_err(|e| UranusError::connection(e.to_string()))?;
    let kernels: Vec<JupyterServerKernel> = response
        .json()
        .await
        .map_err(|e| UranusError::kernel(e.to_string()))?;

    Ok(kernels
        .into_iter()
        .map(|k| KernelInfo {
            name: k.id,
            language: k
                .kernel_spec
                .language
                .unwrap_or_else(|| "python".to_string()),
            status: "remote".to_string(),
        })
        .collect())
}

/// Discovers remote kernels synchronously.
pub fn discover_remote_kernels(server_url: &str) -> Result<Vec<KernelInfo>, UranusError> {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(|e| UranusError::runtime(e.to_string()))?;

    runtime.block_on(async { discover_remote_kernels_async(server_url).await })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_remote_kernel_handle_send_sync() {
        fn check_send_sync<T: Send + Sync>() {}
        check_send_sync::<RemoteKernelHandle>();
    }

    #[test]
    fn test_jupyter_server_kernel_deserialize() {
        let json =
            r#"{"id": "kernel-123", "name": "python3", "kernel_spec": {"language": "python"}}"#;
        let kernel: JupyterServerKernel = serde_json::from_str(json).unwrap();
        assert_eq!(kernel.id, "kernel-123");
        assert_eq!(kernel.kernel_spec.language, Some("python".to_string()));
    }

    #[test]
    fn test_kernel_spec_info_default() {
        let info = KernelSpecInfo { language: None };
        assert!(info.language.is_none());
    }
}
