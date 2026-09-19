import { Section } from "@/app/components/section";

export function Pricing() {
  return (
    <Section id="pricing" label="Pricing" className="overflow-hidden">
      <div className="container text-center">
        <p className="text-sm font-mono uppercase tracking-widest text-brand">
          Pricing
        </p>
        <h2 className="mt-6 text-balance text-3xl font-semibold tracking-tight text-text sm:text-4xl md:text-5xl">
          Free to use. Free to deposit.
          <br />
          <span className="text-brand">0.2% on withdrawal</span>
        </h2>
        <p className="mt-4 text-base leading-[1.6] text-text-muted">
          min ₦10, max ₦100
        </p>
        <p className="mx-auto mt-10 max-w-md text-sm leading-[1.6] text-text-muted/80">
          No subscriptions. No hidden fees. The fee covers gas and servers —
          nothing else.
        </p>
      </div>
    </Section>
  );
}