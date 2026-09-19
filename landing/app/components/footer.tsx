import { LogoMark } from "@/app/components/logo-mark";
import { Section } from "@/app/components/section";

export function Footer() {
  return (
    <Section id="footer" label="Footer" className="overflow-hidden">
      <footer className="container w-full">
        <div className="flex flex-col items-center text-center">
          <LogoMark className="h-12 w-12" />
          <p className="mt-6 text-lg font-semibold text-text">
            GlobMint
          </p>
          <p className="mt-1 text-sm text-text-muted">
            Your money, your rules.
          </p>

          <div className="mt-8 flex items-center gap-6 text-sm">
            <a
              href="https://docs.globmint.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-text-muted transition-colors hover:text-brand"
            >
              Docs
            </a>
            <a
              href="https://globmint.com/terms"
              className="text-text-muted transition-colors hover:text-brand"
            >
              Terms
            </a>
            <a
              href="https://globmint.com/privacy"
              className="text-text-muted transition-colors hover:text-brand"
            >
              Privacy
            </a>
          </div>

          <p className="mt-10 text-xs text-text-muted/70">
            © {new Date().getFullYear()} GlobMint. USDC is not legal tender.
            Crypto is volatile. Nothing here is financial advice.
          </p>
        </div>
      </footer>
    </Section>
  );
}