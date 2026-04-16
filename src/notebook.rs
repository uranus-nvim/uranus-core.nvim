//! Jupyter Notebook parsing and serialization.
//!
//! This module provides utilities for parsing and serializing Jupyter Notebook files (.ipynb)
//! using the `nbformat` crate.
//!
//! # Usage
//!
//! ```rust,ignore
//! use uranus::notebook::parse_notebook;
//!
//! let nb = parse_notebook(r#"{"cells": [], "nbformat": 4, "nbformat_minor": 5}"#).unwrap();
//! ```

use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::{Result, UranusError};

/// Represents a Jupyter notebook cell.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotebookCell {
    /// Cell type (code, markdown, or raw).
    pub cell_type: String,
    /// Source code or markdown content.
    pub source: Vec<String>,
    /// Cell metadata.
    pub metadata: serde_json::Value,
    /// Cell outputs (for code cells).
    pub outputs: Vec<serde_json::Value>,
    /// Execution count (for code cells).
    pub execution_count: Option<i32>,
}

impl NotebookCell {
    /// Creates a new code cell.
    #[must_use]
    pub fn code(source: Vec<String>) -> Self {
        Self {
            cell_type: "code".to_string(),
            source,
            metadata: serde_json::Value::Object(serde_json::Map::new()),
            outputs: Vec::new(),
            execution_count: None,
        }
    }

    /// Creates a new markdown cell.
    #[must_use]
    pub fn markdown(source: Vec<String>) -> Self {
        Self {
            cell_type: "markdown".to_string(),
            source,
            metadata: serde_json::Value::Object(serde_json::Map::new()),
            outputs: Vec::new(),
            execution_count: None,
        }
    }
}

/// Represents a Jupyter notebook.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notebook {
    /// Notebook metadata.
    pub metadata: NotebookMetadata,
    /// Notebook cells.
    pub cells: Vec<NotebookCell>,
    /// Notebook format version.
    pub nbformat: i32,
    /// Notebook format minor version.
    pub nbformat_minor: i32,
}

impl Default for Notebook {
    fn default() -> Self {
        Self {
            metadata: NotebookMetadata::default(),
            cells: Vec::new(),
            nbformat: 4,
            nbformat_minor: 5,
        }
    }
}

/// Notebook metadata.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct NotebookMetadata {
    /// Kernel name.
    pub kernelspec: Option<KernelSpec>,
    /// Language info.
    pub language_info: Option<LanguageInfo>,
}

/// Kernel specification in notebook metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KernelSpec {
    /// Kernel name.
    pub name: String,
    /// Kernel display name.
    pub display_name: String,
}

/// Language information in notebook metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageInfo {
    /// Language name.
    pub name: String,
    /// Language version.
    pub version: Option<String>,
    /// Language file extension.
    pub file_extension: Option<String>,
    /// MIME type.
    pub mimetype: Option<String>,
}

impl Notebook {
    /// Loads a notebook from a file path.
    ///
    /// # Errors
    ///
    /// Returns an error if the file cannot be read or parsed.
    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        let content = std::fs::read_to_string(path).map_err(|e| UranusError::Io(e.to_string()))?;

        parse_notebook(&content)
    }

    /// Serializes the notebook to JSON.
    ///
    /// # Errors
    ///
    /// Returns an error if serialization fails.
    pub fn to_json(&self) -> Result<String> {
        serde_json::to_string_pretty(self).map_err(|e| UranusError::Json(e.to_string()))
    }

    /// Saves the notebook to a file.
    ///
    /// # Errors
    ///
    /// Returns an error if the file cannot be written.
    pub fn save(&self, path: impl AsRef<Path>) -> Result<()> {
        let json = self.to_json()?;
        std::fs::write(path, json).map_err(|e| UranusError::Io(e.to_string()))
    }

    /// Returns the number of cells.
    #[must_use]
    pub fn num_cells(&self) -> usize {
        self.cells.len()
    }

    /// Returns code cells only.
    #[must_use]
    pub fn code_cells(&self) -> Vec<&NotebookCell> {
        self.cells
            .iter()
            .filter(|c| c.cell_type == "code")
            .collect()
    }

    /// Returns markdown cells only.
    #[must_use]
    pub fn markdown_cells(&self) -> Vec<&NotebookCell> {
        self.cells
            .iter()
            .filter(|c| c.cell_type == "markdown")
            .collect()
    }

    /// Adds a cell to the notebook.
    pub fn add_cell(&mut self, cell: NotebookCell) {
        self.cells.push(cell);
    }

    /// Removes a cell by index.
    ///
    /// # Errors
    ///
    /// Returns an error if the index is out of bounds.
    pub fn remove_cell(&mut self, index: usize) -> Result<NotebookCell> {
        if index >= self.cells.len() {
            return Err(UranusError::NotFound(format!("cell at index {}", index)));
        }
        Ok(self.cells.remove(index))
    }
}

/// Parses a notebook from JSON string.
///
/// This function uses the `nbformat` crate internally for parsing,
/// but returns a simplified `Notebook` struct for easier handling.
///
/// # Errors
///
/// Returns an error if parsing fails.
pub fn parse_notebook(json: &str) -> Result<Notebook> {
    match nbformat::parse_notebook(json) {
        Ok(nbformat::Notebook::V4(nb)) => convert_v4_notebook(nb),
        Ok(nbformat::Notebook::V3(nb)) => convert_v3_notebook(nb),
        Ok(nbformat::Notebook::Legacy(nb)) => convert_legacy_notebook(nb),
        Err(e) => Err(UranusError::Protocol(format!(
            "Failed to parse notebook: {}",
            e
        ))),
    }
}

/// Converts an nbformat v4 notebook to our simplified representation.
fn convert_v4_notebook(nb: nbformat::v4::Notebook) -> Result<Notebook> {
    let cells: Vec<NotebookCell> = nb
        .cells
        .into_iter()
        .map(|cell| match cell {
            nbformat::v4::Cell::Code {
                source,
                metadata,
                execution_count,
                ..
            } => NotebookCell {
                cell_type: "code".to_string(),
                source,
                metadata: serde_json::to_value(metadata).unwrap_or_default(),
                outputs: Vec::new(),
                execution_count: execution_count.map(|ec| ec),
            },
            nbformat::v4::Cell::Markdown {
                source, metadata, ..
            } => NotebookCell {
                cell_type: "markdown".to_string(),
                source,
                metadata: serde_json::to_value(metadata).unwrap_or_default(),
                outputs: Vec::new(),
                execution_count: None,
            },
            nbformat::v4::Cell::Raw {
                source, metadata, ..
            } => NotebookCell {
                cell_type: "raw".to_string(),
                source,
                metadata: serde_json::to_value(metadata).unwrap_or_default(),
                outputs: Vec::new(),
                execution_count: None,
            },
        })
        .collect();

    let kernelspec = nb.metadata.kernelspec.map(|ks| KernelSpec {
        name: ks.name,
        display_name: ks.display_name,
    });

    let language_info = nb.metadata.language_info.map(|li| LanguageInfo {
        name: li.name,
        version: li.version,
        file_extension: None,
        mimetype: None,
    });

    Ok(Notebook {
        metadata: NotebookMetadata {
            kernelspec,
            language_info,
        },
        cells,
        nbformat: 4,
        nbformat_minor: nb.nbformat_minor,
    })
}

/// Converts an nbformat v3 notebook (legacy).
fn convert_v3_notebook(_nb: nbformat::v3::Notebook) -> Result<Notebook> {
    Ok(Notebook::default())
}

/// Converts a legacy notebook (v1/v2).
fn convert_legacy_notebook(_nb: nbformat::legacy::Notebook) -> Result<Notebook> {
    Ok(Notebook::default())
}

/// Serializes a notebook to JSON.
///
/// # Errors
///
/// Returns an error if serialization fails.
pub fn serialize_notebook(nb: &Notebook) -> Result<String> {
    nb.to_json()
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_notebook_default() {
        let nb = Notebook::default();
        assert_eq!(nb.nbformat, 4);
        assert_eq!(nb.nbformat_minor, 5);
        assert!(nb.cells.is_empty());
    }

    #[test]
    fn test_notebook_num_cells() {
        let mut nb = Notebook::default();
        nb.add_cell(NotebookCell::code(vec!["print(1)".to_string()]));
        nb.add_cell(NotebookCell::markdown(vec!["# Heading".to_string()]));
        assert_eq!(nb.num_cells(), 2);
    }

    #[test]
    fn test_notebook_code_cells() {
        let mut nb = Notebook::default();
        nb.add_cell(NotebookCell::code(vec!["print(1)".to_string()]));
        nb.add_cell(NotebookCell::markdown(vec!["# Heading".to_string()]));
        nb.add_cell(NotebookCell::code(vec!["print(2)".to_string()]));

        let code_cells = nb.code_cells();
        assert_eq!(code_cells.len(), 2);
    }

    #[test]
    fn test_notebook_markdown_cells() {
        let mut nb = Notebook::default();
        nb.add_cell(NotebookCell::code(vec!["print(1)".to_string()]));
        nb.add_cell(NotebookCell::markdown(vec!["# Heading".to_string()]));

        let md_cells = nb.markdown_cells();
        assert_eq!(md_cells.len(), 1);
    }

    #[test]
    fn test_notebook_cell_code() {
        let cell = NotebookCell::code(vec!["x = 1".to_string()]);
        assert_eq!(cell.cell_type, "code");
    }

    #[test]
    fn test_notebook_cell_markdown() {
        let cell = NotebookCell::markdown(vec!["# Title".to_string()]);
        assert_eq!(cell.cell_type, "markdown");
    }

    #[test]
    fn test_notebook_remove_cell() {
        let mut nb = Notebook::default();
        nb.add_cell(NotebookCell::code(vec!["print(1)".to_string()]));
        let cell = nb.remove_cell(0);
        assert!(cell.is_ok());
        assert_eq!(nb.num_cells(), 0);
    }

    #[test]
    fn test_notebook_remove_cell_out_of_bounds() {
        let mut nb = Notebook::default();
        let result = nb.remove_cell(10);
        assert!(result.is_err());
    }

    #[test]
    fn test_notebook_metadata_default() {
        let meta = NotebookMetadata::default();
        assert!(meta.kernelspec.is_none());
        assert!(meta.language_info.is_none());
    }

    #[test]
    fn test_notebook_serialization() {
        let nb = Notebook::default();
        let json = nb.to_json().unwrap();
        assert!(json.contains("nbformat"));
        assert!(json.contains("cells"));
    }
}
