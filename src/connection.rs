//! Connection utilities for Jupyter kernel communication.
//!
//! This module provides utilities for managing connections to Jupyter kernels
//! using runtimelib and jupyter-protocol.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::error::UranusError;

/// Connection information for a Jupyter kernel.
///
/// This is the primary structure used to connect to a Jupyter kernel.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionInfo {
    /// Transport type (TCP or IPC).
    pub transport: String,
    /// IP address.
    pub ip: String,
    /// stdin port.
    pub stdin_port: u16,
    /// control port.
    pub control_port: u16,
    /// heartbeat port.
    pub hb_port: u16,
    /// shell port.
    pub shell_port: u16,
    /// iopub port.
    pub iopub_port: u16,
    /// Signature scheme (hmac-sha256).
    pub signature_scheme: String,
    /// Authentication key.
    pub key: String,
    /// Kernel name.
    pub kernel_name: Option<String>,
}

impl Default for ConnectionInfo {
    fn default() -> Self {
        Self {
            transport: "tcp".to_string(),
            ip: "127.0.0.1".to_string(),
            stdin_port: 0,
            control_port: 0,
            hb_port: 0,
            shell_port: 0,
            iopub_port: 0,
            signature_scheme: "hmac-sha256".to_string(),
            key: uuid::Uuid::new_v4().to_string(),
            kernel_name: None,
        }
    }
}

impl ConnectionInfo {
    /// Creates connection info with default values.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Creates connection info with custom IP and ports.
    #[must_use]
    pub fn with_ports(
        ip: &str,
        stdin_port: u16,
        control_port: u16,
        hb_port: u16,
        shell_port: u16,
        iopub_port: u16,
    ) -> Self {
        Self {
            ip: ip.to_string(),
            stdin_port,
            control_port,
            hb_port,
            shell_port,
            iopub_port,
            ..Self::default()
        }
    }

    /// Writes connection info to a JSON file.
    ///
    /// # Errors
    ///
    /// Returns an error if writing fails.
    pub fn write_to_file(&self, path: impl Into<PathBuf>) -> Result<(), UranusError> {
        let json =
            serde_json::to_string_pretty(self).map_err(|e| UranusError::Json(e.to_string()))?;

        std::fs::write(path.into(), json).map_err(|e| UranusError::Io(e.to_string()))
    }

    /// Reads connection info from a JSON file.
    ///
    /// # Errors
    ///
    /// Returns an error if reading fails.
    pub fn read_from_file(path: impl Into<PathBuf>) -> Result<Self, UranusError> {
        let content =
            std::fs::read_to_string(path.into()).map_err(|e| UranusError::Io(e.to_string()))?;

        serde_json::from_str(&content).map_err(|e| UranusError::Json(e.to_string()))
    }
}

/// Discovers available ports for kernel connection.
///
/// Uses runtimelib to find available ports on the specified address.
///
/// # Errors
///
/// Returns an error if port discovery fails.
pub async fn discover_ports(addr: &str, count: usize) -> Result<Vec<u16>, UranusError> {
    let ip: std::net::IpAddr = addr
        .parse()
        .map_err(|e| UranusError::connection(format!("invalid address: {}", e)))?;

    let ports = runtimelib::connection::peek_ports(ip, count)
        .await
        .map_err(|e| UranusError::connection(e.to_string()))?;

    Ok(ports)
}

/// Creates a client shell connection.
///
/// # Errors
///
/// Returns an error if connection fails.
pub async fn create_shell_connection(
    conn_info: &ConnectionInfo,
    session_id: &str,
) -> Result<runtimelib::connection::ClientShellConnection, UranusError> {
    let protocol_info = jupyter_protocol::ConnectionInfo {
        transport: if conn_info.transport == "tcp" {
            jupyter_protocol::Transport::TCP
        } else {
            jupyter_protocol::Transport::IPC
        },
        ip: conn_info.ip.clone(),
        stdin_port: conn_info.stdin_port,
        control_port: conn_info.control_port,
        hb_port: conn_info.hb_port,
        shell_port: conn_info.shell_port,
        iopub_port: conn_info.iopub_port,
        signature_scheme: conn_info.signature_scheme.clone(),
        key: conn_info.key.clone(),
        kernel_name: conn_info.kernel_name.clone(),
    };

    let peer_identity = runtimelib::connection::peer_identity_for_session(session_id)
        .map_err(|e| UranusError::connection(e.to_string()))?;

    runtimelib::connection::create_client_shell_connection_with_identity(
        &protocol_info,
        session_id,
        peer_identity,
    )
    .await
    .map_err(|e| UranusError::connection(e.to_string()))
}

/// Creates a client IOPub connection.
///
/// # Errors
///
/// Returns an error if connection fails.
pub async fn create_iopub_connection(
    conn_info: &ConnectionInfo,
    session_id: &str,
) -> Result<runtimelib::connection::ClientIoPubConnection, UranusError> {
    let protocol_info = jupyter_protocol::ConnectionInfo {
        transport: if conn_info.transport == "tcp" {
            jupyter_protocol::Transport::TCP
        } else {
            jupyter_protocol::Transport::IPC
        },
        ip: conn_info.ip.clone(),
        stdin_port: conn_info.stdin_port,
        control_port: conn_info.control_port,
        hb_port: conn_info.hb_port,
        shell_port: conn_info.shell_port,
        iopub_port: conn_info.iopub_port,
        signature_scheme: conn_info.signature_scheme.clone(),
        key: conn_info.key.clone(),
        kernel_name: conn_info.kernel_name.clone(),
    };

    runtimelib::connection::create_client_iopub_connection(&protocol_info, "", session_id)
        .await
        .map_err(|e| UranusError::connection(e.to_string()))
}

/// Creates a client stdin connection.
///
/// # Errors
///
/// Returns an error if connection fails.
pub async fn create_stdin_connection(
    conn_info: &ConnectionInfo,
    session_id: &str,
) -> Result<runtimelib::connection::ClientStdinConnection, UranusError> {
    let protocol_info = jupyter_protocol::ConnectionInfo {
        transport: if conn_info.transport == "tcp" {
            jupyter_protocol::Transport::TCP
        } else {
            jupyter_protocol::Transport::IPC
        },
        ip: conn_info.ip.clone(),
        stdin_port: conn_info.stdin_port,
        control_port: conn_info.control_port,
        hb_port: conn_info.hb_port,
        shell_port: conn_info.shell_port,
        iopub_port: conn_info.iopub_port,
        signature_scheme: conn_info.signature_scheme.clone(),
        key: conn_info.key.clone(),
        kernel_name: conn_info.kernel_name.clone(),
    };

    let peer_identity = runtimelib::connection::peer_identity_for_session(session_id)
        .map_err(|e| UranusError::connection(e.to_string()))?;

    runtimelib::connection::create_client_stdin_connection_with_identity(
        &protocol_info,
        session_id,
        peer_identity,
    )
    .await
    .map_err(|e| UranusError::connection(e.to_string()))
}

/// Creates a client control connection.
///
/// # Errors
///
/// Returns an error if connection fails.
pub async fn create_control_connection(
    conn_info: &ConnectionInfo,
    session_id: &str,
) -> Result<runtimelib::connection::ClientControlConnection, UranusError> {
    let protocol_info = jupyter_protocol::ConnectionInfo {
        transport: if conn_info.transport == "tcp" {
            jupyter_protocol::Transport::TCP
        } else {
            jupyter_protocol::Transport::IPC
        },
        ip: conn_info.ip.clone(),
        stdin_port: conn_info.stdin_port,
        control_port: conn_info.control_port,
        hb_port: conn_info.hb_port,
        shell_port: conn_info.shell_port,
        iopub_port: conn_info.iopub_port,
        signature_scheme: conn_info.signature_scheme.clone(),
        key: conn_info.key.clone(),
        kernel_name: conn_info.kernel_name.clone(),
    };

    runtimelib::connection::create_client_control_connection(&protocol_info, session_id)
        .await
        .map_err(|e| UranusError::connection(e.to_string()))
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_connection_info_default() {
        let conn = ConnectionInfo::default();
        assert_eq!(conn.transport, "tcp");
        assert_eq!(conn.ip, "127.0.0.1");
    }

    #[test]
    fn test_connection_info_with_ports() {
        let conn = ConnectionInfo::with_ports("127.0.0.1", 1, 2, 3, 4, 5);
        assert_eq!(conn.stdin_port, 1);
        assert_eq!(conn.control_port, 2);
        assert_eq!(conn.hb_port, 3);
        assert_eq!(conn.shell_port, 4);
        assert_eq!(conn.iopub_port, 5);
    }

    #[test]
    fn test_connection_info_new() {
        let conn = ConnectionInfo::new();
        assert!(!conn.key.is_empty());
    }
}
