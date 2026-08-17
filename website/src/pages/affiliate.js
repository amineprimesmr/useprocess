import { applySiteDocumentLanguage, appCopy } from "../features/app-copy.js";

export default {
  async init() {
    applySiteDocumentLanguage();
    document.title = appCopy("Process — Portail créateur", "Process — Creator portal");
    const { mountAffiliate } = await import("../affiliate/mount.jsx");
    mountAffiliate();
  },
};
