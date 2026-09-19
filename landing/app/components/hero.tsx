import { WaitlistForm } from "@/app/components/waitlist-form";
import { LogoMark } from "@/app/components/logo-mark";
import { Section } from "@/app/components/section";
import { Button } from "@/app/components/ui/button";
import { theme } from "@/lib/theme";

export function Hero() {
  return (
    <Section id="hero" label="Hero" className="overflow-hidden">
      {/* Very faint brand glow behind the hero — 4% opacity, never a hard edge */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0"
        style={{
          background: `radial-gradient(640px 320px at 50% -4%, ${theme.colors.primaryOverlay}, transparent 70%)`,
        }}
      />

      <div className="container relative flex flex-col items-center text-center">
        <div className="relative">
          <div
            aria-hidden="true"
            className="absolute inset-0 -z-10 rounded-full bg-brand/20 blur-2xl motion-reduce:hidden"
          />
          <LogoMark className="h-24 w-24" priority />
        </div>

        <h1
          id="hero-heading"
          className="mt-10 max-w-2xl text-balance font-display font-semibold tracking-tight text-4xl text-text sm:text-5xl md:text-6xl"
        >
          Your money, your rules.
        </h1>
        <p className="mt-6 max-w-xl text-balance text-lg leading-[1.6] text-text-muted">
          Save and move USDC with full self-custody. No banks. No middlemen.
          Nobody can freeze your funds — not even us.
        </p>

        <div className="mt-10 flex flex-col gap-3 sm:flex-row">
          <Button asChild variant="default" size="lg">
            <a href="#waitlist">Get early access</a>
          </Button>
          <Button
            asChild
            variant="outline"
            size="lg"
          >
            <a
              href="https://docs.globmint.com"
              target="_blank"
              rel="noopener noreferrer"
            >
              Read the docs
            </a>
          </Button>
        </div>

        <div id="waitlist" className="mt-10 flex w-full flex-col items-center">
          <p className="mb-4 text-sm text-text-muted">
            Join the waitlist — we&#8217;ll email you when early access opens.
          </p>
          <WaitlistForm />
        </div>
      </div>
    </Section>
  );
}