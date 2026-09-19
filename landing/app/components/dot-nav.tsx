"use client";

import * as React from "react";
import { useReducedMotion } from "framer-motion";

import { SECTIONS } from "@/lib/sections";

/**
 * Right-edge dot navigation: one dot per section. Active dot is brand lime,
 * others muted. Clicking smooth-scrolls to that section and updates the URL
 * fragment via history.replaceState.
 */
export function DotNav() {
  const reduce = useReducedMotion();
  const [activeId, setActiveId] = React.useState<string>(SECTIONS[0].id);
  const activeIdRef = React.useRef(activeId);
  activeIdRef.current = activeId;

  React.useEffect(() => {
    const scroller = document.querySelector<HTMLElement>("#snap-scroller");
    if (!scroller) return;
    const snapped = scroller;

    function currentSectionId(): string {
      const scrollTop = snapped.scrollTop + snapped.clientHeight / 2;
      let index = 0;
      let best = -Infinity;
      SECTIONS.forEach((section, i) => {
        const el = document.getElementById(section.id);
        if (!el) return;
        const top = el.offsetTop;
        if (top <= scrollTop && top > best) {
          best = top;
          index = i;
        }
      });
      return SECTIONS[index].id;
    }

    function updateHash(id: string) {
      if (window.location.hash !== `#${id}`) {
        history.replaceState(null, "", `#${id}`);
      }
    }

    let ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        ticking = false;
        const id = currentSectionId();
        if (id !== activeIdRef.current) {
          setActiveId(id);
          activeIdRef.current = id;
          updateHash(id);
        }
      });
    }

    // Restore a deep link on load.
    const initial = window.location.hash.replace("#", "");
    const initialIndex = SECTIONS.findIndex((s) => s.id === initial);
    if (initialIndex > 0) {
      const el = document.getElementById(SECTIONS[initialIndex].id);
      if (el) {
        snapped.scrollTop = el.offsetTop;
      }
      setActiveId(SECTIONS[initialIndex].id);
      activeIdRef.current = SECTIONS[initialIndex].id;
    }

    snapped.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => snapped.removeEventListener("scroll", onScroll);
  }, []);

  function goTo(id: string) {
    const el = document.getElementById(id);
    const scroller = document.querySelector<HTMLElement>("#snap-scroller");
    if (!el || !scroller) return;
    const behavior = reduce ? ("auto" as const) : ("smooth" as const);
    scroller.scrollTo({ top: el.offsetTop, behavior });
    history.replaceState(null, "", `#${id}`);
    setActiveId(id);
  }

  return (
    <nav
      aria-label="Section navigation"
      className="fixed right-4 top-1/2 z-40 hidden -translate-y-1/2 flex-col items-center gap-3 md:flex"
    >
      {SECTIONS.map((section) => {
        const active = section.id === activeId;
        return (
          <button
            key={section.id}
            type="button"
            aria-label={`Go to ${section.label}`}
            aria-current={active ? "true" : undefined}
            title={section.label}
            onClick={() => goTo(section.id)}
            className={`h-2.5 w-2.5 rounded-full transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
              active
                ? "scale-125 bg-brand shadow-[0_0_10px_rgba(214,251,87,0.6)]"
                : "bg-ink-border hover:bg-brand-subtle"
            }`}
          />
        );
      })}
    </nav>
  );
}