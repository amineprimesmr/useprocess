import { getGetAppPageHtml } from "../features/get-app-page.js";
import { mountGetAppPage } from "../features/get-app-mount.js";

export default {
  async init() {
    const el = document.getElementById("landing-legal-content");
    if (el) el.innerHTML = getGetAppPageHtml();
    await mountGetAppPage();
  },
};
