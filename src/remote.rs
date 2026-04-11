use anyhow::Result;
use futures::{SinkExt as _, StreamExt as _};
use jupyter_protocol::{messaging::JupyterMessageContent, KernelInfoRequest};
use jupyter_websocket_client::{JupyterWebSocket, RemoteServer};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;

#[derive(Clone)]
pub struct RemoteKernelHandle {
    pub inner: Arc<Mutex<JupyterWebSocket>>,
    pub name: String,
    pub language: String,
    pub server_url: String,
}

impl RemoteKernelHandle {
    pub async fn connect(server_url: &str, kernel_id: &str) -> Result<Self> {
        let server = RemoteServer::from_url(server_url)?;
        let (socket, _response) = server.connect_to_kernel(kernel_id).await?;
        
        let kernel_name = kernel_id.to_string();
        let mut language = "python".to_string();
        
        let (mut w, mut r) = socket.split();
        
        w.send(KernelInfoRequest {}.into()).await?;
        
        if let Some(resp) = r.next().await.transpose()? {
            if let JupyterMessageContent::KernelInfoReply(reply) = resp.content {
                language = reply.language_info.name;
            }
        }
        
        let mut socket = w.reunite(r).map_err(|_| anyhow::anyhow!("Failed to reunite"))?;
        
        Ok(Self {
            inner: Arc::new(Mutex::new(socket)),
            name: kernel_name,
            language,
            server_url: server_url.to_string(),
        })
    }

    pub async fn execute_async(&self, code: &str) -> Result<super::ExecutionResult> {
        use jupyter_protocol::messaging::ExecuteRequest;

        let mut kernel = self.inner.lock().await;
        
        let session_id = Uuid::new_v4().to_string();
        let request = ExecuteRequest::new(code.to_string());
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();
        
        message.header.session = session_id;
        
        kernel.send(message).await?;
        
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
                        Some(Err(_)) => {}
                        None => break,
                    }
                }
                _ = tokio::time::sleep(std::time::Duration::from_millis(500)) => {
                    if waits > 10 { break; }
                }
            }
        }
        
        Ok(super::ExecutionResult {
            execution_count,
            stdout: if stdout_content.is_empty() { None } else { Some(stdout_content) },
            stderr: stderr_content,
            data,
            error: error_msg,
        })
    }

    pub async fn interrupt_async(&self) -> Result<()> {
        use jupyter_protocol::messaging::InterruptRequest;
        
        let mut kernel = self.inner.lock().await;
        let session_id = Uuid::new_v4().to_string();
        let request = InterruptRequest {};
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();
        message.header.session = session_id;
        kernel.send(message).await?;
        Ok(())
    }

    pub async fn shutdown_async(&self) -> Result<()> {
        use jupyter_protocol::messaging::ShutdownRequest;
        
        let mut kernel = self.inner.lock().await;
        let session_id = Uuid::new_v4().to_string();
        let request = ShutdownRequest { restart: false };
        let mut message: jupyter_protocol::messaging::JupyterMessage = request.into();
        message.header.session = session_id;
        let _ = kernel.send(message).await;
        Ok(())
    }

    pub async fn inspect_async(&self, code: &str, cursor_pos: usize) -> Result<super::InspectResult> {
        let inspect_code = format!(
            "import json; __info = {{}}; exec('try: {{__info[\"type\"] = type({}).__name__; __info[\"value\"] = repr({}); __info[\"doc\"] = {}.__doc__ or \"\"}} except Exception as e: {{__info[\"error\"] = str(e)}}'); print(json.dumps(__info))",
            code, code, code
        );
        
        let result = self.execute_async(&inspect_code).await?;
        
        if let Some(output) = result.stdout {
            if let Ok(ok) = serde_json::from_str::<serde_json::Value>(&output.trim()) {
                return Ok(super::InspectResult {
                    found: true,
                    name: code.to_string(),
                    type_name: ok.get("type").and_then(|v| v.as_str()).unwrap_or("unknown").to_string(),
                    value: ok.get("value").and_then(|v| v.as_str()).map(String::from),
                    docstring: ok.get("doc").and_then(|v| v.as_str()).map(String::from),
                });
            }
        }
        
        Ok(super::InspectResult {
            found: false,
            name: code.to_string(),
            type_name: String::new(),
            value: result.error,
            docstring: None,
        })
    }
}

impl super::KernelTrait for RemoteKernelHandle {
    fn execute(&self, code: &str) -> Result<super::ExecutionResult> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(async {
            self.execute_async(code).await
        })
    }

    fn interrupt(&self) -> Result<()> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(async {
            self.interrupt_async().await
        })
    }

    fn shutdown(&self) -> Result<()> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()?;
        runtime.block_on(async {
            self.shutdown_async().await
        })
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
        "remote"
    }
}

#[derive(serde::Deserialize)]
struct JupyterServerKernels {
    kernels: Vec<JupyterServerKernel>,
}

#[derive(serde::Deserialize)]
struct JupyterServerKernel {
    id: String,
    name: String,
    #[serde(rename = "kernel_spec")]
    kernel_spec: KernelSpecInfo,
}

#[derive(serde::Deserialize)]
struct KernelSpecInfo {
    language: Option<String>,
}

pub async fn discover_remote_kernels_async(server_url: &str) -> Result<Vec<super::KernelInfo>> {
    let client = reqwest::Client::new();
    
    let mut url = server_url.trim_end_matches('/').to_string();
    url.push_str("/api/kernels");
    
    let response = client.get(&url).send().await?;
    let kernels: Vec<JupyterServerKernel> = response.json().await?;
    
    Ok(kernels.into_iter().map(|k| {
        super::KernelInfo {
            name: k.id,
            language: k.kernel_spec.language.unwrap_or_else(|| "python".to_string()),
            status: "remote".to_string(),
        }
    }).collect())
}

pub fn discover_remote_kernels(server_url: &str) -> Result<Vec<super::KernelInfo>> {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    
    runtime.block_on(async {
        discover_remote_kernels_async(server_url).await
    })
}