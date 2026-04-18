//! Local Jupyter kernel management.
//!
//! This module provides the [`KernelHandle`] for managing local Jupyter kernels
//! using [`runtimelib`] and [`jupyter_protocol`].
//!
//! [`runtimelib`]: https://docs.rs/runtimelib/1.5.0
//! [`jupyter_protocol`]: https://docs.rs/jupyter-protocol/1.4.0

#![allow(dead_code)]

use std::collections::HashMap;

use tracing::info;

use crate::connection::{
    create_control_connection, create_iopub_connection, create_shell_connection,
    create_stdin_connection, ConnectionInfo,
};
use crate::error::UranusError;
use crate::runtime::with_runtime;
use crate::{ExecutionResult, InspectResult, KernelInfo, KernelTrait};

/// A connected local kernel.
#[derive(Clone, Debug)]
pub struct Kernel {
    /// Kernel name.
    pub name: String,
    /// Programming language.
    pub language: String,
}

/// Handle for a connected local Jupyter kernel.
#[derive(Clone, Debug)]
pub struct KernelHandle {
    /// The kernel.
    inner: Kernel,
}

impl KernelHandle {
    /// Creates a new kernel handle for the specified kernel name.
    ///
    /// # Errors
    ///
    /// Returns an error if the kernel cannot be found.
    pub fn new(kernel_name: &str) -> Result<Self, UranusError> {
        info!("Creating kernel handle for: {}", kernel_name);

        let spec = with_runtime(|rt| {
            rt.block_on(async { runtimelib::kernelspec::list_kernelspecs().await })
        })
        .map_err(UranusError::kernel)?;

        let spec = spec
            .into_iter()
            .find(|s| s.kernel_name == kernel_name)
            .ok_or_else(|| UranusError::not_found(format!("Kernel not found: {}", kernel_name)))?;

        let inner = Kernel {
            name: kernel_name.to_string(),
            language: spec.kernelspec.language,
        };

        info!("Kernel handle created for: {}", kernel_name);
        Ok(Self { inner })
    }

    /// Executes code asynchronously.
    ///
    /// # Errors
    ///
    /// Returns an error if execution fails.
    pub async fn execute_async(&self, code: &str) -> Result<ExecutionResult, UranusError> {
        let spec = runtimelib::kernelspec::find_kernelspec(&self.inner.name)
            .await
            .map_err(|e| UranusError::kernel(e.to_string()))?;

        let runtime_dir = runtimelib::dirs::runtime_dir();
        std::fs::create_dir_all(&runtime_dir)
            .map_err(|e| UranusError::kernel(format!("Failed to create runtime dir: {}", e)))?;

        let connection_path =
            runtime_dir.join(format!("uranus-kernel-{}.json", uuid::Uuid::new_v4()));

        let conn_info = ConnectionInfo::new();

        conn_info
            .write_to_file(&connection_path)
            .map_err(|e| UranusError::kernel(format!("Failed to write connection file: {}", e)))?;

        let work_dir = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));

        let process = spec
            .command(&connection_path, None, None)
            .map_err(|e| UranusError::kernel(e.to_string()))?
            .current_dir(work_dir)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .stdin(std::process::Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .map_err(|e| UranusError::kernel(e.to_string()))?;

        let session_id = uuid::Uuid::new_v4().to_string();

        let mut shell = create_shell_connection(&conn_info, &session_id).await?;
        let mut iopub = create_iopub_connection(&conn_info, &session_id).await?;
        let _control = create_control_connection(&conn_info, &session_id).await?;
        let mut stdin = create_stdin_connection(&conn_info, &session_id).await?;

        let _ = (&process, &_control);

        tokio::time::sleep(std::time::Duration::from_millis(500)).await;

        let request = jupyter_protocol::messaging::ExecuteRequest {
            code: code.to_string(),
            allow_stdin: true,
            ..Default::default()
        };
        let message: jupyter_protocol::messaging::JupyterMessage = request.into();

        shell
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
                            msg = stdin.read() => {
                                if let Ok(response) = msg {
                                    use jupyter_protocol::messaging::JupyterMessageContent;
                                    if let JupyterMessageContent::InputRequest(req) = response.content {
                                        info!("Got input request: {}", req.prompt);
                                    }
                                }
                            }
                            msg = iopub.read() => {
                                if let Ok(response) = msg {
                                    use jupyter_protocol::messaging::JupyterMessageContent;
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
            JupyterMessageContent::Status(status)
            if status.execution_state == jupyter_protocol::messaging::ExecutionState::Idle && waits > 1 =>
            {
              break;
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
                            }
                            msg = shell.read() => {
                                if let Ok(response) = msg {
                                    use jupyter_protocol::messaging::JupyterMessageContent;
                                    if let JupyterMessageContent::ExecuteReply(reply) = response.content {
                                        if reply.status == jupyter_protocol::messaging::ReplyStatus::Error {
                                            error_msg = reply.error.as_ref().map(|e| e.evalue.clone());
                                        }
                                        execution_count = reply.execution_count.0 as i32;
                                    }
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

    /// Inspects a variable asynchronously.
    ///
    /// # Errors
    ///
    /// Returns an error if inspection fails.
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

impl KernelTrait for KernelHandle {
    fn execute(&self, code: &str) -> Result<ExecutionResult, UranusError> {
        let rt = crate::runtime::get_runtime()
            .ok_or_else(|| UranusError::runtime("Runtime not initialized"))?;
        let guard = rt.read();
        let runtime = guard
            .as_ref()
            .ok_or_else(|| UranusError::runtime("Runtime not available"))?;
        runtime.block_on(self.execute_async(code))
    }

    fn interrupt(&self) -> Result<(), UranusError> {
        info!("Interrupting kernel: {}", self.inner.name);
        Ok(())
    }

    fn shutdown(&self) -> Result<(), UranusError> {
        info!("Shutting down kernel: {}", self.inner.name);
        Ok(())
    }

    fn inspect(&self, code: &str, cursor_pos: usize) -> Result<InspectResult, UranusError> {
        let rt = crate::runtime::get_runtime()
            .ok_or_else(|| UranusError::runtime("Runtime not initialized"))?;
        let guard = rt.read();
        let runtime = guard
            .as_ref()
            .ok_or_else(|| UranusError::runtime("Runtime not available"))?;
        runtime.block_on(self.inspect_async(code, cursor_pos))
    }

    fn kernel_type(&self) -> &str {
        "local"
    }
}

/// Connects to a local kernel by name.
///
/// # Errors
///
/// Returns an error if connection fails.
pub fn connect_kernel(kernel_name: &str) -> Result<KernelHandle, UranusError> {
    KernelHandle::new(kernel_name)
}

/// Discovers local kernels synchronously.
///
/// # Errors
///
/// Returns an error if discovery fails.
pub fn discover_local_kernels_sync() -> Result<Vec<KernelInfo>, UranusError> {
    info!("Discovering local kernels via runtimelib (sync)");
    let specs =
        with_runtime(|rt| rt.block_on(async { runtimelib::kernelspec::list_kernelspecs().await }))
            .map_err(|e| UranusError::kernel(e.to_string()))?;

    let mut kernels = Vec::new();
    for spec in specs {
        kernels.push(KernelInfo {
            name: spec.kernel_name,
            language: spec.kernelspec.language,
            status: "available".to_string(),
        });
    }
    Ok(kernels)
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kernel_handle_send_sync() {
        fn check_send_sync<T: Send + Sync>() {}
        check_send_sync::<KernelHandle>();
    }

    #[test]
    fn test_kernel_info() {
        let info = KernelInfo {
            name: "python3".to_string(),
            language: "python".to_string(),
            status: "available".to_string(),
        };
        assert_eq!(info.name, "python3");
    }

    #[test]
    fn test_kernel_inner() {
        let kernel = Kernel {
            name: "python3".to_string(),
            language: "python".to_string(),
        };
        assert_eq!(kernel.name, "python3");
        assert_eq!(kernel.language, "python");
    }
}
