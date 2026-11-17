# IPC and Security

## The contextBridge Pattern — allowlist + typed API

Never expose `ipcRenderer` itself. Expose specific methods over explicit
channels:

```typescript
// electron/preload.ts
import { contextBridge, ipcRenderer } from "electron";

const validInvokeChannels = [
  "keychain:get", "keychain:set", "keychain:delete",
  "app:get-version", "app:get-paths",
];
const validReceiveChannels = ["auth:success", "auth:error", "update:available"];

contextBridge.exposeInMainWorld("electronAPI", {
  invoke: (channel: string, ...args: unknown[]) => {
    if (validInvokeChannels.includes(channel)) {
      return ipcRenderer.invoke(channel, ...args);
    }
    throw new Error(`Invalid channel: ${channel}`);
  },
  on: (channel: string, callback: (...args: unknown[]) => void) => {
    if (!validReceiveChannels.includes(channel)) {
      throw new Error(`Invalid channel: ${channel}`);
    }
    const subscription = (_e: Electron.IpcRendererEvent, ...args: unknown[]) =>
      callback(...args);
    ipcRenderer.on(channel, subscription);
    return () => ipcRenderer.removeListener(channel, subscription);   // unsubscribe!
  },
});
```

Higher-level alternative (jezweb style): expose a domain-shaped API
(`electronAPI.auth.startOAuth(...)`, `electronAPI.app.getVersion()`) instead of
generic invoke — smaller, self-documenting surface. Either way:

```typescript
// Global type declaration
export interface ElectronAPI { /* shape above */ }
declare global {
  interface Window { electronAPI?: ElectronAPI }
}
```

```typescript
// Renderer guard hook — app still runs in a plain browser during dev
export function useElectron() {
  const isElectron = typeof window !== "undefined" && !!window.electronAPI;
  const invoke = useCallback(async <T,>(channel: string, ...args: unknown[]): Promise<T | null> => {
    if (!isElectron) return null;
    return (await window.electronAPI!.invoke(channel, ...args)) as T;
  }, [isElectron]);
  return { isElectron, invoke };
}
```

The guard is for running the renderer in a plain browser during dev —
not a timing race: the preload runs before any page script, so
`window.electronAPI` is either there from the first render or the preload
failed (wrong path, preload threw, ESM preload under `sandbox: true`, or
an `exposeInMainWorld` name that doesn't match what the renderer reads).
Pick one global name (`electronAPI` here) and use it everywhere.

## Main-Process Handlers — validate everything

```typescript
import { ipcMain, app } from "electron";

export function registerIpcHandlers(): void {
  ipcMain.handle("keychain:get", async (_event, keyName: string) => {
    if (typeof keyName !== "string" || !ALLOWED_KEYS.has(keyName)) {
      throw new Error("Invalid key name");          // renderer is untrusted
    }
    return getCredential(keyName);
  });
  ipcMain.handle("app:get-version", () => app.getVersion());
}
```

Rules: no handler executes caller-supplied strings; no caller-controlled
file paths without normalisation + root-confinement checks; return the
minimum data needed (session → `{ user }`, not tokens).

## Credentials

Use Electron's built-in `safeStorage` (`encryptString`/`decryptString`,
backed by Keychain on macOS, DPAPI on Windows, libsecret/kwallet on
Linux — check `isEncryptionAvailable()`, and on Linux
`getSelectedStorageBackend()` for the `basic_text` fallback). `keytar`
is archived (unmaintained since 2022) — don't add it to new apps; migrate
existing uses. Pattern: persist only the safeStorage ciphertext, decrypt
in main on demand, expose get/set/delete over validated IPC. Never
plaintext files, never localStorage. electron-store's `encryptionKey` is
**not** a security control (its own docs say so) — a hardcoded key or
one derived from the machine ID (`machineIdSync()`) is recomputable by
any local process; encrypt the value with safeStorage instead.

## OAuth via Custom Protocol

```typescript
// 1. Register scheme (dev needs the exe path)
if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient("myapp", process.execPath, [process.argv[1]]);
  }
} else {
  app.setAsDefaultProtocolClient("myapp");
}

// 2. Single-instance lock — second launch delivers the callback URL
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on("second-instance", (_event, commandLine) => {
    const url = commandLine.find((arg) => arg.startsWith("myapp://"));
    if (url) handleProtocolUrl(url);
    if (mainWindow?.isMinimized()) mainWindow.restore();
    mainWindow?.focus();
  });
}
app.on("open-url", (_event, url) => handleProtocolUrl(url));   // macOS path

// 3. CSRF state: generate, PERSIST (electron-store — memory dies with the
//    process), validate on callback
ipcMain.handle("auth:start-oauth", async (_event, provider: string) => {
  const state = crypto.randomUUID();
  store.set("pendingState", state);
  await shell.openExternal(`${BACKEND_URL}/api/auth/signin/${provider}?state=${state}`);
});

function handleAuthCallback(token: string, state: string) {
  if (state !== store.get("pendingState")) {
    throw new Error("State mismatch - possible CSRF attack");
  }
  store.set("pendingState", null);
  /* exchange/persist session, then mainWindow.webContents.send("auth:success", session) */
}
```

Token expiry: check with a buffer (e.g. 5 min) and refresh — don't ship
hardcoded expiry with no refresh path. Pick ONE auth mechanism — a
half-configured auth library plus manual OAuth is a maintenance trap.

## Release Security Checklist

- [ ] `contextIsolation: true`, `nodeIntegration: false`; `sandbox: true`
      unless a documented native module forbids it
- [ ] No raw `ipcRenderer` exposure; channel allowlist enforced
- [ ] Every handler validates inputs; no arbitrary execution or path
      traversal
- [ ] Secrets in OS keychain; no hardcoded encryption keys
- [ ] OAuth state persisted + validated
- [ ] External URLs through `shell.openExternal` only; navigation
      restricted (`will-navigate`/`setWindowOpenHandler` deny by default)
- [ ] CSP configured for production
- [ ] macOS hardened runtime + signing configured
- [ ] No empty catch blocks hiding failures
