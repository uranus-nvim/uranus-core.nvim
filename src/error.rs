//! Error types and handling for Uranus.
//!
//! This module provides comprehensive error types using `thiserror` for all
//! Uranus operations. It includes error codes, error responses, and convenient
//! error constructors.

use std::fmt;

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Error codes for Uranus operations.
///
/// These codes are used for programmatic error handling in Neovim.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    /// Kernel-related error.
    #[default]
    KernelError,
    /// Connection error.
    ConnectionError,
    /// Execution error.
    ExecutionError,
    /// Protocol error.
    ProtocolError,
    /// Configuration error.
    ConfigError,
    /// Resource not found.
    NotFound,
    /// I/O error.
    IoError,
    /// JSON serialization/deserialization error.
    JsonError,
    /// Tokio runtime error.
    TokioError,
    /// No kernel connected.
    NoKernel,
    /// Kernel not found.
    KernelNotFound,
    /// Failed to connect to kernel.
    KernelConnectFailed,
    /// Failed to list kernels.
    ListKernelsFailed,
    /// Execution failed.
    ExecutionFailed,
    /// Interrupt failed.
    InterruptFailed,
    /// Inspection failed.
    InspectFailed,
    /// Failed to list remote kernels.
    ListRemoteKernelsFailed,
    /// Failed to connect to remote kernel.
    RemoteConnectFailed,
    /// Runtime initialization error.
    RuntimeError,
    /// Invalid argument.
    InvalidArgument,
    /// Operation timeout.
    Timeout,
    /// Permission denied.
    PermissionDenied,
}

impl fmt::Display for ErrorCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            ErrorCode::KernelError => "KERNEL_ERROR",
            ErrorCode::ConnectionError => "CONNECTION_ERROR",
            ErrorCode::ExecutionError => "EXECUTION_ERROR",
            ErrorCode::ProtocolError => "PROTOCOL_ERROR",
            ErrorCode::ConfigError => "CONFIG_ERROR",
            ErrorCode::NotFound => "NOT_FOUND",
            ErrorCode::IoError => "IO_ERROR",
            ErrorCode::JsonError => "JSON_ERROR",
            ErrorCode::TokioError => "TOKIO_ERROR",
            ErrorCode::NoKernel => "NO_KERNEL",
            ErrorCode::KernelNotFound => "KERNEL_NOT_FOUND",
            ErrorCode::KernelConnectFailed => "KERNEL_CONNECT_FAILED",
            ErrorCode::ListKernelsFailed => "LIST_KERNELS_FAILED",
            ErrorCode::ExecutionFailed => "EXECUTION_FAILED",
            ErrorCode::InterruptFailed => "INTERRUPT_FAILED",
            ErrorCode::InspectFailed => "INSPECT_FAILED",
            ErrorCode::ListRemoteKernelsFailed => "LIST_REMOTE_KERNELS_FAILED",
            ErrorCode::RemoteConnectFailed => "REMOTE_CONNECT_FAILED",
            ErrorCode::RuntimeError => "RUNTIME_ERROR",
            ErrorCode::InvalidArgument => "INVALID_ARGUMENT",
            ErrorCode::Timeout => "TIMEOUT",
            ErrorCode::PermissionDenied => "PERMISSION_DENIED",
        };
        write!(f, "{}", name)
    }
}

/// Main error type for Uranus operations.
///
/// Uses `thiserror` for derive-based error handling with various error
/// variants.
#[derive(Error, Debug)]
pub enum UranusError {
    #[error("Kernel error: {0}")]
    Kernel(String),

    #[error("Connection error: {0}")]
    Connection(String),

    #[error("Execution error: {0}")]
    Execution(String),

    #[error("Protocol error: {0}")]
    Protocol(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("IO error: {0}")]
    Io(String),

    #[error("JSON error: {0}")]
    Json(String),

    #[error("Tokio error: {0}")]
    Tokio(String),

    #[error("Invalid argument: {0}")]
    InvalidArgument(String),

    #[error("Timeout: {0}")]
    Timeout(String),

    #[error("Runtime error: {0}")]
    Runtime(String),
}

impl UranusError {
    /// Returns the error code for this error type.
    #[inline]
    #[must_use]
    pub fn code(&self) -> ErrorCode {
        match self {
            UranusError::Kernel(_) => ErrorCode::KernelError,
            UranusError::Connection(_) => ErrorCode::ConnectionError,
            UranusError::Execution(_) => ErrorCode::ExecutionError,
            UranusError::Protocol(_) => ErrorCode::ProtocolError,
            UranusError::Config(_) => ErrorCode::ConfigError,
            UranusError::NotFound(_) => ErrorCode::NotFound,
            UranusError::Io(_) => ErrorCode::IoError,
            UranusError::Json(_) => ErrorCode::JsonError,
            UranusError::Tokio(_) => ErrorCode::TokioError,
            UranusError::InvalidArgument(_) => ErrorCode::InvalidArgument,
            UranusError::Timeout(_) => ErrorCode::Timeout,
            UranusError::Runtime(_) => ErrorCode::RuntimeError,
        }
    }

    /// Adds context to the error message.
    #[inline]
    #[must_use]
    pub fn with_context(self, context: &str) -> Self {
        let msg = match &self {
            UranusError::Kernel(s) => format!("{}: {}", context, s),
            UranusError::Connection(s) => format!("{}: {}", context, s),
            UranusError::Execution(s) => format!("{}: {}", context, s),
            UranusError::Protocol(s) => format!("{}: {}", context, s),
            UranusError::Config(s) => format!("{}: {}", context, s),
            UranusError::NotFound(s) => format!("{}: {}", context, s),
            _ => return self,
        };

        match self {
            UranusError::Kernel(_) => UranusError::Kernel(msg),
            UranusError::Connection(_) => UranusError::Connection(msg),
            UranusError::Execution(_) => UranusError::Execution(msg),
            UranusError::Protocol(_) => UranusError::Protocol(msg),
            UranusError::Config(_) => UranusError::Config(msg),
            UranusError::NotFound(_) => UranusError::NotFound(msg),
            _ => self,
        }
    }

    /// Creates a kernel error with message.
    #[inline]
    #[must_use]
    pub fn kernel(msg: impl Into<String>) -> Self {
        UranusError::Kernel(msg.into())
    }

    /// Creates a connection error with message.
    #[inline]
    #[must_use]
    pub fn connection(msg: impl Into<String>) -> Self {
        UranusError::Connection(msg.into())
    }

    /// Creates an execution error with message.
    #[inline]
    #[must_use]
    pub fn execution(msg: impl Into<String>) -> Self {
        UranusError::Execution(msg.into())
    }

    /// Creates a protocol error with message.
    #[inline]
    #[must_use]
    pub fn protocol(msg: impl Into<String>) -> Self {
        UranusError::Protocol(msg.into())
    }

    /// Creates a configuration error with message.
    #[inline]
    #[must_use]
    pub fn config(msg: impl Into<String>) -> Self {
        UranusError::Config(msg.into())
    }

    /// Creates a not found error with message.
    #[inline]
    #[must_use]
    pub fn not_found(msg: impl Into<String>) -> Self {
        UranusError::NotFound(msg.into())
    }

    /// Creates an invalid argument error with message.
    #[inline]
    #[must_use]
    pub fn invalid_argument(msg: impl Into<String>) -> Self {
        UranusError::InvalidArgument(msg.into())
    }

    /// Creates a timeout error with message.
    #[inline]
    #[must_use]
    pub fn timeout(msg: impl Into<String>) -> Self {
        UranusError::Timeout(msg.into())
    }

    /// Creates a runtime error with message.
    #[inline]
    #[must_use]
    pub fn runtime(msg: impl Into<String>) -> Self {
        UranusError::Runtime(msg.into())
    }
}

impl Serialize for UranusError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        #[derive(Serialize)]
        struct ErrorJson {
            code: String,
            message: String,
        }

        let json = ErrorJson {
            code: self.code().to_string(),
            message: self.to_string(),
        };
        json.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for UranusError {
    fn deserialize<D>(_deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Ok(UranusError::kernel("deserialized error"))
    }
}

/// Error response for serialization to Neovim.
///
/// This struct provides a consistent error format for returning errors to
/// Neovim.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorResponse {
    /// Error code for programmatic handling.
    pub code: String,
    /// Human-readable error message.
    pub message: String,
    /// Additional context (optional).
    pub context: Option<String>,
}

impl From<UranusError> for ErrorResponse {
    fn from(err: UranusError) -> Self {
        ErrorResponse {
            code: err.code().to_string(),
            message: err.to_string(),
            context: None,
        }
    }
}

impl std::error::Error for ErrorResponse {}

impl fmt::Display for ErrorResponse {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl ErrorResponse {
    /// Creates a new error response.
    #[inline]
    #[must_use]
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            context: None,
        }
    }

    /// Adds context to the error response.
    #[inline]
    #[must_use]
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.context = Some(context.into());
        self
    }
}

/// Result type alias using UranusError.
pub type Result<T, E = UranusError> = std::result::Result<T, E>;

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_code_display() {
        assert_eq!(ErrorCode::KernelError.to_string(), "KERNEL_ERROR");
        assert_eq!(ErrorCode::NoKernel.to_string(), "NO_KERNEL");
    }

    #[test]
    fn test_error_code_equality() {
        assert_eq!(ErrorCode::KernelError, ErrorCode::KernelError);
        assert_ne!(ErrorCode::KernelError, ErrorCode::ConnectionError);
    }

    #[test]
    fn test_uranus_error_code() {
        let err = UranusError::kernel("test error");
        assert_eq!(err.code(), ErrorCode::KernelError);

        let err = UranusError::connection("connection failed");
        assert_eq!(err.code(), ErrorCode::ConnectionError);

        let err = UranusError::execution("execution failed");
        assert_eq!(err.code(), ErrorCode::ExecutionError);
    }

    #[test]
    fn test_uranus_error_context() {
        let err = UranusError::kernel("original message");
        let err_with_context = err.with_context("context");

        let msg = err_with_context.to_string();
        assert!(msg.contains("context"));
        assert!(msg.contains("original message"));
    }

    #[test]
    fn test_uranus_error_convenience_constructors() {
        let err = UranusError::kernel("test");
        assert!(matches!(err, UranusError::Kernel(_)));

        let err = UranusError::connection("test");
        assert!(matches!(err, UranusError::Connection(_)));

        let err = UranusError::execution("test");
        assert!(matches!(err, UranusError::Execution(_)));

        let err = UranusError::protocol("test");
        assert!(matches!(err, UranusError::Protocol(_)));

        let err = UranusError::config("test");
        assert!(matches!(err, UranusError::Config(_)));

        let err = UranusError::not_found("test");
        assert!(matches!(err, UranusError::NotFound(_)));

        let err = UranusError::invalid_argument("test");
        assert!(matches!(err, UranusError::InvalidArgument(_)));

        let err = UranusError::timeout("test");
        assert!(matches!(err, UranusError::Timeout(_)));

        let err = UranusError::runtime("test");
        assert!(matches!(err, UranusError::Runtime(_)));
    }

    #[test]
    fn test_error_response() {
        let resp = ErrorResponse::new("CODE", "message");
        assert_eq!(resp.code, "CODE");
        assert_eq!(resp.message, "message");
        assert!(resp.context.is_none());

        let resp = resp.with_context("extra context");
        assert!(resp.context.is_some());
    }

    #[test]
    fn test_error_response_from_uranus_error() {
        let err = UranusError::kernel("test kernel error");
        let resp = ErrorResponse::from(err);

        assert_eq!(resp.code, "KERNEL_ERROR");
        assert!(resp.message.contains("test kernel error"));
    }

    #[test]
    fn test_error_response_display() {
        let resp = ErrorResponse::new("ERR_CODE", "error message");
        let display = resp.to_string();

        assert_eq!(display, "ERR_CODE: error message");
    }

    #[test]
    fn test_error_serialization() {
        let err = UranusError::kernel("test error");
        let json = serde_json::to_string(&err).unwrap();

        assert!(json.contains("KERNEL_ERROR"));
        assert!(json.contains("test error"));
    }

    #[test]
    fn test_all_error_codes() {
        let codes = vec![
            ErrorCode::KernelError,
            ErrorCode::ConnectionError,
            ErrorCode::ExecutionError,
            ErrorCode::ProtocolError,
            ErrorCode::ConfigError,
            ErrorCode::NotFound,
            ErrorCode::IoError,
            ErrorCode::JsonError,
            ErrorCode::TokioError,
            ErrorCode::NoKernel,
            ErrorCode::KernelNotFound,
            ErrorCode::KernelConnectFailed,
            ErrorCode::ListKernelsFailed,
            ErrorCode::ExecutionFailed,
            ErrorCode::InterruptFailed,
            ErrorCode::InspectFailed,
            ErrorCode::ListRemoteKernelsFailed,
            ErrorCode::RemoteConnectFailed,
            ErrorCode::RuntimeError,
            ErrorCode::InvalidArgument,
            ErrorCode::Timeout,
            ErrorCode::PermissionDenied,
        ];

        for code in codes {
            let _ = code.to_string();
        }
    }
}
