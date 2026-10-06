"use client";

import * as React from "react";
import { motion, useReducedMotion } from "framer-motion";

import { theme } from "@/lib/theme";

/**
 * The vault tree — desktop. A single scalable SVG of the funds flow, drawn in
 * one viewBox ("0 0 1000 680") and scaled to fill the section with
 * `preserveAspectRatio="xMidYMid meet"`, so every label keeps a physical
 * floor on screen (titles ≥14px, body ≥12px, connection labels ≥12px with
 * ≥8px arrow/line clearance).
 *
 * Layout: two small sender cards up top (YOU / ANYONE, ≥120px apart) both feed
 * the tall clone-vault card (≈1.4× the top cards' height), which feeds the
 * ownerless contract card below it, which then fans out to the three safety
 * badges (smallest cards, still ≥100px tall / ≥180px wide). The vertical line
 * from the contract to the badges has a visible break where the "vault has no
 * owner" sentence sits alongside it.
 *
 * Motion: each branch draws itself over 1.2s (pathLength), staggered
 * top-left → top-right → vault → badges. When the lines finish the contract
 * pulses once and settles to a rest glow; the badges fade in one by one.
 * prefers-reduced-motion shows the fully static tree.
 */
export function VaultTree() {
  const reduce = useReducedMotion();

  const lineProps = {
    fill: "none" as const,
    stroke: theme.colors.primary,
    strokeOpacity: 0.5,
    strokeWidth: 1.6,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    pathLength: 1,
  };

  const lineVariants = {
    hidden: { pathLength: reduce ? 1 : 0, opacity: reduce ? 1 : 0 },
    visible: (delay: number) => ({
      pathLength: 1,
      opacity: 1,
      transition: {
        pathLength: { duration: 1.2, ease: EASE, delay },
        opacity: { duration: 0.3, ease: EASE, delay },
      },
    }),
  };

  const arrowVariants = {
    hidden: { opacity: reduce ? 1 : 0 },
    visible: (delay: number) => ({
      opacity: 1,
      transition: { duration: 0.25, ease: EASE, delay: delay + 0.9 },
    }),
  };

  const badgeVariants = {
    hidden: { opacity: reduce ? 1 : 0, y: reduce ? 0 : 10 },
    visible: (delay: number) => ({
      opacity: 1,
      y: 0,
      transition: { duration: 0.4, ease: EASE, delay },
    }),
  };

  const viewport = { once: true as const, margin: "-20% 0px -20% 0px" };

  const badges = [
    { title: "PIN + 2FA", lines: ["protects", "your session"] },
    { title: "24h time-lock", lines: ["protects large", "withdrawals"] },
    {
      title: "Recovery address",
      lines: ["(opt-in) protects", "you if you", "lose your key"],
    },
  ];

  return (
    <div
      className="relative mx-auto w-full max-w-[920px]"
      style={{ aspectRatio: "1000 / 680" }}
    >
      <svg
        viewBox="0 0 1000 680"
        width="100%"
        height="100%"
        preserveAspectRatio="xMidYMid meet"
        role="img"
        aria-label="Funds flow: you and anyone can move USDC into your clone vault address, deployed deterministically via CREATE2, held by an ownerless GlobMint vault contract, protected by your PIN and 2FA, a 24-hour time lock, and an optional recovery address."
        className="block"
      >
        <title>
          Funds flow: you and anyone move USDC into your clone vault, held by
          an ownerless contract, protected by PIN + 2FA, a 24h time-lock, and
          an optional recovery address.
        </title>

        <desc>
          Two senders (you and anyone) at the top both feed the clone vault,
          which feeds the ownerless GlobMint contract in the middle; the
          contract then fans out to three safety layers below. The vault has no
          owner, no admin, and no pause.
        </desc>

        <style>{`
            g.badge rect.badge-fill { transition: fill 0.3s ease; }
            g.badge:hover rect.badge-fill { fill: ${theme.colors.primaryOverlay}; }
          `}</style>

        <defs>
          <filter
            id="vault-glow-rest"
            x="-40%"
            y="-40%"
            width="180%"
            height="180%"
          >
            <feDropShadow
              dx="0"
              dy="0"
              stdDeviation="12"
              floodColor={theme.colors.primary}
              floodOpacity="0.15"
            />
          </filter>
          <filter
            id="vault-glow-pulse"
            x="-40%"
            y="-40%"
            width="180%"
            height="180%"
          >
            <feDropShadow
              dx="0"
              dy="0"
              stdDeviation="22"
              floodColor={theme.colors.primary}
              floodOpacity="0.6"
            />
          </filter>
        </defs>

        <g>
          {/* ---------- Branch A: YOU → clone vault (delay 0.2) ---------- */}
          <motion.path
            {...lineProps}
            d="M170 128 L170 192"
            variants={lineVariants}
            custom={0.2}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.g
            stroke={theme.colors.primary}
            strokeOpacity="0.6"
            fill="none"
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
            variants={arrowVariants}
            custom={0.2}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          >
            <path d="M163 185 L170 192 L163 199" />
          </motion.g>
          <text x="186" y="152" fill={theme.colors.textSecondary} fontSize="13">
            withdraw signed
          </text>
          <text x="186" y="170" fill={theme.colors.textSecondary} fontSize="13">
            by your wallet (EIP-712)
          </text>

          {/* ---------- Branch B: ANYONE → clone vault (delay 1.6) ---------- */}
          <motion.path
            {...lineProps}
            d="M830 128 L830 192"
            variants={lineVariants}
            custom={1.6}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.g
            stroke={theme.colors.primary}
            strokeOpacity="0.6"
            fill="none"
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
            variants={arrowVariants}
            custom={1.6}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          >
            <path d="M823 185 L830 192 L823 199" />
          </motion.g>
          <text
            x="814"
            y="152"
            textAnchor="end"
            fill={theme.colors.textSecondary}
            fontSize="13"
          >
            deposit USDC
          </text>
          <text
            x="814"
            y="170"
            textAnchor="end"
            fill={theme.colors.textSecondary}
            fontSize="13"
          >
            (no wallet link needed)
          </text>

          {/* ---------- Branch C: clone vault → contract (delay 3.0) ---------- */}
          <motion.path
            {...lineProps}
            d="M500 326 L500 372"
            variants={lineVariants}
            custom={3}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.g
            stroke={theme.colors.primary}
            strokeOpacity="0.6"
            fill="none"
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
            variants={arrowVariants}
            custom={3}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          >
            <path d="M493 365 L500 372 L493 379" />
          </motion.g>

          {/* ---------- Branch D: contract → badges, broken by the sentence
                 (delay 4.4) ---------- */}
          <motion.path
            {...lineProps}
            d="M220 506 L220 512"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M500 506 L500 512"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M780 506 L780 512"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M220 512 L780 512"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M220 512 L220 560"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M500 512 L500 560"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          <motion.path
            {...lineProps}
            d="M780 512 L780 560"
            variants={lineVariants}
            custom={4.4}
            initial="hidden"
            whileInView="visible"
            viewport={viewport}
          />
          {[220, 500, 780].map((cx) => (
            <motion.g
              key={`arrow-${cx}`}
              stroke={theme.colors.primary}
              strokeOpacity="0.6"
              fill="none"
              strokeWidth="1.4"
              strokeLinecap="round"
              strokeLinejoin="round"
              variants={arrowVariants}
              custom={4.4}
              initial="hidden"
              whileInView="visible"
              viewport={viewport}
            >
              <path d={`M${cx - 7} 553 L${cx} 560 L${cx + 7} 553`} />
            </motion.g>
          ))}

          <text
            x="764"
            y="522"
            textAnchor="end"
            fill={theme.colors.textSecondary}
            fontSize="13"
          >
            the vault has no owner. no admin. no pause.
          </text>
          <text
            x="764"
            y="542"
            textAnchor="end"
            fill={theme.colors.textSecondary}
            fontSize="13"
          >
            no way for us to touch it.
          </text>

          {/* ---------- Top cards ---------- */}
          <g>
            <rect
              x="40"
              y="32"
              width="260"
              height="96"
              rx={theme.radius.lg}
              fill={theme.colors.surfaceElevated}
              stroke={theme.colors.primary}
              strokeWidth="1"
            />
            <text
              x="170"
              y="66"
              textAnchor="middle"
              fill={theme.colors.textPrimary}
              fontSize="15"
              fontWeight="600"
              letterSpacing="-0.01em"
            >
              YOU
            </text>
            <text
              x="170"
              y="90"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              (your wallet)
            </text>
            <text
              x="170"
              y="112"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              signs every withdrawal
            </text>
          </g>

          <g>
            <rect
              x="700"
              y="32"
              width="260"
              height="96"
              rx={theme.radius.lg}
              fill={theme.colors.surfaceElevated}
              stroke={theme.colors.primary}
              strokeWidth="1"
            />
            <text
              x="830"
              y="66"
              textAnchor="middle"
              fill={theme.colors.textPrimary}
              fontSize="15"
              fontWeight="600"
              letterSpacing="-0.01em"
            >
              ANYONE
            </text>
            <text
              x="830"
              y="90"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              friend, exchange, new wallet
            </text>
            <text
              x="830"
              y="112"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              no wallet link required
            </text>
          </g>

          {/* ---------- Clone vault anchor (tall, 1.4×) ---------- */}
          <g>
            <rect
              x="140"
              y="192"
              width="720"
              height="134"
              rx={theme.radius.lg}
              fill={theme.colors.surfaceElevated}
              stroke={theme.colors.primary}
              strokeWidth="1"
            />
            <rect
              x="140"
              y="192"
              width="720"
              height="32"
              rx={theme.radius.lg}
              fill={theme.colors.primaryOverlay}
            />
            <rect
              x="140"
              y="208"
              width="720"
              height="16"
              fill={theme.colors.primaryOverlay}
            />
            <text
              x="500"
              y="218"
              textAnchor="middle"
              fill={theme.colors.primary}
              fontSize="15"
              fontWeight="600"
              fontFamily="var(--font-jetbrains-mono), monospace"
              letterSpacing="0.02em"
            >
              YOUR CLONE VAULT ADDRESS
            </text>
            <text
              x="500"
              y="264"
              textAnchor="middle"
              fill={theme.colors.textPrimary}
              fontSize="15"
              fontWeight="600"
              letterSpacing="-0.01em"
              fontFamily="var(--font-jetbrains-mono), monospace"
            >
              one address, yours alone
            </text>
            <text
              x="500"
              y="294"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              deployed deterministically via CREATE2
            </text>
          </g>

          {/* ---------- Ownerless contract anchor ---------- */}
          <g>
            <motion.rect
              x="140"
              y="372"
              width="720"
              height="134"
              rx={theme.radius.lg}
              fill={theme.colors.surfaceElevated}
              stroke={theme.colors.primary}
              strokeWidth="2"
              filter="url(#vault-glow-rest)"
            />
            <motion.rect
              x="140"
              y="372"
              width="720"
              height="134"
              rx={theme.radius.lg}
              fill="none"
              stroke={theme.colors.primary}
              strokeWidth="2"
              filter="url(#vault-glow-pulse)"
              initial={{ opacity: 0 }}
              whileInView={{
                opacity: [0, 0.85, 0],
                transition: {
                  duration: 0.9,
                  times: [0, 0.35, 1],
                  ease: EASE,
                  delay: 5.9,
                },
              }}
              viewport={viewport}
              style={reduce ? { opacity: 0 } : undefined}
            />
            <rect
              x="140"
              y="372"
              width="720"
              height="32"
              rx={theme.radius.lg}
              fill={theme.colors.primaryOverlay}
            />
            <rect
              x="140"
              y="388"
              width="720"
              height="16"
              fill={theme.colors.primaryOverlay}
            />
            <text
              x="500"
              y="400"
              textAnchor="middle"
              fill={theme.colors.primary}
              fontSize="15"
              fontWeight="600"
              fontFamily="var(--font-jetbrains-mono), monospace"
              letterSpacing="0.02em"
            >
              GLOBMINT VAULT CONTRACT
            </text>
            <text
              x="500"
              y="436"
              textAnchor="middle"
              fill={theme.colors.textPrimary}
              fontSize="15"
              fontWeight="600"
              letterSpacing="-0.01em"
              fontFamily="var(--font-jetbrains-mono), monospace"
            >
              immutable, ownerless
            </text>
            <text
              x="500"
              y="458"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              the backend relays — it can never move funds
            </text>
            <text
              x="500"
              y="478"
              textAnchor="middle"
              fill={theme.colors.textSecondary}
              fontSize="13"
            >
              you didn&#8217;t sign for
            </text>
          </g>

          {/* ---------- Safety badges ---------- */}
          {badges.map((badge, index) => {
            const cx = 220 + index * 280;
            const lineStart = badge.lines.length === 3 ? 614 : 620;
            return (
              <motion.g
                key={badge.title}
                className="badge"
                variants={badgeVariants}
                custom={5.9 + index * 0.2}
                initial="hidden"
                whileInView="visible"
                viewport={viewport}
              >
                <rect
                  className="badge-fill"
                  x={cx - 110}
                  y="560"
                  width="220"
                  height="120"
                  rx={theme.radius.lg}
                  fill={theme.colors.surfaceElevated}
                  stroke={theme.colors.primarySubtle}
                  strokeWidth="1"
                />
                <text
                  x={cx}
                  y="590"
                  textAnchor="middle"
                  fill={theme.colors.primary}
                  fontSize="15"
                  fontWeight="600"
                >
                  {badge.title}
                </text>
                {badge.lines.map((line, li) => (
                  <text
                    key={line}
                    x={cx}
                    y={lineStart + li * 20}
                    textAnchor="middle"
                    fill={theme.colors.textSecondary}
                    fontSize="13"
                  >
                    {line}
                  </text>
                ))}
              </motion.g>
            );
          })}
        </g>
      </svg>
    </div>
  );
}

const EASE = [0.22, 1, 0.36, 1] as const;