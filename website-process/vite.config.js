import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
const local = (path) => fileURLToPath(new URL(path, import.meta.url));
export default defineConfig({ plugins: [react(), tailwindcss()], build: {
 outDir: "dist", rollupOptions: { input: {main: local("./index.html"), clipping: local("./clipping.html"), affiliate: local("./affiliate.html")} }
}, server: {host: "127.0.0.1"} });
