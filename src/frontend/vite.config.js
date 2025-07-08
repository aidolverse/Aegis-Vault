import { sveltekit } from "@sveltejs/kit/vite"
import { defineConfig } from "vite"
import path from "path"

export default defineConfig({
  plugins: [sveltekit()],
  define: {
    global: "globalThis",
    process: {
      env: {},
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4943",
        changeOrigin: true,
      },
    },
    fs: {
      allow: [".."],
    },
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis",
      },
    },
  },
  build: {
    target: "es2020",
    rollupOptions: {
      output: {
        manualChunks: {
          dfinity: ["@dfinity/agent", "@dfinity/auth-client", "@dfinity/principal"],
          crypto: ["crypto-js"],
        },
      },
    },
  },
  resolve: {
    alias: {
      $lib: path.resolve("./src/lib"),
      $app: path.resolve("./node_modules/@sveltejs/kit/src/runtime/app"),
    },
  },
})
