import { Section } from "@/app/components/section";

type ChainGlyphProps = {
  label: string;
  d: string;
};

function ChainGlyph({ label, d }: ChainGlyphProps) {
  return (
    <span
      className="flex items-center gap-2 text-sm text-text-muted"
      aria-label={label}
    >
      <svg
        viewBox="0 0 24 24"
        className="h-5 w-5"
        fill="none"
        aria-hidden="true"
      >
        <path d={d} stroke="currentColor" strokeWidth="1.4" />
      </svg>
      {label}
    </span>
  );
}

/**
 * Minimal on-chain identity glyphs. Hexagon (Base), diamond (Ethereum),
 * triangle (Arbitrum), circle (Optimism). Rendered inline as SVG.
 */
export function BuiltOn() {
  return (
    <Section id="built-on" label="Built on" className="overflow-hidden">
      <div className="container flex flex-col items-center text-center">
        <p className="text-sm font-mono uppercase tracking-widest text-text-muted">
          Built on Ethereum
        </p>
        <p className="mt-6 max-w-2xl text-balance text-xl font-medium leading-[1.6] text-text md:text-2xl">
          Live on Sepolia testnet. Mainnet launch staged on Base, Ethereum,
          Arbitrum, and Optimism. USDC only for now. More stablecoins coming.
        </p>

        <div
          className="mt-10 flex items-center gap-8"
          role="list"
          aria-label="Supported networks"
        >
          <span role="listitem">
            <ChainGlyph label="Base" d="M12 3l7 4v10l-7 4-7-4V7l7-4Z" />
          </span>
          <span role="listitem">
            <ChainGlyph
              label="Ethereum"
              d="M12 3v18M5 9l7-6 7 6M5 15l7 6 7-6M5 9l7 3 7-3M5 15l7-3 7 3"
            />
          </span>
          <span role="listitem">
            <ChainGlyph
              label="Arbitrum"
              d="M12 4l7.5 4.5v7L12 20l-7.5-4.5v-7L12 4Z"
            />
          </span>
          <span role="listitem">
            <ChainGlyph label="Optimism" d="M12 4a8 8 0 100 16 8 8 0 000-16Z" />
          </span>
        </div>

        <p className="mt-8 text-sm text-text-muted">
          Testnet: Sepolia. Your money, your rules — on mainnet soon.
        </p>
      </div>
    </Section>
  );
}