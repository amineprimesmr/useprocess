import { initSiteLanguage } from "../features/app-copy.js";
import { initSiteTheme } from "../features/site-theme.js";
import { mountLandingCinematic } from "../landing-cinematic/mount.jsx";

export default {
  init() {
    initSiteTheme();
    initSiteLanguage();
    mountLandingCinematic();
  },
};
