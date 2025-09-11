use std::collections::HashMap;
use anyhow::{Result, Context};
use tracing::{info, error, debug};
use runtimelib::connection::{ConnectionInfo, ClientShellConnection, ClientIoPubConnection};
use jupyter_protocol::{ExecuteRequest, ExecuteResult, JupyterMessage, JupyterMessageContent};

use crate::protocol::UranusResponse;

pub struct ZmqClient {
    connection_info: ConnectionInfo,
    shell_connection: Option<ClientShellConnection>,
    iopub_connection: Option<ClientIoPubConnection>,
    session_id: String,
    connected: bool,
}

impl ZmqClient {
    pub async fn new(connection_file: &str) -> Result<Self> {
        info!("Initializing ZMQ client with connection file: {}", connection_file);

        // Read and parse connection file
        let connection_info = Self::read_connection_file(connection_file)?;
        let session_id = uuid::Uuid::new_v4().to_string();

        Ok(Self {
            connection_info,
            shell_connection: None,
            iopub_connection: None,
            session_id,
            connected: false,
        })
    }

    fn read_connection_file(connection_file: &str) -> Result<ConnectionInfo> {
        let content = std::fs::read_to_string(connection_file)?;
        let connection_info: ConnectionInfo = serde_json::from_str(&content)?;
        Ok(connection_info)
    }

    pub async fn connect(&mut self) -> Result<()> {
        info!("Establishing ZMQ connections...");

        // Create shell connection for execute requests
        let shell_connection = runtimelib::connection::create_client_shell_connection(
            &self.connection_info,
            &self.session_id,
        ).await?;

        // Create IOPub connection for output messages
        let iopub_connection = runtimelib::connection::create_client_iopub_connection(
            &self.connection_info,
            &self.session_id,
            "",
        ).await?;

        self.shell_connection = Some(shell_connection);
        self.iopub_connection = Some(iopub_connection);
        self.connected = true;

        info!("ZMQ connections established successfully");
        Ok(())
    }

    pub async fn execute_request(&mut self, request: ExecuteRequest) -> Result<ExecuteResult> {
        if !self.connected {
            return Err(anyhow::anyhow!("ZMQ client not connected"));
        }

        let shell_conn = self.shell_connection.as_mut()
            .context("Shell connection not available")?;

        debug!("Executing request: {}", request.code);

        // Create execute message
        let execute_msg = JupyterMessage::new(
            JupyterMessageContent::ExecuteRequest(request),
            None,
        );

        // Send execute request
        shell_conn.send(execute_msg).await?;

        // Wait for execute reply
        let reply_msg = shell_conn.read().await?;
        let reply = match &reply_msg.content {
            JupyterMessageContent::ExecuteReply(reply) => reply.clone(),
            _ => return Err(anyhow::anyhow!("Unexpected message type in reply")),
        };

        // Collect outputs from IOPub (simplified - in production would handle multiple messages)
        let mut outputs: Vec<String> = Vec::new();

        // For now, create a simple result
        let result = ExecuteResult {
            execution_count: reply.execution_count,
            data: jupyter_protocol::Media::new(vec![jupyter_protocol::MediaType::Plain(format!("Executed code successfully"))]),
            metadata: serde_json::Map::new(),
            transient: None,
        };

        Ok(result)
    }

    pub async fn disconnect(&mut self) -> Result<()> {
        info!("Disconnecting ZMQ sockets...");

        // Connections will be automatically closed when dropped
        self.shell_connection = None;
        self.iopub_connection = None;
        self.connected = false;

        info!("ZMQ disconnection complete");
        Ok(())
    }

    pub fn is_connected(&self) -> bool {
        self.connected
    }
}