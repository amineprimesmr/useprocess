import { runLiquidGlassMenuCleanupLanding } from "../features/kube-liquid-glass/liquid-glass-menu-dispose.js";
import { applyNotFoundCopy } from "../features/site-chrome.js";
import { applySiteDocumentLanguage } from "../features/app-copy.js";

export function getRoute() {
  const path = window.location.pathname.replace(/\/$/, "");
  const host = window.location.hostname.toLowerCase();
  const params = new URLSearchParams(window.location.search || "");

  const hasReferral = Boolean(params.get("ref") || params.get("code"));
  const hasUtm = Boolean(
    params.get("utm_source") ||
      params.get("utm_campaign") ||
      params.get("source") ||
      params.get("campaign")
  );
  const wantsGetApp = params.get("get") === "1" || hasReferral || hasUtm;

  if (host === "join.useprocess.xyz" || host === "get.useprocess.xyz") {
    return { type: "get-app" };
  }
  if (
    path === "/clipping" ||
    path === "/clipping.html" ||
    path === "/affiliate" ||
    path === "/affiliate.html"
  ) {
    return { type: "affiliate" };
  }
  if (
    path === "/app" ||
    path === "/get" ||
    path === "/i" ||
    path === "/a" ||
    path === "/telecharger" ||
    /^\/join\/[^/]+$/i.test(path) ||
    /^\/c\/[^/]+$/i.test(path) ||
    wantsGetApp
  ) {
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
    pageAffiliate: document.getElementById("page-affiliate"),
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
  document.body.classList.toggle("page-affiliate", route.type === "affiliate");
  document.documentElement.classList.toggle("page-affiliate", route.type === "affiliate");

  if (route.type !== "landing") {
    runLiquidGlassMenuCleanupLanding();
  }

  if (c.page404) c.page404.classList.add("hidden");
  if (c.pageAffiliate) {
    c.pageAffiliate.classList.add("hidden");
    c.pageAffiliate.setAttribute("aria-hidden", "true");
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

  if (route.type === "affiliate") {
    if (c.landing) c.landing.classList.add("hidden");
    if (c.pageAffiliate) {
      c.pageAffiliate.classList.remove("hidden");
      c.pageAffiliate.setAttribute("aria-hidden", "false");
    }
    const page = await loadPage("affiliate");
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
