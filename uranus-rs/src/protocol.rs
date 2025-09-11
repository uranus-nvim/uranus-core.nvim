use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use jupyter_protocol::*;

// Re-export commonly used types
pub use jupyter_protocol::{
    JupyterMessage,
    JupyterMessageContent,
    ExecuteRequest,
    ExecuteReply,
    ExecuteResult,
    ConnectionInfo,
    Transport,
};

// Simplified request/response types for our internal protocol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusRequest {
    pub id: String,
    pub cmd: String,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusResponse {
    pub id: String,
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<UranusError>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusEvent {
    pub event: String,
    pub data: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UranusError {
    pub code: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<serde_json::Value>,
}

// Kernel information structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KernelInfo {
    pub name: String,
    pub language: String,
    pub display_name: String,
    pub connection_file: Option<String>,
    pub status: KernelStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum KernelStatus {
    Starting,
    Running,
    Idle,
    Busy,
    Stopping,
    Dead,
}