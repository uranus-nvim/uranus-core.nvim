//! Async task scheduling bridge to the global runtime.
#![allow(dead_code)]

use std::{pin::Pin, sync::Arc};

use tokio::sync::mpsc;

use crate::runtime::spawn;

/// Async task runner.
pub struct AsyncTask {
    /// Sender for the task channel.
    sender: mpsc::Sender<Pin<Box<dyn std::future::Future<Output = ()> + Send + 'static>>>,
}

impl AsyncTask {
    /// Creates a new async task runner.
    pub fn new() -> Self {
        let (tx, mut rx) =
            mpsc::channel::<Pin<Box<dyn std::future::Future<Output = ()> + Send + 'static>>>(100);

        let _ = spawn(async move {
            while let Some(task) = rx.recv().await {
                task.await;
            }
        });

        Self { sender: tx }
    }

    /// Schedules a future to run on the global runtime.
    pub fn schedule<F>(&self, f: F) -> Result<(), String>
    where
        F: std::future::Future<Output = ()> + Send + 'static,
    {
        let boxed: Pin<Box<dyn std::future::Future<Output = ()> + Send + 'static>> = Box::pin(f);
        self.sender.try_send(boxed).map_err(|e| e.to_string())
    }

    /// Schedules a blocking task to run on the global runtime.
    pub fn schedule_blocking<F>(&self, f: F) -> Result<(), String>
    where
        F: FnOnce() + Send + 'static,
    {
        let future = async move {
            tokio::task::spawn_blocking(f).await.ok();
        };
        self.schedule(future)
    }
}

impl Default for AsyncTask {
    fn default() -> Self {
        Self::new()
    }
}

/// Async scheduler wrapping AsyncTask.
pub struct AsyncScheduler {
    /// The async task runner.
    task: Arc<AsyncTask>,
}

impl AsyncScheduler {
    /// Creates a new async scheduler.
    pub fn new() -> Self {
        Self {
            task: Arc::new(AsyncTask::new()),
        }
    }

    /// Schedules a future to run.
    pub fn schedule<F>(&self, future: F) -> Result<(), String>
    where
        F: std::future::Future<Output = ()> + Send + 'static,
    {
        self.task.schedule(future)
    }

    /// Schedules a blocking task to run.
    pub fn schedule_blocking<F>(&self, f: F) -> Result<(), String>
    where
        F: FnOnce() + Send + 'static,
    {
        self.task.schedule_blocking(f)
    }
}

impl Default for AsyncScheduler {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_async_task_struct_size() {
        let task_size = std::mem::size_of::<AsyncTask>();
        assert!(task_size > 0);
    }

    #[test]
    fn test_async_scheduler_struct_size() {
        let scheduler_size = std::mem::size_of::<AsyncScheduler>();
        assert!(scheduler_size > 0);
    }
}
