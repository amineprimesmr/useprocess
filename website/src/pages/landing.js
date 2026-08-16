import { initSiteLanguage } from "../features/app-copy.js";
import { mountLandingCinematic } from "../landing-cinematic/mount.jsx";

export default {
  init() {
    initSiteLanguage();
    mountLandingCinematic();
  },
};
