# GlobMint — Marketing Landing Page

A single-page, dark-themed marketing site for [GlobMint](https://globmint.com):
self-custodial USDC on Ethereum. Built with **Next.js 14 (App Router)**,
**TypeScript**, **Tailwind CSS**, **shadcn/ui**, and **Framer Motion**.
Deploy-ready for Vercel or Render.

The page sits in front of the GlobMint mobile app (Flutter), which is live on
the **Sepolia testnet** and staged for **Base / Ethereum / Arbitrum / Optimism**
mainnet.

## Stack

- Next.js 14 App Router, fully server-rendered static output
- TypeScript, strict mode
- Tailwind CSS 3.4 with the GlobMint brand tokens as named colors
- shadcn/ui primitives (Button, Card, Input, Accordion)
- Framer Motion for section reveals, mounts, hovers, and the vault-tree draw
- `next/font/google` — **Inter** (sans = display) + **JetBrains Mono** (mono),
  both self-hosted. No other webfonts.
- Hand-rolled particle canvas (no animation libs for the background)
- Generated OpenGraph image (`next/og`, nodejs runtime) — real logo embedded;
  no external assets anywhere

## Layout model — one viewport per section, every device

- `#snap-scroller` is a `100dvh` container with `overflow-y: scroll` and
  `scroll-snap-type: y mandatory` at **all** viewport sizes: every section is a
  snap target (`min-h-[100dvh]`, `scroll-snap-align: start`).
- `scroll-snap-stop: always` applies **only on desktop (≥768px)**, where each
  section is exactly one viewport — the user can never land between sections.
  On mobile a section may grow taller than a viewport; `scroll-snap-stop:
  normal` lets the user rest anywhere inside a tall section instead of being
  trapped by a jumpy snap.
- Section `overflow: hidden` is **md+ only** so nothing bleeds into a
  neighbour; on small screens sections are free to grow.
- **Mobile exception — the vault tree.** The vault-tree section (`relax`
  variant in `section.tsx`) is capped at `100dvh` on mobile and internal-
  scrolls (`overflow-y: auto`) so the tall diagram reads fully without breaking
  the mandatory snap.
- A fixed dot nav (`dot-nav.tsx`) jumps between sections and writes the URL
  fragment via `history.replaceState` (no history spam). A top brand progress
  bar (`scroll-progress.tsx`) fills with scroll position.
- All motion respects `prefers-reduced-motion`: framer variants render at
  final state, ScrollTop animations become `auto`, the particle field draws one
  static frame, and the hero logo pulse is disabled.

## Brand tokens — single source of truth

`lib/theme.ts` **mirrors `lib/core/theme/app_colors.dart` in the Flutter app
and must not be edited independently.** If the Flutter palette changes, update
that file and rebuild this page. No hardcoded hex/rgb lives in any component —
derive every color/radius/shadow from this module (e.g. `shadow-brand-soft`,
`shadow-brand-dot` in `tailwind.config.ts`).

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
  layout.tsx             # fonts (Inter, JetBrains Mono), metadata, MotionConfig
  page.tsx               # snap shell (#snap-scroller) + overlay composition
  globals.css            # snap utilities, themed scrollbar, reduced-motion
  opengraph-image.tsx    # at-request OG PNG (1200×630, theme + real logo)
  api/waitlist/route.ts  # hardened waitlist proxy (POST)
  components/
    section.tsx          # Section shell: snap viewport + relax (vault) variant
    reveal.tsx           # framer fade+slide entry (respects reduced motion)
    particle-field.tsx   # canvas constellation behind everything (area-based)
    scroll-progress.tsx  # top brand progress bar, reads #snap-scroller
    dot-nav.tsx          # right-edge section dots + replaceState fragments
    hero.tsx             # real logo (2.5s pulse) + headline + CTAs + form
    problem.tsx          # four scroll-fade lines
    how-it-works.tsx     # 1-2-3 cards (staggered, hover lift)
    vault-section.tsx    # section wrapper (intro + closing line)
    vault-tree.tsx       # THE funds-flow diagram (SVG desktop / stack mobile)
    features.tsx         # 1-col mobile / 3-col desktop grid, lime outline icons
    security-note.tsx    # plain-language security card
    pricing.tsx          # one-panel pricing
    built-on.tsx         # Sepolia live / mainnet staged + chain glyphs
    faq.tsx              # shadcn Accordion (hover lime), keyboard-navigable
    footer.tsx           # 3-column Product/Legal/Contact + honest legal small print
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

## Waitlist endpoint — hardened proxy

`POST /api/waitlist` accepts a JSON body and proxies it to the verified
backend service (`GLOBMINT_API_URL`, default the Render backend).

Request body:

```json
{ "email": "you@example.com" }
```

Behavior:

- **Validates** the email and returns `400` only for an invalid JSON body or an
  unparseable email address.
- **Always returns `{ ok: true }` for valid input** — rate-limited or upstream
  failures are swallowed, never surfaced to the visitor (leaks the backend
  topology) and never break the submit.
- **Rate-limits per IP, 5/hour**, keyed by a one-way SHA-256 hash of the
  client IP (first 32 hex chars), held in an in-memory `Map` (best-effort per
  instance; the backend rate limiter is the authoritative guard). **A raw IP is
  never stored or forwarded.**
- **Forwards attribution** to the backend: `source: "landing"`, the computed
  `ip_hash`, and the browser `user_agent`.
- The backend is the durable store (Postgres, migration `0023_waitlist_meta.sql`
  adds `email_lower` unique index, `source`, `ip_hash`, `user_agent`,
  `confirmed`); inserts are idempotent across case.

## VaultTree

`app/components/vault-tree.tsx` is the centerpiece. It renders the funds-flow
diagram:

1. **Desktop (≥768px):** a single scalable SVG scene
   (`viewBox 1000×680`, `max-w-[920px]` container) with `preserveAspectRatio`
   meet. Topology (one object flows into the next, no object feeds two):
   the two sender cards **YOU** and **ANYONE** both feed **YOUR CLONE VAULT
   ADDRESS** (deployed deterministically via CREATE2), which feeds the single
   **GLOBMINT VAULT CONTRACT** anchor (immutable, ownerless), which fans out to
   the three safety layers (**PIN + 2FA**, **24h time-lock**, **Recovery
   address**). The "the vault has no owner. no admin. no pause." sentence
   breaks the contract→badges line. Physical floors: the two anchor cards are
   ~1.4× the sender cards, badges are the smallest cards (still ≥100px tall /
   ≥180px wide), and the whole scene scales from one viewBox so every label
   keeps a floor (titles ≥14px, body ≥12px, connection labels ≥12px with ≥8px
   clearance). The section is tuned so the tree fits exactly one 1280×800
   viewport.
2. **Connector animation:** flow lines self-draw via framer `pathLength`
   (1.2s each, staggered YOU→vault → anyone→vault → vault→contract →
   contract→badges). Arrowheads appear as each branch finishes; the contract
   pulses once and settles to a rest glow; badges fade in one by one. Calm,
   once, no flash. On `prefers-reduced-motion` the scene renders fully static.
3. **Mobile (<768px):** the same content collapses into a stacked card list
   (`vault-tree-mobile.tsx`) with arrow separators and the badges as a simple
   list below; the section internal-scrolls within its one viewport.
4. All SVG colors/opacities come from `lib/theme.ts`.

## Testing motion / reduced motion

With the dev/prod server running:

- Desktop (1440×900): every section should snap to exactly 900px; dot nav on
  the right updates the hash; the progress bar reaches 100% at the footer.
- Mobile (375×667): snap is mandatory but `scroll-snap-stop` is `normal`; the
  vault tree internal-scrolls through its full height within its one-viewport
  window.
- DevTools → Rendering → `emulate prefers-reduced-motion: reduce`: no particles
  drift (single static frame), sections render instantly, dot-nav jumps
  instantly, hero logo does not pulse.

## Deploy

Vercel or Render; the build runs `next build`, `/` is `○ Static` with
`/api/waitlist` + `/opengraph-image` the only dynamic routes. Set
`GLOBMINT_API_URL` to the backend if it is not the default Render URL. No other
environment variables are required.

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