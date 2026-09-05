//! Own thread-bound biometric resources for a sequence of synchronous FFI calls.
//!
//! Runtime and provider construction happen on the worker, and both are dropped
//! there on shutdown. This avoids nesting or dropping an async runtime on an
//! arbitrary Flutter bridge executor thread.

use std::sync::mpsc;
use std::thread::{self, JoinHandle};

type Operation<P> = Box<dyn FnOnce(&mut P) + Send>;

pub(crate) struct BiometricWorker<P: 'static> {
    sender: Option<mpsc::Sender<Operation<P>>>,
    thread: Option<JoinHandle<()>>,
}

impl<P: 'static> BiometricWorker<P> {
    pub(crate) fn start(
        initialize: impl FnOnce() -> Result<P, String> + Send + 'static,
    ) -> Result<Self, String> {
        let (sender, receiver) = mpsc::channel::<Operation<P>>();
        let (ready_sender, ready_receiver) = mpsc::sync_channel(1);
        let thread = thread::Builder::new()
            .name("marty-biometrics".to_string())
            .spawn(move || {
                let mut provider = match initialize() {
                    Ok(provider) => provider,
                    Err(error) => {
                        let _ = ready_sender.send(Err(error));
                        return;
                    }
                };
                if ready_sender.send(Ok(())).is_err() {
                    return;
                }
                for operation in receiver {
                    operation(&mut provider);
                }
            })
            .map_err(|error| format!("Failed to start biometric worker: {error}"))?;
        match ready_receiver.recv() {
            Ok(Ok(())) => Ok(Self {
                sender: Some(sender),
                thread: Some(thread),
            }),
            result => {
                let _ = thread.join();
                Err(match result {
                    Ok(Err(error)) => error,
                    _ => "Biometric worker stopped during initialization".to_string(),
                })
            }
        }
    }

    pub(crate) fn run<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&mut P) -> T + Send + 'static,
    ) -> Result<T, String> {
        let (result_sender, result_receiver) = mpsc::sync_channel(1);
        self.sender
            .as_ref()
            .ok_or("Biometric worker is shut down")?
            .send(Box::new(move |provider| {
                let result = operation(provider);
                let _ = result_sender.send(result);
            }))
            .map_err(|_| "Biometric worker is unavailable".to_string())?;
        result_receiver
            .recv()
            .map_err(|_| "Biometric worker stopped during operation".to_string())
    }

    /// Drain accepted operations and release resources before returning.
    pub(crate) fn shutdown(mut self) -> Result<(), String> {
        self.stop()
    }

    fn stop(&mut self) -> Result<(), String> {
        self.sender.take();
        if let Some(thread) = self.thread.take() {
            thread
                .join()
                .map_err(|_| "Biometric worker panicked".to_string())?;
        }
        Ok(())
    }
}

impl<P: 'static> Drop for BiometricWorker<P> {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Barrier};

    #[test]
    fn cold_start_initializes_once_and_warm_calls_reuse_resources() {
        let initializations = Arc::new(AtomicUsize::new(0));
        let count = Arc::clone(&initializations);
        let worker = BiometricWorker::start(move || {
            count.fetch_add(1, Ordering::SeqCst);
            Ok(0usize)
        })
        .unwrap();
        for expected in 1..=10 {
            assert_eq!(
                worker
                    .run(|value| {
                        *value += 1;
                        *value
                    })
                    .unwrap(),
                expected
            );
        }
        assert_eq!(initializations.load(Ordering::SeqCst), 1);
        worker.shutdown().unwrap();
    }

    #[test]
    fn initialization_failure_preserves_the_error() {
        let result = BiometricWorker::<()>::start(|| Err("model file is invalid".to_string()));
        assert_eq!(result.err().unwrap(), "model file is invalid");
    }

    #[test]
    fn concurrent_requests_share_one_provider() {
        let worker = Arc::new(BiometricWorker::start(|| Ok(0usize)).unwrap());
        let barrier = Arc::new(Barrier::new(17));
        let mut threads = Vec::new();
        for _ in 0..16 {
            let worker = Arc::clone(&worker);
            let barrier = Arc::clone(&barrier);
            threads.push(thread::spawn(move || {
                barrier.wait();
                worker
                    .run(|value| {
                        *value += 1;
                        *value
                    })
                    .unwrap()
            }));
        }
        barrier.wait();
        let mut results: Vec<_> = threads.into_iter().map(|t| t.join().unwrap()).collect();
        results.sort();
        assert_eq!(results, (1..=16).collect::<Vec<_>>());
        let worker = Arc::try_unwrap(worker).ok().unwrap();
        worker.shutdown().unwrap();
    }

    #[test]
    fn shutdown_releases_resources_on_the_owning_thread() {
        struct Resource {
            created_on: thread::ThreadId,
            dropped: Arc<AtomicUsize>,
        }
        impl Drop for Resource {
            fn drop(&mut self) {
                assert_eq!(self.created_on, thread::current().id());
                self.dropped.fetch_add(1, Ordering::SeqCst);
            }
        }
        let dropped = Arc::new(AtomicUsize::new(0));
        let observed = Arc::clone(&dropped);
        let worker = BiometricWorker::start(move || {
            Ok(Resource {
                created_on: thread::current().id(),
                dropped: observed,
            })
        })
        .unwrap();
        assert_ne!(
            worker.run(|r| r.created_on).unwrap(),
            thread::current().id()
        );
        worker.shutdown().unwrap();
        assert_eq!(dropped.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn operation_panic_is_reported_without_hanging_the_caller() {
        let worker = BiometricWorker::start(|| Ok(())).unwrap();
        assert!(worker.run::<()>(|_| panic!("test provider panic")).is_err());
        assert!(worker.run(|_| ()).is_err());
        assert!(worker.shutdown().is_err());
    }
}
