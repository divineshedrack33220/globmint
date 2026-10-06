"use client";

import * as React from "react";

import { Reveal } from "@/app/components/reveal";
import { cn } from "@/lib/utils";

/**
 * A full-viewport snap section.
 *
 * - Exactly one viewport tall (min-h 100dvh), content vertically centered.
 * - scroll-snap-align: start + scroll-snap-stop: always, overflow hidden so
 *   nothing bleeds into the neighbouring section.
 * - `relax` is for sections that cannot fit on small screens (the vault tree
 *   with all its badges): on mobile it stays a snap target but is capped at
 *   one viewport and internal-scrolls (content is taller than the screen);
 *   on md+ it behaves like every other section.
 */
export function Section({
  id,
  children,
  className,
  label,
  relax = false,
  compact = false,
  flush = false,
}: {
  id: string;
  children: React.ReactNode;
  className?: string;
  label?: string;
  relax?: boolean;
  compact?: boolean;
  flush?: boolean;
}) {
  return (
    <section
      id={id}
      aria-label={label}
      className={cn(
        "relative flex w-full flex-col items-center pb-16 pt-20 md:min-h-[100dvh] md:justify-center md:overflow-hidden md:pb-20 md:pt-24",
        compact && "pb-10 pt-12 md:pb-12 md:pt-16",
        flush && "pb-6 pt-10 md:pb-6 md:pt-10",
        relax
          ? "snap-section h-[100dvh] justify-start overflow-y-auto md:h-auto"
          : "snap-section min-h-[100dvh] md:overflow-hidden",
        className
      )}
    >
      <Reveal className="flex w-full flex-col items-center justify-center">
        {children}
      </Reveal>
    </section>
  );
}