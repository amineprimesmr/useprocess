import { createRoot } from "react-dom/client";
import { StudioApp } from "./StudioApp.jsx";

/**
 * Monte Process Studio sur #studio-root.
 */
export function mountStudio() {
  const el = document.getElementById("studio-root");
  if (!el) return;
  const existingRoot = el.__studioRoot;
  const root = existingRoot || createRoot(el);
  if (!existingRoot) el.__studioRoot = root;
  root.render(<StudioApp />);
}
