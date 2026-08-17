import { initSiteLanguage, subscribeSiteLanguage } from "./features/app-copy.js";
import { initRouting } from "./router/index.js";
import { applyLandingFooterCopy, applyNotFoundCopy, applyGetAppChromeCopy } from "./features/site-chrome.js";
import { mountCrispChat } from "./features/crisp-chat.js";

window.addEventListener("popstate", () => {
  initRouting().catch((err) => console.error("Routing error:", err));
});

async function bootstrap() {
  try {
    initSiteLanguage();
    applyLandingFooterCopy();
    applyGetAppChromeCopy();
    subscribeSiteLanguage(() => {
      applyLandingFooterCopy();
      applyGetAppChromeCopy();
      const page404 = document.getElementById("page-404");
      if (page404 && !page404.classList.contains("hidden")) {
        applyNotFoundCopy();
      }
    });
    await initRouting();
    mountCrispChat().catch(() => {});
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
