"use client";

import { motion } from "framer-motion";

import { Section } from "@/app/components/section";

const EASE = [0.22, 1, 0.36, 1] as const;

const LINES: Array<{ text: string; brand?: boolean }> = [
  { text: "Banks freeze accounts." },
  { text: "Governments can seize funds." },
  { text: "Custodial apps change the rules overnight." },
  { text: "There\u2019s a better way.", brand: true },
];

export function Problem() {
  return (
    <Section id="problem" label="Problem" className="overflow-hidden">
      <div
        className="flex flex-col gap-5 text-center"
        style={{ perspective: "600px" }}
      >
        {LINES.map((line, index) => (
          <motion.p
            key={line.text}
            className={
              line.brand
                ? "text-balance text-2xl font-semibold tracking-tight text-brand sm:text-3xl"
                : "text-balance text-2xl font-semibold tracking-tight text-text sm:text-3xl"
            }
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-30%" }}
            transition={{ duration: 0.6, ease: EASE, delay: index * 0.18 }}
          >
            {line.text}
          </motion.p>
        ))}
      </div>
    </Section>
  );
}