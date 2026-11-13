import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      // "server-only" só existe para o bundler do Next barrar import no cliente.
      "server-only": fileURLToPath(new URL("./testes/vazio.ts", import.meta.url)),
    },
  },
  test: { include: ["testes/**/*.test.ts"] },
});
