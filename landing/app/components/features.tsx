"use client";

import { motion } from "framer-motion";

import {
  Building2,
  Coins,
  EyeOff,
  Fingerprint,
  CircleDollarSign,
  TimerReset,
} from "lucide-react";

import { Card } from "@/app/components/ui/card";
import { Section } from "@/app/components/section";

const EASE = [0.22, 1, 0.36, 1] as const;

const FEATURES = [
  {
    icon: Fingerprint,
    title: "True self-custody",
    body: "Ownerless vault contracts. No admin. No seizure.",
  },
  {
    icon: CircleDollarSign,
    title: "Nearly free",
    body: "Deposits cost only network gas. Withdrawals: 0.2%, min ₦10, max ₦100.",
  },
  {
    icon: Coins,
    title: "No KYC",
    body: "An email and a PIN. Nothing else.",
  },
  {
    icon: EyeOff,
    title: "Private balances",
    body: "Commitment-based storage hides your balance from block explorers.",
  },
  {
    icon: Building2,
    title: "Recovery without surrender",
    body: "Designate a backup address. If you lose your key, they can reclaim your vault. You keep the cancel button.",
  },
  {
    icon: TimerReset,
    title: "PIN, 2FA, time-locks",
    body: "High-value withdrawals wait 24 hours. You can cancel them anytime.",
  },
];

export function Features() {
  return (
    <Section id="features" label="Features" className="overflow-hidden">
      <div className="container">
        <h2 className="text-balance text-center text-3xl font-semibold tracking-tight text-text md:text-4xl">
          Built to be boring.
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-center text-lg text-text-muted">
          Every detail exists to keep your money yours.
        </p>

        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((feature, index) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-30%" }}
              transition={{ duration: 0.6, ease: EASE, delay: index * 0.08 }}
            >
              <Card className="p-6 transition-all duration-300 hover:-translate-y-1 hover:border-brand/60">
                <div className="flex items-start gap-4">
                  <span className="mt-0.5 shrink-0 rounded-xl border border-brand/30 p-2.5 text-brand">
                    <feature.icon className="h-5 w-5" strokeWidth={1.6} />
                  </span>
                  <div>
                    <h3 className="text-lg font-semibold tracking-tight text-text">
                      {feature.title}
                    </h3>
                    <p className="mt-2 text-sm leading-[1.6] text-text-muted">
                      {feature.body}
                    </p>
                  </div>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </Section>
  );
}