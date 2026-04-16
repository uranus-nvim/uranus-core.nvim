//! Parallel execution of tasks with concurrency control.
//!
//! This module provides utilities for running tasks in parallel
//! with semaphore-based concurrency limiting.

use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;

use tokio::sync::Semaphore;
use tokio::task::JoinSet;

/// Parallel executor with concurrency limiting.
pub struct ParallelExecutor {
    /// Maximum concurrent tasks.
    max_concurrent: usize,
    /// Semaphore for concurrency control.
    semaphore: Arc<Semaphore>,
}

impl ParallelExecutor {
    /// Creates a new executor with the specified concurrency limit.
    pub fn new(max_concurrent: usize) -> Self {
        Self {
            max_concurrent,
            semaphore: Arc::new(Semaphore::new(max_concurrent)),
        }
    }

    /// Creates an executor with default concurrency (4).
    pub fn with_default() -> Self {
        Self::new(4)
    }

    /// Runs multiple cell tasks in parallel with concurrency limiting.
    pub async fn run_cells<C, F, R>(&self, cells: C) -> Vec<Result<R, String>>
    where
        C: IntoIterator<Item = F>,
        F: FnOnce() -> R + Send + 'static,
        R: Send + 'static,
    {
        let mut set = JoinSet::new();
        let semaphore = self.semaphore.clone();

        for cell in cells {
            let sem = semaphore.clone();
            set.spawn(async move {
                let _permit = sem.acquire().await.expect("Semaphore closed");
                cell()
            });
        }

        let mut results = Vec::new();
        while let Some(result) = set.join_next().await {
            match result {
                Ok(r) => results.push(Ok(r)),
                Err(e) => results.push(Err(e.to_string())),
            }
        }

        results
    }

    /// Runs multiple futures in parallel with concurrency limiting.
    pub async fn run_futures<F, R>(
        &self,
        futures: Vec<Pin<Box<dyn Future<Output = R> + Send>>>,
    ) -> Vec<R>
    where
        R: Send + 'static,
    {
        let mut set = JoinSet::new();
        let semaphore = self.semaphore.clone();

        for future in futures {
            let sem = semaphore.clone();
            set.spawn(async move {
                let _permit = sem.acquire().await.expect("Semaphore closed");
                future.await
            });
        }

        let mut results = Vec::new();
        while let Some(result) = set.join_next().await {
            if let Ok(r) = result {
                results.push(r);
            }
        }

        results
    }

    /// Returns the maximum concurrent task limit.
    pub fn max_concurrent(&self) -> usize {
        self.max_concurrent
    }
}

impl Default for ParallelExecutor {
    fn default() -> Self {
        Self::with_default()
    }
}

/// Runs tasks in parallel with the specified concurrency limit.
pub async fn run_parallel<F, R>(tasks: Vec<F>, max_concurrent: usize) -> Vec<Result<R, String>>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    let executor = ParallelExecutor::new(max_concurrent);
    executor.run_cells(tasks).await
}

/// Runs tasks sequentially (for compatibility).
pub async fn run_sequential<F, R>(tasks: Vec<F>) -> Vec<R>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    let mut results = Vec::new();
    for task in tasks {
        results.push(task());
    }
    results
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_parallel_execution() {
        let executor = ParallelExecutor::new(2);

        let results = executor
            .run_cells(vec![
                || {
                    std::thread::sleep(std::time::Duration::from_millis(10));
                    1
                },
                || {
                    std::thread::sleep(std::time::Duration::from_millis(10));
                    2
                },
                || {
                    std::thread::sleep(std::time::Duration::from_millis(10));
                    3
                },
            ])
            .await;

        assert_eq!(results.len(), 3);
        assert!(results.iter().all(|r| r.is_ok()));
    }

    #[tokio::test]
    async fn test_sequential_execution() {
        let results = run_sequential(vec![|| 1, || 2, || 3]).await;

        assert_eq!(results, vec![1, 2, 3]);
    }

    #[test]
    fn test_parallel_executor_default() {
        let executor = ParallelExecutor::default();
        assert_eq!(executor.max_concurrent(), 4);
    }

    #[test]
    fn test_parallel_executor_new() {
        let executor = ParallelExecutor::new(8);
        assert_eq!(executor.max_concurrent(), 8);
    }
}
