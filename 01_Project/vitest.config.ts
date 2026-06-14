import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    include: ["tests/**/*.test.ts"],
    // The throughput suite (scenario 5) is intentionally slow; give it room.
    testTimeout: 30_000,
  },
});
