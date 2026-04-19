//! Zero-copy message parsing and handling.
//!
//! This module provides efficient message parsing utilities
//! for Jupyter protocol messages using Bytes for zero-copy operations.
#![allow(dead_code)]

use bytes::{Bytes, BytesMut};

/// Buffer for message data using Bytes for efficiency.
pub struct MessageBuffer {
    /// The message data.
    data: Bytes,
}

impl MessageBuffer {
    /// Creates a buffer from JSON string.
    pub fn from_json(json: &str) -> Self {
        Self {
            data: Bytes::from(json.to_string()),
        }
    }

    /// Creates a buffer from bytes.
    pub fn from_bytes(bytes: Vec<u8>) -> Self {
        Self {
            data: Bytes::from(bytes),
        }
    }

    /// Parses the buffer to the specified type.
    pub fn parse<T: serde::de::DeserializeOwned>(&self) -> Result<T, serde_json::Error> {
        serde_json::from_slice(&self.data)
    }

    /// Returns the buffer as a string slice.
    pub fn as_str(&self) -> &str {
        std::str::from_utf8(&self.data).unwrap_or("")
    }

    /// Returns the length of the buffer.
    pub fn len(&self) -> usize {
        self.data.len()
    }

    /// Returns true if the buffer is empty.
    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
}

/// Parses a JSON string to a Value.
pub fn parse_message(json: &str) -> Result<serde_json::Value, serde_json::Error> {
    serde_json::from_str(json)
}

/// Serializes a Value to a JSON string.
pub fn serialize_message(value: &serde_json::Value) -> String {
    serde_json::to_string(value).unwrap_or_default()
}

/// Zero-copy JSON parser using BytesMut.
pub struct ZeroCopyParser {
    /// Internal buffer.
    buffer: BytesMut,
}

impl ZeroCopyParser {
    /// Creates a new parser.
    pub fn new() -> Self {
        Self {
            buffer: BytesMut::new(),
        }
    }

    /// Appends data to the buffer.
    pub fn append(&mut self, data: &[u8]) {
        self.buffer.extend_from_slice(data);
    }

    /// Parses all complete messages from the buffer.
    pub fn parse_all<T: serde::de::DeserializeOwned>(&mut self) -> Vec<T> {
        let mut results = Vec::new();
        let data = std::mem::take(&mut self.buffer);

        if data.is_empty() {
            return results;
        }

        if let Ok(item) = serde_json::from_slice::<T>(&data) {
            results.push(item);
        }

        results
    }

    /// Clears the buffer.
    pub fn clear(&mut self) {
        self.buffer.clear();
    }
}

impl Default for ZeroCopyParser {
    fn default() -> Self {
        Self::new()
    }
}

/// Jupyter message representation.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct JupyterMessage {
    /// Message type (e.g., "execute_request").
    pub msg_type: String,
    /// Message content.
    pub content: serde_json::Value,
}

impl JupyterMessage {
    /// Creates a message from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    /// Converts the message to JSON.
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }
}

/// Parses a message string to a JupyterMessage.
pub fn parse(data: &str) -> Option<JupyterMessage> {
    parse_message(data).ok().map(|v| JupyterMessage {
        msg_type: v
            .get("msg_type")
            .and_then(|t| t.as_str())
            .unwrap_or("")
            .to_string(),
        content: v.get("content").cloned().unwrap_or(serde_json::Value::Null),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_buffer() {
        let buf = MessageBuffer::from_json(r#"{"key": "value"}"#);
        let parsed: serde_json::Value = buf.parse().unwrap();
        assert_eq!(parsed["key"], "value");
    }

    #[test]
    fn test_message_buffer_empty() {
        let buf = MessageBuffer::from_json("");
        assert!(buf.is_empty());
    }

    #[test]
    fn test_message_buffer_len() {
        let buf = MessageBuffer::from_json("test");
        assert_eq!(buf.len(), 4);
    }

    #[test]
    fn test_parse_message() {
        let msg = parse(r#"{"msg_type": "execute_reply", "content": {}}"#).unwrap();
        assert_eq!(msg.msg_type, "execute_reply");
    }

    #[test]
    fn test_jupyter_message_serialization() {
        let msg = JupyterMessage {
            msg_type: "execute_request".to_string(),
            content: serde_json::json!({"code": "print(1)"}),
        };
        let json = msg.to_json();
        assert!(json.contains("execute_request"));
    }

    #[test]
    fn test_zero_copy_parser() {
        let mut parser = ZeroCopyParser::new();
        parser.append(b"test");
        assert!(!parser.buffer.is_empty());
    }

    #[test]
    fn test_zero_copy_parser_clear() {
        let mut parser = ZeroCopyParser::new();
        parser.append(b"test");
        parser.clear();
        assert!(parser.buffer.is_empty());
    }
}
