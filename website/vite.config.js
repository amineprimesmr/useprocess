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

      async function sendHtml(file, req, res, next) {
        try {
          const html = readFileSync(join(root, file), "utf-8");
          const transformed = await server.transformIndexHtml(`/${file}`, html, req.originalUrl);
          res.setHeader("Content-Type", "text/html; charset=utf-8");
          res.setHeader("Cache-Control", "no-store");
          res.end(transformed);
        } catch (error) {
          next(error);
        }
      }

      server.middlewares.use(async (req, res, next) => {
        if (req.method !== "GET" || req.url == null) return next();
        const path = req.url.split("?")[0];
        if (path === "/studio" || path === "/studio.html") {
          res.statusCode = 308;
          res.setHeader("Location", "https://scrollshow.io");
          res.end();
          return;
        }
        if (path === "/affiliate" || path === "/affiliate.html") {
          return sendHtml("affiliate.html", req, res, next);
        }
        return next();
      });

      return () => {
        server.middlewares.use(async (req, res, next) => {
          if (req.method !== "GET" || req.url == null) return next();
          const path = req.url.split("?")[0];
          if (path.includes(".") && !path.endsWith(".html")) return next();
          if (path.startsWith("/src/") || path.startsWith("/@") || path.startsWith("/node_modules") || path.startsWith("/assets/")) {
            return next();
          }
          if (["/cgu", "/confidentialite", "/mentions-legales", "/support", "/sources-sante"].some((p) => path === p || path.startsWith(p + "/"))) {
            return next();
          }
          if (path === "/studio" || path === "/studio.html") {
            res.statusCode = 308;
            res.setHeader("Location", "https://scrollshow.io");
            res.end();
            return;
          }
          if (path === "/affiliate" || path === "/affiliate.html") {
            return sendHtml("affiliate.html", req, res, next);
          }
          return sendHtml("index.html", req, res, next);
        });
      };
    },
  };
}

export default defineConfig({
  appType: "spa",
  plugins: [react({ fastRefresh: false }), tailwindcss(), spaFallback()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: join(__dirname, "index.html"),
        affiliate: join(__dirname, "affiliate.html"),
      },
    },
  },
  server: {
    port: 5173,
    strictPort: false,
    host: "127.0.0.1",
    headers: {
      "Cache-Control": "no-store",
    },
  },
});
