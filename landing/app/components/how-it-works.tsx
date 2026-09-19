"use client";

import { motion } from "framer-motion";

import { Card, CardContent } from "@/app/components/ui/card";
import { Section } from "@/app/components/section";

const EASE = [0.22, 1, 0.36, 1] as const;

const STEPS = [
  {
    number: "1",
    title: "Create an account",
    body: "Just an email and a PIN. No KYC. No documents. No waiting.",
  },
  {
    number: "2",
    title: "Get your own deposit address",
    body: "A private on-chain vault address, unique to you. Anyone can send USDC to it — a friend, an exchange, a brand-new wallet. No wallet connection needed.",
  },
  {
    number: "3",
    title: "Withdraw to any address you name",
    body: "Signed by your own wallet. Nobody else can move your money. Not us, not a regulator, not a hacker.",
  },
];

export function HowItWorks() {
  return (
    <Section id="how-it-works" label="How it works" className="overflow-hidden">
      <div className="container">
        <h2 className="text-balance text-center text-3xl font-semibold tracking-tight text-text md:text-4xl">
          How it works
        </h2>

        <div className="mt-12 grid gap-5 md:grid-cols-3">
          {STEPS.map((step, index) => (
            <motion.div
              key={step.number}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-30%" }}
              transition={{ duration: 0.6, ease: EASE, delay: index * 0.12 }}
            >
              <Card className="p-6 transition-all duration-300 hover:-translate-y-1 hover:shadow-card">
                <CardContent className="p-0">
                  <p className="font-mono text-sm text-brand">{step.number}</p>
                  <h3 className="mt-4 text-xl font-semibold tracking-tight text-text">
                    {step.title}
                  </h3>
                  <p className="mt-3 leading-[1.6] text-text-muted">
                    {step.body}
                  </p>
                </CardContent>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </Section>
  );
}