import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    passWithNoTests: true,
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          bindings: {
            ANTHROPIC_API_KEY: "test-anthropic-key",
            DEVICE_TOKEN: "test-device-token",
          },
        },
      },
    },
  },
});
