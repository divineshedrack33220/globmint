import Image from "next/image";

/**
 * The real GlobMint mark — the platform's logo.png (assets/images/logo.png),
 * copied to public/logo.png so it is self-hosted with zero external requests.
 * Rendered as a circle to match the Flutter app's logo treatment.
 */
export function LogoMark({
  className,
  priority = false,
  ariaHidden = false,
}: {
  className?: string;
  priority?: boolean;
  ariaHidden?: boolean;
}) {
  return (
    <Image
      src="/logo.png"
      alt={ariaHidden ? "" : "GlobMint"}
      width={96}
      height={96}
      priority={priority}
      aria-hidden={ariaHidden || undefined}
      className={`rounded-full bg-transparent ${className ?? ""}`}
    />
  );
}