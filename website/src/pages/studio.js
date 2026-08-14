import { applySiteDocumentLanguage, appCopy } from "../features/app-copy.js";

export default {
  async init() {
    applySiteDocumentLanguage();
    document.title = appCopy(
      "Process Studio — Publier sur TikTok",
      "Process Studio — Publish to TikTok"
    );
    const { mountStudio } = await import("../studio/mount.jsx");
    mountStudio();
  },
};
