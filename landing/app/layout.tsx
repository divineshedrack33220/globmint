import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import { MotionConfig } from "framer-motion";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

const COPY_BASE =
  "Hold and move USDC with full self-custody. No banks. No middlemen. Nobody can freeze your funds — not even us.";

export const metadata: Metadata = {
  metadataBase: new URL("https://globmint.com"),
  title: "GlobMint — Your money, your rules.",
  description: COPY_BASE,
  openGraph: {
    title: "GlobMint — Your money, your rules.",
    description: COPY_BASE,
    url: "https://globmint.com",
    siteName: "GlobMint",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "GlobMint — Your money, your rules.",
    description: COPY_BASE,
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} font-sans bg-ink text-text`}
      >
        <MotionConfig reducedMotion="user">{children}</MotionConfig>
      </body>
    </html>
  );
}