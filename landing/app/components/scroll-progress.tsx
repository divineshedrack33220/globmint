"use client";

import * as React from "react";

import { theme } from "@/lib/theme";

/**
 * A thin brand progress bar fixed to the top of the viewport that fills as
 * the user scrolls through sections.
 */
export function ScrollProgress() {
  const [progress, setProgress] = React.useState(0);

  React.useEffect(() => {
    const scroller = document.querySelector<HTMLElement>("#snap-scroller");
    if (!scroller) return;
    const snapped = scroller;

    let ticking = false;
    function update() {
      ticking = false;
      const max = snapped.scrollHeight - snapped.clientHeight;
      const value = snapped.scrollTop / (max || 1);
      setProgress(Math.max(0, Math.min(1, value)));
    }

    function onScroll() {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    }

    update();
    snapped.addEventListener("scroll", onScroll, { passive: true });
    return () => snapped.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed inset-x-0 top-0 z-50 h-[3px]"
    >
      <div
        className="h-full w-full origin-left bg-brand transition-transform duration-150 ease-out"
        style={{
          transform: `scaleX(${progress})`,
          boxShadow: `0 0 12px ${theme.colors.primaryGlow}`,
        }}
      />
    </div>
  );
}