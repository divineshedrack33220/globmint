# GlobMint — Marketing Landing Page

A single-page, dark-themed marketing site for [GlobMint](https://globmint.com):
self-custodial USDC savings on Ethereum. Built with **Next.js 14 (App Router)**,
**TypeScript**, **Tailwind CSS**, **shadcn/ui**, and **Framer Motion**.
Deploy-ready for Vercel.

The page sits in front of the GlobMint mobile app (Flutter), which is live on
the **Sepolia testnet** and staged for **Base / Ethereum / Arbitrum / Optimism**
mainnet.

## Stack

- Next.js 14 App Router, fully server-rendered static output
- TypeScript, strict mode
- Tailwind CSS 3.4 with the GlobMint brand tokens as named colors
- shadcn/ui primitives (Button, Card, Input, Accordion)
- Framer Motion for section reveals, mounts, hovers, and the vault-tree draw
- `next/font/google` — Inter (sans) + Space Grotesk (display) +
  JetBrains Mono (mono), all self-hosted
- Hand-rolled particle canvas (no animation libs for the background)
- Generated OpenGraph image (`next/og`, nodejs runtime) — real logo embedded;
  no external assets anywhere

## Layout model

- `#snap-scroller` is a `100dvh` container with `overflow-y: scroll` and
  `scroll-snap-type: y mandatory` on **desktop (≥768px)**: every section is
  exactly one viewport (`min-h-[100dvh]`, `scroll-snap-align: start`,
  `scroll-snap-stop: always`, `overflow: hidden`) — no peeking, nothing bleeds.
- **Mobile (<768px)** uses `y proximity` instead: several sections are taller
  than a viewport (stacked cards, vault diagram), and mandatory snap would
  trap the user at a section's top. Proximity lets you rest anywhere.
- `.snap-section-relaxed` (used by the vault tree) opts a section out of being
  a snap target below `md`; on desktop it snaps normally.
- A fixed dot nav (`dot-nav.tsx`) jumps between sections and writes the URL
  fragment via `history.replaceState` (no history spam). A top brand progress
  bar (`scroll-progress.tsx`) fills with scroll position.
- All motion respects `prefers-reduced-motion`: framer variants render at
  final state, ScrollTop animations become `auto`, and the particle field
  draws one static frame.

## Brand tokens — single source of truth

`lib/theme.ts` **mirrors `lib/core/theme/app_colors.dart` in the Flutter app
and must not be edited independently.** If the Flutter palette changes, update
that file and rebuild this page. No hardcoded hex lives in any component —
derive every color/radius/shadow from this module.

Real palette (do not invent): brand `#D6FB57`, backgrounds `#080808`/
`#000000`, surfaces `#111111`/`#181818`/`#202020`/`#0D0D0D`, text `#FFFFFF`/
`#A3A3A3`/`#737373`/`#4D4D4D`, borders `#242424`/`#333333`/`#1A1A1A`/`#1C1C1C`,
status success `#22C55E` / warning `#F59E0B` / destructive `#EF4444` /
info `#60A5FA`. Radius: sm 8 / md 12 / lg 16 / xl 20 / xxl 24 / full.

`tailwind.config.ts` turns them into utilities (`brand`, `ink`, `text`,
`border`, `bg-*`, `shadow-brand`, etc.). The brand logo is the real
`assets/images/logo.png` (copied to `public/logo.png`, inlined into the
OpenGraph image and used as `/icon.png`) — never invent an SVG mark.

## Project structure

```
app/
  layout.tsx             # fonts (Inter, Space Grotesk, JetBrains Mono), metadata
  page.tsx               # snap shell (#snap-scroller) + overlay composition
  globals.css            # snap utilities, themed scrollbar, reduced-motion
  opengraph-image.tsx    # at-request OG PNG (1200×630, theme + real logo)
  api/waitlist/route.ts  # waitlist capture endpoint (POST)
  components/
    section.tsx          # Section shell: 100dvh snap viewport + Reveal wrapper
    reveal.tsx           # framer fade+slide entry (respects reduced motion)
    particle-field.tsx   # canvas constellation behind everything (area-based)
    scroll-progress.tsx  # top brand progress bar, reads #snap-scroller
    dot-nav.tsx          # right-edge section dots + replaceState fragments
    hero.tsx             # real logo (soft static glow) + headline + CTAs + form
    problem.tsx          # four scroll-fade lines
    how-it-works.tsx     # 1-2-3 cards (staggered, hover lift)
    vault-section.tsx    # section wrapper (intro + closing line)
    vault-tree.tsx       # THE funds-flow diagram (SVG desktop / stack mobile)
    features.tsx         # 3×2 feature grid, lime outline icons
    security-note.tsx    # plain-language security card
    pricing.tsx          # one-panel pricing
    built-on.tsx         # Sepolia live / mainnet staged + chain glyphs
    faq.tsx              # shadcn Accordion (hover lime), keyboard-navigable
    footer.tsx           # logo + links + honest legal small print
    waitlist-form.tsx    # client form → POST /api/waitlist
    logo-mark.tsx        # real /logo.png rendered as a circle (Flutter-like)
    ui/                  # shadcn/ui primitives
lib/
  theme.ts               # SINGLE source of truth (mirrors app_colors.dart)
  sections.ts            # section id/label registry (dots + hashes)
```

## Local development

```bash
# from this directory
npm install
npm run dev
# open http://localhost:3000
```

Other scripts:

```bash
npm run build     # production build
npm start         # serve the production build
npm run lint      # Next.js lint (workspace)
npm run typecheck # tsc --noEmit
```

## Waitlist endpoint

`POST /api/waitlist` with a JSON body:

```json
{ "email": "you@example.com" }
```

- Returns `201`-style `{ ok: true }` on success (validated, lowercased).
- Duplicate emails are ignored.
- Rows persist to `data/waitlist.json` (gitignored) so local runs keep a list.
  That file is ephemeral on Vercel — for production, wire the route to your
  database, Resend broadcast, or Airtable API instead. The handler is
  deliberately isolated so a storage failure never breaks the visitor's submit.

## VaultTree

`app/components/vault-tree.tsx` is the centerpiece. It renders the funds-flow
diagram:

1. **Desktop (≥768px):** a single scalable SVG scene (`viewBox 1000×548`)
   that fills the section's content column (`max-w-[1100px]` container) —
   sender cards (`YOU`, `ANYONE` up top), your clone vault, the ownerless
   `GLOBMINT VAULT CONTRACT`, and the three safety layers
   (`PIN + 2FA`, `24h time-lock`, `Recovery address`). Each physical label
   keeps a floor on screen because the whole scene scales from one viewBox:
   card titles ≥14px, body ≥12px, connection labels ≥12px. Sizing hierarchy:
   the two anchor cards are ~1.4× the top cards' height, and the badges are
   the smallest cards (still ≥100px tall / ≥180px wide) so the eye lands on
   the contract last. The section (`.snap-section-relaxed`) is fine-tuned so
   the whole tree fits exactly one 1280×800 viewport with no internal scroll.
2. **Connector animation:** flow lines self-draw top-to-bottom via framer
   `pathLength` (1.2s each, staggered: YOU→vault, then anyone→contract, then
   vault→contract, then contract→badges). Arrowheads appear as each branch
   finishes; when the lines are done the contract pulses once and settles to
   a rest glow, and the badges fade in one by one. Calm, once, no flash. On
   `prefers-reduced-motion` the whole scene renders fully static.
3. **Mobile (<768px / low width):** the same content collapses into a stacked
   card list (`vault-tree-mobile.tsx`) with arrow separators; the three
   safety badges become a simple list below. The section relaxes its snap so
   the tall diagram can scroll naturally.
4. All SVG colors/opacities come from `lib/theme.ts`.

## Testing motion / reduced motion

With the dev/prod server running:

- Desktop (1440×900): every section should snap to exactly 900px; dot nav on
  the right updates the hash; the progress bar reaches 100% at the footer.
- Mobile (375×667): page scrolls freely; vault tree scrolls through its whole
  height (no snap trap).
- DevTools → Rendering → `emulate prefers-reduced-motion: reduce`: no particles
  drift (single static frame), sections render instantly, dot-nav jumps
  instantly.

## Deploy to Vercel

1. Push the `landing/` directory to a repo (or import it as a standalone
   project).
2. In Vercel, **Import Project** → framework preset **Next.js** is auto-detected
   (`vercel.json` pins it explicitly).
3. No environment variables are required for the marketing page itself.
4. Deploy. The build runs `next build`; the page is fully static
   (`/` is `○ Static`), with `/api/waitlist` + `/opengraph-image` as the only
   dynamic routes.

Optional (production waitlist): set any storage-crew env vars your waitlist
integration needs via `vercel env add`.

## A note on copy

All marketing copy is honest and specific. No fake social proof, no "the
future of," no hype words. The product says what it is: live on Sepolia,
mainnet imminent, USDC-only for now, self-custodial, no KYC, no seizure. The
fee is disclosed in plain numbers (`0.2%`, min ₦10, max ₦100). If the copy
here diverges from the product, the product wins — update this page to match
reality.

## Legal

`GlobMint` is a self-custodial software product — not a bank, money
transmitter, or financial advisor. The footer carries the full plain-English
disclaimer and the `/privacy` and `/terms` links point to their real pages in
production.