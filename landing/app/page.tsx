import { ParticleField } from "@/app/components/particle-field";
import { ScrollProgress } from "@/app/components/scroll-progress";
import { DotNav } from "@/app/components/dot-nav";
import { Hero } from "@/app/components/hero";
import { Problem } from "@/app/components/problem";
import { HowItWorks } from "@/app/components/how-it-works";
import { VaultSection } from "@/app/components/vault-section";
import { Features } from "@/app/components/features";
import { SecurityNote } from "@/app/components/security-note";
import { Pricing } from "@/app/components/pricing";
import { BuiltOn } from "@/app/components/built-on";
import { FAQ } from "@/app/components/faq";
import { Footer } from "@/app/components/footer";

/**
 * The full-viewport scroll-snap shell. Sections are exactly one viewport tall
 * and snap; nothing peeks. Overlays (particles, progress bar, dot nav) are
 * fixed and driven by the `.snap-scroll` container.
 */
export default function Page() {
  return (
    <div className="relative">
      <ParticleField />
      <ScrollProgress />
      <DotNav />

      <main id="snap-scroller" className="snap-scroll relative z-10">
        <Hero />
        <Problem />
        <HowItWorks />
        <VaultSection />
        <Features />
        <SecurityNote />
        <Pricing />
        <BuiltOn />
        <FAQ />
        <Footer />
      </main>
    </div>
  );
}