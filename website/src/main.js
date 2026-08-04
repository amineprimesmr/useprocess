import { initRouting } from "./router/index.js";

window.addEventListener("popstate", () => {
  initRouting().catch((err) => console.error("Routing error:", err));
});

async function bootstrap() {
  try {
    await initRouting();
  } catch (err) {
    console.error("Erreur au chargement:", err);
  } finally {
    document.documentElement.classList.remove("app-booting");
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrap);
} else {
  bootstrap();
}
