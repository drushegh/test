# Node Backend Patterns

## Process-Level Error Handling

Unhandled rejections and uncaught exceptions leave the process in an
unknown state — log and shut down cleanly rather than limping on:

```typescript
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled rejection:", reason);
  shutdown("unhandledRejection", 1);   // a crash must exit non-zero
});
process.on("uncaughtException", (err) => {
  console.error("Uncaught exception:", err);
  shutdown("uncaughtException", 1);
});

function shutdown(reason: string, exitCode = 0) {
  console.log(`Received ${reason}, shutting down...`);
  server.close(() => {
    db.destroy().finally(() => process.exit(exitCode));
  });
  setTimeout(() => process.exit(1), 10_000).unref();   // force-exit if close hangs
}
```

Stop accepting connections first, drain in-flight requests, close DB pools,
then exit — with a hard timeout so a stuck connection can't block shutdown
forever.

## Async Errors in Express

Express 4 does not catch rejected promises from async handlers — they
become unhandled rejections. Wrap them (Express 5 and Fastify handle this
natively):

```typescript
const asyncHandler =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<void>) =>
  (req: Request, res: Response, next: NextFunction) =>
    fn(req, res, next).catch(next);

app.get("/users/:id", asyncHandler(async (req, res) => {
  const user = await userService.getById(req.params.id);
  if (!user) {
    res.status(404).json({ error: "Not found" });
    return;
  }
  res.json(user);
}));
```

## Layering

Route handlers stay thin: parse/validate input (Zod), call a service,
shape the response. Business logic lives in services; data access in
repositories. This keeps logic testable without HTTP plumbing.

```typescript
// route: validation + orchestration only
app.post("/users", asyncHandler(async (req, res) => {
  const input = CreateUserSchema.parse(req.body);
  const user = await userService.create(input);
  res.status(201).json(user);
}));
```

## Centralised Error Handler

One error middleware maps domain errors to HTTP responses — consistent
shape, no stack traces to clients, full logging server-side:

```typescript
app.use((err: unknown, req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof ValidationError) {
    res.status(400).json({ code: "VALIDATION", message: err.message });
    return;
  }
  if (err instanceof NotFoundError) {
    res.status(404).json({ code: "NOT_FOUND", message: err.message });
    return;
  }
  logger.error({ err, path: req.path }, "Unhandled error");
  res.status(500).json({ code: "INTERNAL", message: "An unexpected error occurred" });
});
```

## Child Processes on Windows

`spawn(cmd, { shell: true })` on Windows starts `cmd.exe`, and
`child.kill()` kills only that shell — the real process (a dev server, a
preview server) survives and keeps its port. Kill the tree:
`spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"])`, or avoid
`shell: true` and spawn the executable directly (resolve `.cmd` shims
explicitly, and never pass untrusted arguments through a shell).

## Other Essentials

- Validate `process.env` at startup with Zod (see validation-and-apis.md).
- Use the `node:` import protocol for built-ins:
  `import { readFile } from "node:fs/promises"`.
- Structured logging (pino or similar) with request context, not bare
  `console.log`.
- Top-level await is available in ESM — use it for startup initialisation
  rather than `.then()` chains.
