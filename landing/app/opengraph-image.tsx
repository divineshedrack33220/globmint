import { readFileSync } from "node:fs";
import path from "node:path";

import { ImageResponse } from "next/og";

import { theme } from "@/lib/theme";

export const runtime = "nodejs";
export const alt = "GlobMint — Your money, your rules.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/* eslint-disable @next/next/no-img-element */

function logoDataUri(): string {
  const file = readFileSync(
    path.join(process.cwd(), "public", "logo.png")
  );
  const base64 = file.toString("base64");
  const ext = "png";
  return `data:image/${ext};base64,${base64}`;
}

export default function OpengraphImage() {
  const { colors, radius } = theme;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 32,
          background: colors.background,
          padding: 64,
        }}
      >
        <img
          src={logoDataUri()}
          alt=""
          width={132}
          height={132}
          style={{ borderRadius: radius.full }}
        />
        <div
          style={{
            color: colors.textPrimary,
            fontSize: 64,
            fontWeight: 600,
            letterSpacing: "-0.02em",
            textAlign: "center",
          }}
        >
          Your money, your rules.
        </div>
        <div style={{ color: colors.textSecondary, fontSize: 28, textAlign: "center" }}>
          Save and move USDC with full self-custody.
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}