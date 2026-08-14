import { runLiquidGlassMenuCleanupLanding } from "../features/kube-liquid-glass/liquid-glass-menu-dispose.js";
import { applyNotFoundCopy } from "../features/site-chrome.js";
import { applySiteDocumentLanguage } from "../features/app-copy.js";

export function getRoute() {
  const path = window.location.pathname.replace(/\/$/, "");
  const host = window.location.hostname.toLowerCase();
  const params = new URLSearchParams(window.location.search || "");

  const hasReferral = Boolean(params.get("ref") || params.get("code"));
  const wantsGetApp = params.get("get") === "1" || hasReferral;

  if (host === "join.useprocess.xyz") {
    return { type: "get-app" };
  }
  if (path === "/studio" || path === "/studio.html") {
    return { type: "studio" };
  }
  if (path === "/get" || path === "/telecharger" || /^\/join\/[^/]+$/i.test(path) || wantsGetApp) {
    return { type: "get-app" };
  }
  if (path === "") return { type: "landing" };
  return { type: "404" };
}

function getContainers() {
  return {
    landing: document.getElementById("landing"),
    landingMain: document.getElementById("landing-main"),
    landingLegal: document.getElementById("landing-legal"),
    legalContent: document.getElementById("landing-legal-content"),
    pageStudio: document.getElementById("page-studio"),
    page404: document.getElementById("page-404"),
  };
}

async function loadPage(routeType) {
  const mod = await import(`../pages/${routeType}.js`);
  return mod.default;
}

export async function initRouting() {
  const route = getRoute();
  const c = getContainers();

  document.body.classList.toggle("page-landing-subpage", route.type === "get-app");
  document.body.classList.toggle("page-get-app", route.type === "get-app");
  document.documentElement.classList.toggle("page-get-app", route.type === "get-app");
  document.body.classList.toggle("page-studio", route.type === "studio");
  document.documentElement.classList.toggle("page-studio", route.type === "studio");

  if (route.type !== "landing") {
    runLiquidGlassMenuCleanupLanding();
  }

  if (c.page404) c.page404.classList.add("hidden");
  if (c.pageStudio) {
    c.pageStudio.classList.add("hidden");
    c.pageStudio.setAttribute("aria-hidden", "true");
  }

  if (route.type === "404") {
    if (c.landing) c.landing.classList.add("hidden");
    if (c.page404) {
      c.page404.classList.remove("hidden");
      c.page404.setAttribute("aria-hidden", "false");
      applyNotFoundCopy();
      applySiteDocumentLanguage();
    }
    return null;
  }

  if (route.type === "studio") {
    if (c.landing) c.landing.classList.add("hidden");
    if (c.pageStudio) {
      c.pageStudio.classList.remove("hidden");
      c.pageStudio.setAttribute("aria-hidden", "false");
    }
    const page = await loadPage("studio");
    await page.init(route);
    return null;
  }

  if (route.type === "get-app" && c.landingMain && c.landingLegal) {
    if (c.landing) c.landing.classList.remove("hidden");
    if (c.landingMain) c.landingMain.classList.add("hidden");
    c.landingLegal.classList.remove("hidden");
    const page = await loadPage("get-app");
    await page.init(route);
    return null;
  }

  if (c.landing) c.landing.classList.remove("hidden");
  if (c.landingMain) c.landingMain.classList.remove("hidden");
  if (c.landingLegal) c.landingLegal.classList.add("hidden");

  applySiteDocumentLanguage();
  const page = await loadPage("landing");
  await page.init(route);
  return null;
}
