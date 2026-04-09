use anyhow::Result;
use std::collections::HashMap;
use tracing::{debug, info};

use runtimelib::kernelspec::list_kernelspecs;

#[derive(Debug, Clone)]
pub struct Kernel {
    pub name: String,
    pub language: String,
}

impl Kernel {
    pub fn connect(kernel_name: &str) -> Result<Self> {
        info!("Connecting to kernel: {}", kernel_name);

        let specs = futures::executor::block_on(list_kernelspecs());
        let spec = specs
            .into_iter()
            .find(|s| s.kernel_name == kernel_name)
            .ok_or_else(|| anyhow::anyhow!("Kernel not found: {}", kernel_name))?;

        Ok(Self {
            name: kernel_name.to_string(),
            language: spec.kernelspec.language,
        })
    }

    pub fn execute(&self, code: &str) -> Result<super::ExecutionResult> {
        debug!("Executing code via runtimelib: {}", code);

        let result = super::ExecutionResult {
            execution_count: 1,
            stdout: Some(format!("Code would be executed via runtimelib: {}", code)),
            stderr: None,
            data: HashMap::new(),
            error: None,
        };

        Ok(result)
    }

    pub fn interrupt(&self) -> Result<()> {
        debug!("Interrupting kernel: {}", self.name);
        Ok(())
    }

    pub fn shutdown(&self) -> Result<()> {
        debug!("Shutting down kernel: {}", self.name);
        Ok(())
    }
}

pub fn discover_local_kernels_sync() -> Result<Vec<super::KernelInfo>> {
    info!("Discovering local kernels via runtimelib (sync)");

    let specs = futures::executor::block_on(list_kernelspecs());

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
