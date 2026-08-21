import { applySiteDocumentLanguage, appCopy } from "../features/app-copy.js";

export default {
  async init() {
    applySiteDocumentLanguage();
    document.title = appCopy("Process — Portail créateur", "Process — Creator portal");
    const theme = document.querySelector('meta[name="theme-color"]');
    if (theme) theme.setAttribute("content", "#ffffff");
    const { mountAffiliate } = await import("../affiliate/mount.jsx");
    mountAffiliate();
  },
};
