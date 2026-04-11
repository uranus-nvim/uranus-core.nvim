use anyhow::Result;
use std::collections::HashMap;
use tracing::{info, debug};

#[derive(Clone, Debug)]
pub struct Kernel {
    pub name: String,
    pub language: String,
}

#[derive(Clone, Debug)]
pub struct KernelHandle {
    pub inner: Kernel,
}

impl KernelHandle {
    pub fn new(kernel_name: &str) -> Result<Self> {
        info!("Creating kernel handle for: {}", kernel_name);
        
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        
        let spec = runtime.block_on(async {
            let specs = runtimelib::kernelspec::list_kernelspecs().await;
            specs.into_iter()
                .find(|s| s.kernel_name == kernel_name)
                .ok_or_else(|| anyhow::anyhow!("Kernel not found: {}", kernel_name))
        })?;
        
        let inner = Kernel {
            name: kernel_name.to_string(),
            language: spec.kernelspec.language,
        };
        
        info!("Kernel handle created for: {}", kernel_name);
        
        Ok(Self { inner })
    }

    pub async fn execute_async(&self, code: &str) -> Result<super::ExecutionResult> {
        let spec = runtimelib::kernelspec::find_kernelspec(&self.inner.name).await?;
        
        let ports = runtimelib::connection::peek_ports("127.0.0.1".parse()?, 5).await?;
        
        let connection_info = jupyter_protocol::ConnectionInfo {
            transport: jupyter_protocol::Transport::TCP,
            ip: "127.0.0.1".to_string(),
            stdin_port: ports[0],
            control_port: ports[1],
            hb_port: ports[2],
            shell_port: ports[3],
            iopub_port: ports[4],
            signature_scheme: "hmac-sha256".to_string(),
            key: uuid::Uuid::new_v4().to_string(),
            kernel_name: Some(self.inner.name.clone()),
        };
        
        let runtime_dir = runtimelib::dirs::runtime_dir();
        std::fs::create_dir_all(&runtime_dir)?;
        
        let connection_path = runtime_dir.join(format!("uranus-kernel-{}.json", uuid::Uuid::new_v4()));
        let conn_json = serde_json::to_string_pretty(&connection_info)?;
        std::fs::write(&connection_path, conn_json)?;
        
        let work_dir = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
        
        let _process = spec.command(&connection_path, None, None)?
            .current_dir(work_dir)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .stdin(std::process::Stdio::piped())
            .kill_on_drop(true)
            .spawn()?;
        
        let session_id = uuid::Uuid::new_v4().to_string();
        let peer_identity = runtimelib::connection::peer_identity_for_session(&session_id)?;
        
        let mut shell = runtimelib::connection::create_client_shell_connection_with_identity(
            &connection_info, 
            &session_id,
            peer_identity.clone()
        ).await?;
        
        let mut iopub = runtimelib::connection::create_client_iopub_connection(
            &connection_info,
            "",
            &session_id,
        ).await?;
        
        let control = runtimelib::connection::create_client_control_connection(
            &connection_info,
            &session_id,
        ).await?;
        
let mut stdin = runtimelib::connection::create_client_stdin_connection_with_identity(
            &connection_info,
            &session_id,
            peer_identity,
        ).await?;

        let _ = (&_process, &control);
        
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        
        let request = jupyter_protocol::messaging::ExecuteRequest {
            code: code.to_string(),
            allow_stdin: true,
            ..Default::default()
        };
        let message: jupyter_protocol::messaging::JupyterMessage = request.into();
        
        shell.send(message).await?;
        
        let mut stdout_content = String::new();
        let mut stderr_content: Option<String> = None;
        let mut execution_count = 0;
        let mut data = HashMap::new();
        let mut error_msg: Option<String> = None;
        let mut pending_input: Option<(String, bool)> = None;
        
        let mut waits = 0;
        
        loop {
            waits += 1;
            tokio::select! {
                msg = stdin.read() => {
                    match msg {
                        Ok(response) => {
                            debug!("stdin received msg_type: {:?}", response.header.msg_type);
                            use jupyter_protocol::messaging::JupyterMessageContent;
                            if let JupyterMessageContent::InputRequest(req) = response.content {
                                info!("Got input request: {}", req.prompt);
                                pending_input = Some((req.prompt.clone(), req.password));
                            } else {
                                debug!("stdin non-input message: {:?}", response.header.msg_type);
                            }
                        }
                        Err(e) => {
                            debug!("stdin read error: {:?}", e);
                        }
                    }
                }
                msg = iopub.read() => {
                    match msg {
                        Ok(response) => {
                            use jupyter_protocol::messaging::JupyterMessageContent;
                            match response.content {
                                JupyterMessageContent::StreamContent(stream) => {
                                    use jupyter_protocol::messaging::Stdio;
                                    match stream.name {
                                        Stdio::Stdout => stdout_content.push_str(&stream.text),
                                        Stdio::Stderr => {
                                            stderr_content.get_or_insert_with(String::new).push_str(&stream.text);
                                        },
                                    }
                                },
                                JupyterMessageContent::ExecuteInput(_) => {},
                                JupyterMessageContent::ExecuteResult(ref result) => {
                                    execution_count = result.execution_count.0 as i32;
                                    for media_type in &result.data.content {
                                        use jupyter_protocol::media::MediaType;
                                        match media_type {
                                            MediaType::Plain(text) => { data.insert("text/plain".to_string(), text.clone()); },
                                            MediaType::Html(html) => { data.insert("text/html".to_string(), html.clone()); },
                                            MediaType::Png(png) => { data.insert("image/png".to_string(), png.clone()); },
                                            MediaType::Jpeg(jpeg) => { data.insert("image/jpeg".to_string(), jpeg.clone()); },
                                            MediaType::Svg(svg) => { data.insert("image/svg+xml".to_string(), svg.clone()); },
                                            _ => {}
                                        }
                                    }
                                },
                                JupyterMessageContent::ErrorOutput(err) => { error_msg = Some(err.evalue.clone()); },
                                JupyterMessageContent::Status(status) => {
                                    if status.execution_state == jupyter_protocol::messaging::ExecutionState::Idle {
                                        if waits > 1 { break; }
                                    }
                                },
                                JupyterMessageContent::ExecuteReply(reply) => {
                                    if reply.status == jupyter_protocol::messaging::ReplyStatus::Error {
                                        error_msg = reply.error.as_ref().map(|e| e.evalue.clone());
                                    } else {
                                        execution_count = reply.execution_count.0 as i32;
                                    }
                                },
                                _ => {}
                            }
                        }
                        Err(_) => {}
                    }
                }
                msg = shell.read() => {
                    match msg {
                        Ok(response) => {
                            use jupyter_protocol::messaging::JupyterMessageContent;
                            if let JupyterMessageContent::ExecuteReply(reply) = response.content {
                                if reply.status == jupyter_protocol::messaging::ReplyStatus::Error {
                                    error_msg = reply.error.as_ref().map(|e| e.evalue.clone());
                                }
                                execution_count = reply.execution_count.0 as i32;
                            }
                        }
                        Err(_) => {}
                    }
                }
                _ = tokio::time::sleep(std::time::Duration::from_millis(500)) => {
                    if waits > 10 { break; }
                }
            }
        }
        
        if let Some((prompt, is_password)) = pending_input {
            info!("Sending input reply for prompt: {} (password: {})", prompt, is_password);
            let reply = jupyter_protocol::messaging::InputReply {
                value: String::new(),
                ..Default::default()
            };
            let msg: jupyter_protocol::messaging::JupyterMessage = reply.into();
            let _ = stdin.send(msg).await;
        }
        
        Ok(super::ExecutionResult {
            execution_count,
            stdout: if stdout_content.is_empty() { None } else { Some(stdout_content) },
            stderr: stderr_content,
            data,
            error: error_msg,
        })
    }

    pub async fn inspect_async(&self, code: &str, cursor_pos: usize) -> Result<super::InspectResult> {
        let spec = runtimelib::kernelspec::find_kernelspec(&self.inner.name).await?;
        
        let ports = runtimelib::connection::peek_ports("127.0.0.1".parse()?, 5).await?;
        
        let connection_info = jupyter_protocol::ConnectionInfo {
            transport: jupyter_protocol::Transport::TCP,
            ip: "127.0.0.1".to_string(),
            stdin_port: ports[0],
            control_port: ports[1],
            hb_port: ports[2],
            shell_port: ports[3],
            iopub_port: ports[4],
            signature_scheme: "hmac-sha256".to_string(),
            key: uuid::Uuid::new_v4().to_string(),
            kernel_name: Some(self.inner.name.clone()),
        };
        
        let runtime_dir = runtimelib::dirs::runtime_dir();
        std::fs::create_dir_all(&runtime_dir)?;
        
        let connection_path = runtime_dir.join(format!("uranus-inspect-{}.json", uuid::Uuid::new_v4()));
        let conn_json = serde_json::to_string_pretty(&connection_info)?;
        std::fs::write(&connection_path, conn_json)?;
        
        let work_dir = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
        
        let _process = spec.command(&connection_path, None, None)?
            .current_dir(work_dir)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .stdin(std::process::Stdio::piped())
            .kill_on_drop(true)
            .spawn()?;
        
        let session_id = uuid::Uuid::new_v4().to_string();
        let peer_identity = runtimelib::connection::peer_identity_for_session(&session_id)?;
        
        let mut shell = runtimelib::connection::create_client_shell_connection_with_identity(
            &connection_info, 
            &session_id,
            peer_identity.clone()
        ).await?;
        
        let mut iopub = runtimelib::connection::create_client_iopub_connection(
            &connection_info,
            "",
            &session_id,
        ).await?;
        
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        
        let inspect_code = format!(
            "import json; __info = {{}}; exec('try: {{__info[\"type\"] = type({}).__name__; __info[\"value\"] = repr({}); __info[\"doc\"] = {}.__doc__ or \"\"}} except Exception as e: {{__info[\"error\"] = str(e)}}'); print(json.dumps(__info))",
            code, code, code
        );
        
        let request = jupyter_protocol::messaging::ExecuteRequest::new(inspect_code);
        let message: jupyter_protocol::messaging::JupyterMessage = request.into();
        
        shell.send(message).await?;
        
        let mut result = super::InspectResult {
            found: true,
            name: code.to_string(),
            type_name: String::new(),
            value: None,
            docstring: None,
        };
        
        let mut waits = 0;
        loop {
            waits += 1;
            tokio::select! {
                msg = iopub.read() => {
                    match msg {
                        Ok(response) => {
                            use jupyter_protocol::messaging::JupyterMessageContent;
                            match response.content {
                                JupyterMessageContent::StreamContent(s) => {
                                    let output = s.text.trim();
                                    if let Ok(ok) = serde_json::from_str::<serde_json::Value>(output) {
                                        result.type_name = ok.get("type").and_then(|v| v.as_str()).unwrap_or("unknown").to_string();
                                        result.value = ok.get("value").and_then(|v| v.as_str()).map(String::from);
                                        result.docstring = ok.get("doc").and_then(|v| v.as_str()).map(String::from);
                                        break;
                                    }
                                }
                                JupyterMessageContent::ErrorOutput(e) => {
                                    result.found = false;
                                    result.value = Some(e.evalue);
                                    break;
                                }
                                JupyterMessageContent::Status(status) => {
                                    if status.execution_state == jupyter_protocol::messaging::ExecutionState::Idle {
                                        break;
                                    }
                                }
                                _ => {}
                            }
                        }
                        Err(_) => {}
                    }
                }
                msg = shell.read() => {
                    match msg {
                        Ok(response) => {
                            use jupyter_protocol::messaging::JupyterMessageContent;
                            if let JupyterMessageContent::ExecuteReply(reply) = response.content {
                                if reply.status == jupyter_protocol::messaging::ReplyStatus::Error {
                                    result.found = false;
                                }
                            }
                        }
                        Err(_) => {}
                    }
                }
                _ = tokio::time::sleep(std::time::Duration::from_millis(200)) => {
                    if waits > 20 { break; }
                }
            }
        }
        
        Ok(result)
    }
}

impl super::KernelTrait for KernelHandle {
    fn execute(&self, code: &str) -> Result<super::ExecutionResult> {
        info!("Executing code via runtimelib: {}", code);
        
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(async {
            self.execute_async(code).await
        })
    }

    fn interrupt(&self) -> Result<()> {
        info!("Interrupting kernel: {}", self.inner.name);
        Ok(())
    }

    fn shutdown(&self) -> Result<()> {
        info!("Shutting down kernel: {}", self.inner.name);
        Ok(())
    }

    fn inspect(&self, code: &str, cursor_pos: usize) -> Result<super::InspectResult> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(async {
            self.inspect_async(code, cursor_pos).await
        })
    }

    fn kernel_type(&self) -> &str {
        "local"
    }
}

pub fn connect_kernel(kernel_name: &str) -> Result<KernelHandle> {
    KernelHandle::new(kernel_name)
}

pub fn discover_local_kernels_sync() -> Result<Vec<super::KernelInfo>> {
    info!("Discovering local kernels via runtimelib (sync)");
    
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    
    let specs = runtime.block_on(async {
        runtimelib::kernelspec::list_kernelspecs().await
    });
    
    let mut kernels = Vec::new();
    for spec in specs {
        kernels.push(super::KernelInfo {
            name: spec.kernel_name,
            language: spec.kernelspec.language,
            status: "available".to_string(),
        });
    }
    
    Ok(kernels)
}