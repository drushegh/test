# Async Rust (tokio)

Rules of the runtime: never block >100µs without `.await` (use
`spawn_blocking`/`rayon`); know cancellation safety before using
`select!`; pick the right mutex.

## Send/Sync Essentials

`tokio::spawn` requires `Future + Send + 'static` — everything held
**across an `.await`** must be `Send`.

| Type | Send | Sync | Note |
|---|---|---|---|
| `Rc<T>` / `RefCell<T>` | ❌ / ✅ | ❌ | use `Arc` / `Mutex`, or `spawn_local` |
| `Arc<T>` | ✅* | ✅* | *only if `T: Send + Sync` — Arc doesn't add safety |
| `Mutex<T>` | ✅* | ✅* | *needs only `T: Send` |
| `RwLock<T>` | ✅* | ✅* | *Send needs only `T: Send`; Sync needs `T: Send + Sync` (stricter than Mutex) |
| `MutexGuard` | ❌ | ✅ | the root of "future is not Send" errors |

"Future cannot be sent between threads safely" → find what's held across
the await (guard, `Rc`) — scope it or replace it.

## Mutex Selection

| Mutex | Use when |
|---|---|
| `std::sync::Mutex` | Default — lock briefly, never while awaiting |
| `tokio::sync::Mutex` | You genuinely must hold across `.await` |
| `RobustMutex` (cancel-safe-futures) | Lock inside `select!` (queue-position safety) |

```rust
// ✅ scope the guard before awaiting
let value = {
    let guard = mutex.lock().unwrap_or_else(std::sync::PoisonError::into_inner);
    guard.clone()
};
do_async(value).await;
```

`std::sync::Mutex` in async has two failure modes: contended `lock()`
blocks the executor thread; holding across `.await` can deadlock (the
resuming thread may be the one waiting on the lock).

## Cancellation Safety in `select!`

Safe (no loss on cancel): `mpsc/broadcast Receiver::recv`,
`watch::changed`, `TcpListener::accept`, `AsyncRead::read`,
`StreamExt::next`, `JoinSet::join_next`.

NOT safe — data loss: `read_exact`, `read_to_end`, `read_to_string`,
`write_all`. NOT safe — queue-position loss: `tokio::sync::Mutex::lock`,
`RwLock`, `Semaphore::acquire`, `Notify::notified`.

```rust
// Priority: biased checks branches in order — shutdown never starved
tokio::select! {
    biased;
    _ = shutdown.recv() => break,
    msg = rx.recv() => handle(msg),
}
```

Don't gate `select!` branches on racy preconditions
(`if !sleep.is_elapsed()`) — let the branches themselves decide.

Two branches that both read into the same `&mut buf` fail with E0499
(mutable borrow twice) — give each branch its own buffer.

## Structured Concurrency

```rust
// JoinSet: dynamic task groups — results collected, rest aborted on drop
let mut set = tokio::task::JoinSet::new();
for job in jobs { set.spawn(run(job)); }
while let Some(res) = set.join_next().await { res??; }
```

`tokio::join!` vs `spawn`: join runs concurrently on the same task (no
`'static` needed, children cancelled with parent — prefer it); spawn for
true parallelism across cores. Never bare fire-and-forget
`tokio::spawn` — track handles via `JoinSet`/`TaskTracker` or you lose
errors and shutdown control.
A detached `JoinHandle` swallows the task's panic: the panic surfaces
only as `Err(JoinError)` when the handle is awaited, so a dropped handle
means a silently dead task.

## Blocking and CPU Work

| Workload | Tool |
|---|---|
| Blocking I/O (filesystem, diesel) | `spawn_blocking` (cannot be aborted once started) |
| CPU-bound, many tasks | `rayon` + oneshot back to async |
| Forever-running background thread | `std::thread::spawn` |

```rust
async fn parallel_sum(nums: Vec<i32>) -> i32 {
    let (send, recv) = tokio::sync::oneshot::channel();
    rayon::spawn(move || { let _ = send.send(nums.iter().sum()); });
    recv.await.expect("rayon task panicked")
}
```

## Channels vs Shared State

Channels for: isolating concerns, exclusive resource ownership, natural
message domains, shutdown signalling (closure = done). Shared state
(`Arc<Mutex>>`/atomics) for: brief infrequent access, read-heavy
(`RwLock`), counters. **Bounded channels always** — unbounded means a slow
consumer eats unlimited memory; handle the full case. Bounded cycles can
deadlock: break with `try_send` or `oneshot` replies.

Actor pattern: task owns state, `mpsc` in, `oneshot` per-request replies —
a `Clone`able handle wraps the sender.

## Timeouts and Shutdown

```rust
// Every network operation gets a timeout
match tokio::time::timeout(Duration::from_secs(5), fetch()).await {
    Ok(result) => handle(result?),
    Err(_elapsed) => handle_timeout(),
}

// Standard shutdown: CancellationToken (tokio-util), not hand-rolled AtomicBool
let token = CancellationToken::new();
let child = token.child_token();          // hierarchical cancellation
let mut tasks = tokio::task::JoinSet::new();         // tracked, not a bare tokio::spawn
tasks.spawn(async move {
    loop {
        tokio::select! {
            _ = child.cancelled() => break,
            _ = do_work() => {}
        }
    }
});
token.cancel();
while let Some(res) = tasks.join_next().await { res?; }   // wait + surface panics
```

## Async Traits

Native `async fn` in traits (1.75+) — but not dyn-compatible. For
`dyn Trait`: `async-trait` crate. For Send bounds on native form:
`fn process(&self) -> impl Future<Output = ()> + Send;`. Async closures
(1.85+): `async |x| { ... }`; accept them with `F: AsyncFn(X) -> Y` (also
`AsyncFnMut`/`AsyncFnOnce`, stable in 1.85) instead of the old
`F: Fn(X) -> Fut, Fut: Future` pair. Caveat: an `AsyncFn` bound can't yet
require the returned future to be `Send`; keep the two-parameter form
where the caller must `tokio::spawn` the result.

## Observability Gotcha

`tracing` is a facade: with no subscriber installed (e.g.
`tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init()`
in `main`, or a test-writer subscriber in tests), every event is dropped
and `RUST_LOG` does nothing. "No logs" means check the subscriber first.
