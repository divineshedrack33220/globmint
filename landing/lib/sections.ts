// Mirrors the order + ids of the sections rendered in app/page.tsx.
export const SECTIONS = [
  { id: "hero", label: "Hero" },
  { id: "problem", label: "Problem" },
  { id: "how-it-works", label: "How it works" },
  { id: "vault-tree", label: "The vault" },
  { id: "features", label: "Features" },
  { id: "security", label: "Security" },
  { id: "pricing", label: "Pricing" },
  { id: "built-on", label: "Built on" },
  { id: "faq", label: "FAQ" },
  { id: "footer", label: "Footer" },
] as const;

export type SectionId = (typeof SECTIONS)[number]["id"];