import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        // The R2 simulator's isolated-storage snapshotting has trouble
        // popping its stack across parallel test files/workers in this
        // toolchain version; single-worker mode avoids it. Fine for this
        // suite's size (a handful of fast unit tests).
        singleWorker: true,
      },
    },
  },
});
