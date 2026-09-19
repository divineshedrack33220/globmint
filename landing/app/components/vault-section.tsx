import { VaultTree } from "@/app/components/vault-tree";
import { VaultTreeMobile } from "@/app/components/vault-tree-mobile";
import { Section } from "@/app/components/section";

/**
 * The vault section. This is the centerpiece: the tree fills ~85% of the
 * available width (capped at 1100px) and ~70% of the viewport tall on
 * desktop, so it gets the whole section to itself. On mobile the diagram
 * becomes stacked cards, and the section relaxes snapping so the tall stack
 * can scroll naturally.
 */
export function VaultSection() {
  return (
    <Section
      id="vault-tree"
      label="The vault"
      relax
      flush
      className="md:overflow-hidden"
    >
      <div className="container">
        <div className="mb-3 flex flex-col items-center gap-1 text-center">
          <h2 className="text-balance text-2xl font-semibold tracking-tight text-text">
            Where your money lives.
          </h2>
          <p className="text-sm text-text-muted md:text-base">
            One address. Yours alone. No admin can touch it.
          </p>
        </div>

        {/* Desktop: one scalable SVG */}
        <div className="hidden md:block">
          <VaultTree />
        </div>

        {/* Mobile: stacked cards */}
        <div className="md:hidden">
          <VaultTreeMobile />
        </div>

        <p className="mx-auto mt-4 max-w-2xl text-balance text-center text-sm leading-[1.6] text-text-muted md:text-base">
          Your funds are held in a contract with no owner and no admin. The
          backend can relay withdrawals — but it can never move funds you
          didn&#8217;t sign for. That&#8217;s not a feature. That&#8217;s the
          entire design.
        </p>
      </div>
    </Section>
  );
}