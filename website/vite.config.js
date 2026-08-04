import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

/** SPA fallback en dev — /get, etc. */
function spaFallback() {
  return {
    name: "spa-fallback",
    apply: "serve",
    configureServer(server) {
      const root = server.config.root || __dirname;
      const handler = async (req, res, next) => {
        if (req.method !== "GET" || req.url == null) return next();
        const path = req.url.split("?")[0];
        if (path.includes(".") && !path.endsWith(".html")) return next();
        if (path.startsWith("/src/") || path.startsWith("/@") || path.startsWith("/node_modules") || path.startsWith("/assets/")) {
          return next();
        }
        if (["/cgu", "/confidentialite", "/mentions-legales", "/support", "/sources-sante"].some((p) => path === p || path.startsWith(p + "/"))) {
          return next();
        }
        try {
          const indexHtml = readFileSync(join(root, "index.html"), "utf-8");
          const transformed = await server.transformIndexHtml(path, indexHtml, req.originalUrl);
          res.setHeader("Content-Type", "text/html; charset=utf-8");
          res.end(transformed);
        } catch (e) {
          next(e);
        }
      };
      server.middlewares.use(handler);
    },
  };
}

export default defineConfig({
  appType: "spa",
  plugins: [react(), tailwindcss(), spaFallback()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  server: {
    port: 5175,
    host: "127.0.0.1",
  },
});
