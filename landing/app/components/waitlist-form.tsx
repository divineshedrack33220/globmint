"use client";

import * as React from "react";

import { Button } from "@/app/components/ui/button";
import { Input } from "@/app/components/ui/input";

type Status = "idle" | "loading" | "success" | "error";

export function WaitlistForm() {
  const [email, setEmail] = React.useState("");
  const [status, setStatus] = React.useState<Status>("idle");
  const [message, setMessage] = React.useState("");

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (status === "loading") return;

    const value = email.trim();
    if (!value) {
      setStatus("error");
      setMessage("Please enter your email address.");
      return;
    }

    setStatus("loading");
    setMessage("");

    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: value }),
      });

      if (res.ok) {
        setStatus("success");
        setMessage(
          "You're on the list. We'll email you the moment early access opens."
        );
        setEmail("");
        return;
      }

      const data = await res.json().catch(() => null);
      setStatus("error");
      setMessage(
        data?.error ?? "Something went wrong. Please try again in a moment."
      );
    } catch {
      setStatus("error");
      setMessage("Could not reach the server. Please try again.");
    }
  }

  return (
    <div className="w-full max-w-md">
      <form
        onSubmit={onSubmit}
        className="flex w-full flex-col gap-3 sm:flex-row"
        noValidate
      >
        <div className="flex-1">
          <Input
            type="email"
            inputMode="email"
            autoComplete="email"
            placeholder="you@example.com"
            aria-label="Email address"
            aria-invalid={status === "error" ? true : undefined}
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            disabled={status === "loading"}
            className="w-full"
          />
        </div>
        <Button
          type="submit"
          variant="default"
          size="default"
          disabled={status === "loading"}
          className="w-full sm:w-auto"
        >
          {status === "loading" ? "Joining…" : "Join"}
        </Button>
      </form>

      {status !== "idle" && (
        <p
          role={status === "error" ? "alert" : "status"}
          className={
            status === "error"
              ? "mt-3 text-sm text-destructive"
              : "mt-3 text-sm text-brand"
          }
        >
          {message}
        </p>
      )}
    </div>
  );
}