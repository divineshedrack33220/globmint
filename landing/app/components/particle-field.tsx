"use client";

import * as React from "react";

type Particle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  flicker: number;
};

const BRAND_RGB = { r: 214, g: 251, b: 87 }; // #D6FB57

function brandRgba(alpha: number) {
  return `rgba(${BRAND_RGB.r}, ${BRAND_RGB.g}, ${BRAND_RGB.b}, ${alpha})`;
}

/**
 * A quiet constellation behind the whole page: many small dots slowly
 * drifting, with thin faint lines connecting nearby particles. Reads as
 * "network / connection / security" without being distracting.
 *
 * - Density scales with viewport area (60–80 desktop, 25–35 mobile).
 * - Motion is capped at 60fps, pauses when the tab is hidden, and renders a
 *   single static frame under prefers-reduced-motion.
 * - Colors derive from the theme's primary (#D6FB57): dots at ~35–50%
 *   opacity, connector lines at ~10–15%.
 */
export function ParticleField() {
  const canvasRef = React.useRef<HTMLCanvasElement | null>(null);

  React.useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const el = canvas;
    const g = ctx;

    const reduceMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    let width = 0;
    let height = 0;
    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    let particles: Particle[] = [];

    const LINK_DISTANCE = 150;
    const PARTICLE_ALPHA_MIN = 0.35;
    const PARTICLE_ALPHA_MAX = 0.5;
    const LINK_ALPHA_BASE = 0.1;

    let rafId = 0;
    let lastFrame = 0;
    let running = true;
    let active = !document.hidden;

    function buildParticles() {
      const area = width * height;
      // Density scales with viewport area: 60–80 desktop, 25–35 mobile.
      const count = width < 768
        ? Math.max(25, Math.min(35, Math.round(area / 12000)))
        : Math.max(60, Math.min(80, Math.round(area / 20000)));
      particles = Array.from({ length: count }, () => ({
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 0.22,
        vy: (Math.random() - 0.5) * 0.22,
        r: 1 + Math.random() * 1.5,
        flicker: Math.random() * Math.PI * 2,
      }));
    }

    function resize() {
      const rect = el.getBoundingClientRect();
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = rect.width || window.innerWidth;
      height = rect.height || window.innerHeight;
      el.width = Math.floor(width * dpr);
      el.height = Math.floor(height * dpr);
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      buildParticles();

      if (reduceMotion) {
        drawStatic();
      }
    }

    function drawStatic() {
      g.clearRect(0, 0, width, height);
      for (let i = 0; i < particles.length; i++) {
        const p = particles[i];
        g.globalAlpha = PARTICLE_ALPHA_MIN;
        g.fillStyle = brandRgba(1);
        g.beginPath();
        g.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        g.fill();
      }

      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const a = particles[i];
          const b = particles[j];
          const dx = a.x - b.x;
          const dy = a.y - b.y;
          const dist = Math.hypot(dx, dy);
          if (dist < LINK_DISTANCE) {
            const alpha =
              LINK_ALPHA_BASE * (1 - dist / LINK_DISTANCE) * 0.5;
            g.globalAlpha = alpha;
            g.strokeStyle = brandRgba(1);
            g.lineWidth = 1;
            g.beginPath();
            g.moveTo(a.x, a.y);
            g.lineTo(b.x, b.y);
            g.stroke();
          }
        }
      }
      g.globalAlpha = 1;
    }

    function step(timestamp: number) {
      if (!running) return;

      if (timestamp - lastFrame >= 16) {
        lastFrame = timestamp;
        if (active) update();
      } else if (active) {
        // Keeps motion smooth but capped at ~60fps.
      }
      rafId = requestAnimationFrame(step);
    }

    function update() {
      g.clearRect(0, 0, width, height);
      const now = performance.now() / 1000;

      for (let i = 0; i < particles.length; i++) {
        const p = particles[i];
        p.x += p.vx;
        p.y += p.vy;

        // Wrap around the edges so the field always looks full.
        if (p.x < -10) p.x = width + 10;
        if (p.x > width + 10) p.x = -10;
        if (p.y < -10) p.y = height + 10;
        if (p.y > height + 10) p.y = -10;

        const alpha =
          PARTICLE_ALPHA_MIN +
          (PARTICLE_ALPHA_MAX - PARTICLE_ALPHA_MIN) *
            (0.5 + 0.5 * Math.sin(now * 0.8 + p.flicker));
        g.globalAlpha = alpha;
        g.fillStyle = brandRgba(1);
        g.beginPath();
        g.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        g.fill();
      }

      // Connector lines at much lower opacity.
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const a = particles[i];
          const b = particles[j];
          const dx = a.x - b.x;
          const dy = a.y - b.y;
          const dist = Math.hypot(dx, dy);
          if (dist < LINK_DISTANCE) {
            const alpha = LINK_ALPHA_BASE * (1 - dist / LINK_DISTANCE);
            g.globalAlpha = alpha;
            g.strokeStyle = brandRgba(1);
            g.lineWidth = 1;
            g.beginPath();
            g.moveTo(a.x, a.y);
            g.lineTo(b.x, b.y);
            g.stroke();
          }
        }
      }
      g.globalAlpha = 1;
    }

    function onVisibility() {
      active = !document.hidden;
    }

    function onResize() {
      resize();
    }

    if (reduceMotion) {
      resize();
      return () => {};
    }

    resize();
    rafId = requestAnimationFrame(step);
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("resize", onResize);

    return () => {
      running = false;
      cancelAnimationFrame(rafId);
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("resize", onResize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-0 h-full w-full"
    />
  );
}