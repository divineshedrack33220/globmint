// Mirrors lib/core/theme/app_colors.dart — do not edit independently.
// If the Flutter app palette changes, update that file and rebuild the
// landing page. Every color on this page derives from these tokens.

export const theme = {
  colors: {
    // Background layers
    backgroundDeep: "#000000", // Color(0xFF000000)
    background: "#080808", // Color(0xFF080808)
    surface: "#111111", // Color(0xFF111111)
    surfaceElevated: "#181818", // Color(0xFF181818)
    surfaceHighlight: "#202020", // Color(0xFF202020)
    surfaceSoft: "#0D0D0D", // Color(0xFF0D0D0D)

    // Brand — signature yellow
    primary: "#D6FB57", // Color(0xFFD6FB57)
    primaryBright: "#D6FB57", // Color(0xFFD6FB57)
    primaryDark: "#D6FB57", // Color(0xFFD6FB57)
    primaryMuted: "#D6FB57", // Color(0xFFD6FB57)
    primaryForeground: "#000000", // Color(0xFF000000)

    // Brand alpha variants
    primaryGlow: "rgba(214, 251, 87, 0.20)", // 0x33 primary
    primarySubtle: "rgba(214, 251, 87, 0.30)", // 0x4D primary
    primaryHighlight: "rgba(214, 251, 87, 0.40)", // 0x66 primary
    primaryOverlay: "rgba(214, 251, 87, 0.10)", // 0x1A primary
    primarySoft: "rgba(214, 251, 87, 0.15)", // 0x26 primary

    // Text
    textPrimary: "#FFFFFF", // Color(0xFFFFFFFF)
    textSecondary: "#A3A3A3", // Color(0xFFA3A3A3)
    textTertiary: "#737373", // Color(0xFF737373)
    textDisabled: "#4D4D4D", // Color(0xFF4D4D4D)
    textOnPrimary: "#000000", // Color(0xFF000000)

    // Functional status
    success: "#22C55E", // Color(0xFF22C55E)
    successMuted: "#052E16", // Color(0xFF052E16)
    warning: "#F59E0B", // Color(0xFFF59E0B)
    warningMuted: "#451A03", // Color(0xFF451A03)
    destructive: "#EF4444", // Color(0xFFEF4444)
    destructiveMuted: "#450A0A", // Color(0xFF450A0A)
    info: "#60A5FA", // Color(0xFF60A5FA)
    infoMuted: "#172554", // Color(0xFF172554)

    // Borders & dividers
    border: "#242424", // Color(0xFF242424)
    borderLight: "#333333", // Color(0xFF333333)
    borderSubtle: "#1A1A1A", // Color(0xFF1A1A1A)
    divider: "#1C1C1C", // Color(0xFF1C1C1C)

    // Inputs
    inputBackground: "#111111", // Color(0xFF111111)
    inputFocus: "#181818", // Color(0xFF181818)
    inputBorder: "#242424", // Color(0xFF242424)
    inputBorderFocus: "#D6FB57", // Color(0xFFD6FB57)
    inputBorderError: "#EF4444", // Color(0xFFEF4444)

    // Overlays & loading
    overlay: "rgba(0, 0, 0, 0.70)", // 0xB3 black
    skeletonBase: "#181818", // Color(0xFF181818)
    skeletonShimmer: "#242424", // Color(0xFF242424)
  },

  radius: {
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 24,
    full: 999,
  },
} as const;

// Legacy short names used by older landing tokens so the page stays readable.
export const brand = theme.colors.primary;
export const brandRgb = "214 251 87"; // rgb triplet for opacity modifiers
export const accentGlow = theme.colors.primaryGlow;