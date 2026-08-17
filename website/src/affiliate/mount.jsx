import { createRoot } from "react-dom/client";
import { AffiliateApp } from "./AffiliateApp.jsx";

export function mountAffiliate() {
  const root = document.getElementById("affiliate-root");
  if (!root) return;
  createRoot(root).render(<AffiliateApp />);
}
