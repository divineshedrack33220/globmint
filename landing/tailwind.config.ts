import type { Config } from "tailwindcss";

import { theme } from "./lib/theme";

const config: Config = {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "1.5rem",
      screens: {
        "2xl": "1100px",
      },
    },
    extend: {
      colors: {
        // Platform background layers (lib/core/theme/app_colors.dart)
        background: theme.colors.background,
        foreground: theme.colors.textPrimary,
        border: theme.colors.border,
        input: theme.colors.inputBackground,

        // Brand — signature yellow #D6FB57 + its alpha variants
        brand: {
          DEFAULT: theme.colors.primary,
          dark: theme.colors.primaryDark,
          muted: theme.colors.primaryMuted,
          glow: theme.colors.primaryGlow,
          subtle: theme.colors.primarySubtle,
          highlight: theme.colors.primaryHighlight,
          overlay: theme.colors.primaryOverlay,
          soft: theme.colors.primarySoft,
          foreground: theme.colors.primaryForeground,
        },

        // Ink surfaces
        ink: {
          DEFAULT: theme.colors.background,
          deep: theme.colors.backgroundDeep,
          surface: theme.colors.surface,
          elev: theme.colors.surfaceElevated,
          highlight: theme.colors.surfaceHighlight,
          soft: theme.colors.surfaceSoft,
          border: theme.colors.borderLight,
        },

        // Text ramp
        text: {
          DEFAULT: theme.colors.textPrimary,
          muted: theme.colors.textSecondary,
          tertiary: theme.colors.textTertiary,
          disabled: theme.colors.textDisabled,
          onPrimary: theme.colors.textOnPrimary,
        },

        // Functional status
        success: theme.colors.success,
        warning: theme.colors.warning,
        destructive: theme.colors.destructive,
        info: theme.colors.info,
      },
      fontFamily: {
        sans: ["var(--font-inter)", "system-ui", "sans-serif"],
        mono: ["var(--font-jetbrains-mono)", "SFMono-Regular", "monospace"],
        display: ["var(--font-space-grotesk)", "var(--font-inter)", "sans-serif"],
      },
      borderRadius: {
        lg: `${theme.radius.lg}px`,
        md: `${theme.radius.md}px`,
        sm: `${theme.radius.sm}px`,
        xl: `${theme.radius.xl}px`,
        "2xl": `${theme.radius.xxl}px`,
      },
      boxShadow: {
        brand: `0 0 24px ${theme.colors.primaryGlow}`,
        "brand-lg": `0 0 48px ${theme.colors.primaryGlow}`,
        card: `0 0 0 1px ${theme.colors.border}`,
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        "particle-drift": {
          from: { transform: "translateY(0)" },
          to: { transform: "translateY(-8px)" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.25s cubic-bezier(0.22, 1, 0.36, 1)",
        "accordion-up": "accordion-up 0.25s cubic-bezier(0.22, 1, 0.36, 1)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;