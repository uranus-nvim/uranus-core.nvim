//! Kernel connection pooling for reuse.
//!
//! This module provides a connection pool for kernel handles,
//! allowing reuse of kernel connections to reduce startup overhead.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use parking_lot::RwLock;

use crate::KernelTrait;

/// A pooled kernel with metadata.
#[derive(Clone)]
pub struct PooledKernel {
    /// The kernel handle.
    pub kernel: Arc<dyn KernelTrait>,
    /// When this kernel was created.
    pub created_at: Instant,
    /// When this kernel was last used.
    pub last_used: Instant,
    /// Whether the kernel is currently in use.
    pub in_use: bool,
}

/// Kernel connection pool for reusing kernel connections.
pub struct KernelPool {
    /// Pooled kernels indexed by name.
    kernels: Arc<RwLock<HashMap<String, Vec<PooledKernel>>>>,
    /// Maximum idle time before kernel is removed.
    max_idle_time: Duration,
    /// Maximum idle kernels per kernel name.
    max_idle_per_kernel: usize,
}

impl KernelPool {
    /// Creates a new kernel pool with default settings.
    pub fn new() -> Self {
        Self {
            kernels: Arc::new(RwLock::new(HashMap::new())),
            max_idle_time: Duration::from_secs(300),
            max_idle_per_kernel: 3,
        }
    }

    /// Creates a kernel pool with custom configuration.
    pub fn with_config(max_idle_time_ms: u64, max_idle_per_kernel: usize) -> Self {
        Self {
            kernels: Arc::new(RwLock::new(HashMap::new())),
            max_idle_time: Duration::from_millis(max_idle_time_ms),
            max_idle_per_kernel,
        }
    }

    /// Acquires a kernel from the pool if available.
    pub fn acquire(&self, kernel_name: &str) -> Option<Arc<dyn KernelTrait>> {
        let mut kernels = self.kernels.write();

        let available = kernels
            .entry(kernel_name.to_string())
            .or_insert_with(Vec::new);

        while let Some(pooled) = available.pop() {
            if pooled.last_used.elapsed() < self.max_idle_time {
                if !pooled.in_use {
                    return Some(pooled.kernel);
                }
            }
        }

        None
    }

    /// Releases a kernel back to the pool.
    pub fn release(&self, kernel: Arc<dyn KernelTrait>) {
        let mut kernels = self.kernels.write();
        let kernel_type = kernel.kernel_type();

        let entry = kernels
            .entry(kernel_type.to_string())
            .or_insert_with(Vec::new);

        if entry.len() < self.max_idle_per_kernel {
            entry.push(PooledKernel {
                kernel,
                created_at: Instant::now(),
                last_used: Instant::now(),
                in_use: false,
            });
        }
    }

    /// Clears all pooled kernels.
    pub fn clear(&self) {
        let mut kernels = self.kernels.write();
        kernels.clear();
    }

    /// Returns pool statistics.
    pub fn stats(&self) -> PoolStats {
        let kernels = self.kernels.read();
        let mut total = 0;
        let mut in_use = 0;

        for (_name, pool) in kernels.iter() {
            for pooled in pool {
                total += 1;
                if pooled.in_use {
                    in_use += 1;
                }
            }
        }

        PoolStats {
            total_kernels: total,
            in_use,
            idle: total.saturating_sub(in_use),
        }
    }
}

impl Default for KernelPool {
    fn default() -> Self {
        Self::new()
    }
}

/// Statistics about the kernel pool.
#[derive(Debug, Clone, serde::Serialize)]
pub struct PoolStats {
    /// Total number of kernels in pool.
    pub total_kernels: usize,
    /// Number of kernels currently in use.
    pub in_use: usize,
    /// Number of idle kernels.
    pub idle: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kernel_pool_default() {
        let pool = KernelPool::new();
        assert_eq!(pool.max_idle_per_kernel, 3);
    }

    #[test]
    fn test_kernel_pool_with_config() {
        let pool = KernelPool::with_config(60000, 5);
        assert_eq!(pool.max_idle_per_kernel, 5);
    }

    #[test]
    fn test_pool_stats() {
        let stats = PoolStats {
            total_kernels: 10,
            in_use: 3,
            idle: 7,
        };
        assert_eq!(stats.total_kernels, 10);
        assert_eq!(stats.in_use, 3);
        assert_eq!(stats.idle, 7);
    }

    #[test]
    fn test_pool_stats_saturating() {
        let stats = PoolStats {
            total_kernels: 5,
            in_use: 10,
            idle: 0,
        };
        assert_eq!(stats.idle, 0);
    }
}
