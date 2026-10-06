import { LogoMark } from "@/app/components/logo-mark";
import { Section } from "@/app/components/section";

const COLUMNS: {
  heading: string;
  links: { label: string; href: string; external?: boolean }[];
}[] = [
  {
    heading: "Product",
    links: [
      { label: "How it works", href: "#how-it-works" },
      { label: "Pricing", href: "#pricing" },
      { label: "FAQ", href: "#faq" },
      { label: "Docs", href: "https://docs.globmint.com", external: true },
    ],
  },
  {
    heading: "Legal",
    links: [
      { label: "Privacy Policy", href: "https://globmint.com/privacy" },
      { label: "Terms of Service", href: "https://globmint.com/terms" },
    ],
  },
  {
    heading: "Contact",
    links: [
      { label: "Email", href: "mailto:hello@clawbet.it.com" },
      { label: "Twitter", href: "https://x.com/globmint", external: true },
      { label: "GitHub", href: "https://github.com/globmint", external: true },
    ],
  },
];

export function Footer() {
  return (
    <Section id="footer" label="Footer" className="overflow-hidden">
      <footer className="container w-full">
        <div className="grid grid-cols-1 gap-10 md:grid-cols-3 md:gap-8">
          <div className="flex flex-col items-start">
            <LogoMark className="h-12 w-12" />
            <p className="mt-4 font-semibold text-text">GlobMint</p>
            <p className="mt-1 text-sm text-brand">
              Built for people who want control.
            </p>
          </div>

          {COLUMNS.map((column) => (
            <nav
              key={column.heading}
              aria-label={column.heading}
              className="flex flex-col items-start gap-3 text-sm"
            >
              <p className="font-medium text-text">{column.heading}</p>
              {column.links.map((link) => (
                <a
                  key={link.label}
                  href={link.href}
                  {...(link.external
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                  className="text-text-muted transition-colors hover:text-brand"
                >
                  {link.label}
                </a>
              ))}
            </nav>
          ))}
        </div>

        <div className="mt-12 border-t border-ink-border pt-6">
          <p className="max-w-3xl text-xs leading-relaxed text-text-muted/70">
            GlobMint is a self-custodial software product. It is not a bank,
            money transmitter, or financial advisor. USDC is issued by Circle.
            Use at your own risk.
          </p>
          <p className="mt-3 text-xs text-text-muted/70">
            © {new Date().getFullYear()} GlobMint.
          </p>
        </div>
      </footer>
    </Section>
  );
}