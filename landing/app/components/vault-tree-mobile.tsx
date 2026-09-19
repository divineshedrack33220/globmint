"use client";

import * as React from "react";

import { theme } from "@/lib/theme";
import { cn } from "@/lib/utils";

/**
 * The vault tree — mobile. Same content as the desktop SVG but rendered as
 * stacked cards so it reads on small screens: 16px titles, 14px body,
 * 32px row gaps, visibly taller anchor cards in the middle, and the
 * ownerless-contract glow at rest.
 */
export function VaultTreeMobile() {
  return (
    <ol className="flex list-none flex-col gap-8">
      <li>
        <FlowCard
          title="YOU"
          lines={["(your wallet)", "signs every withdrawal"]}
        />
      </li>
      <FlowArrow label="withdraw signed by your wallet (EIP-712)" />
      <li>
        <FlowCard
          title="ANYONE"
          lines={["friend, exchange, new wallet", "no wallet link required"]}
        />
      </li>
      <FlowArrow label="deposit USDC (no wallet link needed)" />
      <li>
        <FlowCard
          title="YOUR CLONE VAULT ADDRESS"
          mono
          tall
          lines={[
            "one address, yours alone",
            "deployed deterministically via CREATE2",
          ]}
        />
      </li>
      <li>
        <FlowCard
          title="GLOBMINT VAULT CONTRACT"
          mono
          tall
          glow
          lines={[
            "immutable, ownerless",
            "the backend relays — it can never move funds you didn\u2019t sign for",
          ]}
        />
      </li>

      {/*
        The sentence that breaks the desktop line: rendered here as the
        connector itself, so the "vault has no owner" statement carries the
        same weight between the contract and the safety layers.
      */}
      <FlowSentence />

      <ul className="flex list-none flex-col gap-4">
        {BADGES.map((badge) => (
          <li
            key={badge.title}
            className="rounded-[16px] border border-ink-border bg-ink-elev px-5 py-4"
          >
            <p className="text-base font-semibold text-brand">{badge.title}</p>
            <p className="mt-1 text-sm text-text-muted">
              {badge.lines.join(" ")}
            </p>
          </li>
        ))}
      </ul>
    </ol>
  );
}

type Badge = { title: string; lines: string[] };

const BADGES: Badge[] = [
  { title: "PIN + 2FA", lines: ["protects", "your session"] },
  { title: "24h time-lock", lines: ["protects large", "withdrawals"] },
  {
    title: "Recovery address",
    lines: ["(opt-in) protects", "you if you", "lose your key"],
  },
];

function FlowCard({
  title,
  lines,
  mono = false,
  tall = false,
  glow = false,
}: {
  title: string;
  lines: string[];
  mono?: boolean;
  tall?: boolean;
  glow?: boolean;
}) {
  return (
    <div
      className={cn(
        "rounded-[16px] border bg-ink-elev px-5",
        tall ? "min-h-[120px] py-5" : "min-h-[88px] py-4",
        glow
          ? "border-2 border-brand shadow-[0_0_24px_rgba(214,251,87,0.15)]"
          : "border-brand/70"
      )}
    >
      <p
        className={cn(
          "text-base font-semibold tracking-tight",
          mono ? "font-mono text-brand" : "text-text"
        )}
      >
        {title}
      </p>
      {lines.map((line) => (
        <p key={line} className="mt-1 text-sm leading-snug text-text-muted">
          {line}
        </p>
      ))}
    </div>
  );
}

function FlowArrow({ label }: { label: string }) {
  return (
    <li aria-hidden="true" className="flex flex-col">
      <p className="pl-5 text-xs text-text-muted md:hidden">
        {label}
      </p>
      <div className="mt-2 flex flex-col items-center text-brand/60">
        <svg
          viewBox="0 0 24 24"
          className="h-6 w-6 shrink-0 md:h-7 md:w-7"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
        >
          <path
            d="M12 4v16m0 0l-6-6m6 6l6-6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>
    </li>
  );
}

/**
 * The visible "break" in the line between the vault and the safety badges:
 * two short line segments with the sentence sitting alongside the gap. On
 * mobile this is the same idea as the desktop SVG — a thin divider with the
 * phrase in the middle — without needing horizontal space.
 */
function FlowSentence() {
  return (
    <li aria-hidden="true" className="flex flex-col items-center gap-3">
      <div className="h-6 w-px bg-brand/30" />
      <p className="max-w-[260px] text-balance text-center font-mono text-xs leading-relaxed text-text-muted">
        the vault has no owner. no admin. no pause.
      </p>
      <div className="h-6 w-px bg-brand/30" />
    </li>
  );
}