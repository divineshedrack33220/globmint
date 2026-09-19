import { Section } from "@/app/components/section";

export function SecurityNote() {
  return (
    <Section id="security" label="Security" className="overflow-hidden">
      <div className="container">
        <div className="mx-auto max-w-[700px] rounded-2xl border border-ink-border bg-ink-elev p-10 text-center md:p-14">
          <p className="text-sm font-mono uppercase tracking-widest text-brand">
            Security, said plainly
          </p>
          <p
            id="security-heading"
            className="mt-6 text-balance text-xl font-medium leading-[1.6] text-text md:text-2xl"
          >
            The vault has no owner and no admin. The backend can relay
            withdrawals, but it cannot move funds you did not sign for. Nobody —
            not us, not a regulator, not a hacker — can freeze or seize your
            balance. That&#8217;s not a feature. That&#8217;s the entire design.
          </p>
        </div>
      </div>
    </Section>
  );
}