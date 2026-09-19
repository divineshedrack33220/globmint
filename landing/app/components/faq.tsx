import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/app/components/ui/accordion";
import { Section } from "@/app/components/section";

const FAQ_ITEMS = [
  {
    question: "Do I need to understand crypto?",
    answer:
      "No. If you can use email, you can use GlobMint.",
  },
  {
    question: "What if I lose my phone?",
    answer:
      "Recover with your password, your 2FA code, or a recovery address you set in advance.",
  },
  {
    question: "Is USDC safe?",
    answer:
      "It's issued by Circle, backed 1:1 by US dollars and short-term Treasuries. It is not risk-free — no stablecoin is.",
  },
  {
    question: "Can you freeze my account?",
    answer:
      "No. We don't hold your keys or your funds. That's the whole point.",
  },
  {
    question: "Is this available in Nigeria?",
    answer:
      "Yes — and anywhere with internet. There's no KYC, so there's no country list.",
  },
];

export function FAQ() {
  return (
    <Section
      id="faq"
      label="Questions, answered plainly"
      className="overflow-hidden"
    >
      <div className="container">
        <h2
          id="faq-heading"
          className="text-balance text-center text-3xl font-semibold tracking-tight text-text md:text-4xl"
        >
          Questions, answered plainly
        </h2>

        <div className="mx-auto mt-12 max-w-2xl">
          <Accordion type="single" collapsible className="w-full">
            {FAQ_ITEMS.map((item, index) => (
              <AccordionItem key={item.question} value={`item-${index}`}>
                <AccordionTrigger>{item.question}</AccordionTrigger>
                <AccordionContent>{item.answer}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </div>
    </Section>
  );
}