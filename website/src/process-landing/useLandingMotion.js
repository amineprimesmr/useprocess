import { useEffect } from "react";

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function scrollToAnchor(id) {
  const target = document.getElementById(id);
  if (!target) return;

  const navHeight = Number.parseInt(
    getComputedStyle(document.documentElement).getPropertyValue("--fk-nav-h") || "56",
    10
  );

  const top = target.getBoundingClientRect().top + window.scrollY - navHeight - 10;
  window.scrollTo({
    top: Math.max(0, top),
    behavior: prefersReducedMotion() ? "auto" : "smooth",
  });
}

export function useSmoothAnchorScroll(rootSelector = ".fk-page") {
  useEffect(() => {
    const root = document.querySelector(rootSelector);
    if (!root) return undefined;

    const onClick = (event) => {
      const link = event.target.closest('a[href^="#"]');
      if (!link || !root.contains(link)) return;

      const hash = link.getAttribute("href");
      if (!hash || hash === "#") return;

      const id = hash.slice(1);
      const target = document.getElementById(id);
      if (!target) return;

      event.preventDefault();
      scrollToAnchor(id);
      history.pushState(null, "", `#${id}`);
    };

    root.addEventListener("click", onClick);

    if (window.location.hash.length > 1) {
      const id = window.location.hash.slice(1);
      requestAnimationFrame(() => scrollToAnchor(id));
    }

    return () => root.removeEventListener("click", onClick);
  }, [rootSelector]);
}

export function useNavScrollState(navSelector = ".fk-nav") {
  useEffect(() => {
    const nav = document.querySelector(navSelector);
    if (!nav) return undefined;

    let ticking = false;

    const update = () => {
      nav.classList.toggle("fk-nav--scrolled", window.scrollY > 10);
      ticking = false;
    };

    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(update);
    };

    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [navSelector]);
}
