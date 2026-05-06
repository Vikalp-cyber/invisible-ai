# Prompt: Build a Modern Website for My App

Use this prompt in ChatGPT, Claude, v0, Framer AI, Lovable, or any website-generation tool.

---

You are an expert product designer + frontend engineer.

Build a **high-end marketing website** for my product:

**Product name:** Invisible AI Assistant  
**Platform:** Flutter Windows desktop app  
**Core value:** A floating AI overlay that listens to system speaker output (Meet/Zoom/browser audio), detects interview questions, and instantly shows AI answers in an on-screen overlay.

## What this website should achieve

- Make the product look premium and trustworthy.
- Explain clearly how it works.
- Emphasize local/on-device speech pipeline and low-latency feel.
- Drive user actions: **Download**, **Watch Demo**, **Join Waitlist / Contact**.

## Visual direction

- Style: dark, futuristic, minimal, glassmorphism + neon accents.
- Feel: “invisible”, “smart”, “real-time”, “pro”.
- Colors:
  - Background: #070B14 / #0B1020
  - Primary accent: #6C7BFF
  - Secondary accent: #22D3EE
  - Highlight accent: #A78BFA
  - Text: #E5E7EB / muted #9CA3AF
- Typography:
  - Headings: Space Grotesk / Sora
  - Body: Inter / Manrope
- Layout: responsive, mobile-first, max-width sections with generous spacing.

## Animation requirements (important)

Use smooth, tasteful animations throughout:

1. Hero entrance animation (staggered text, fade+slide, subtle scale).
2. Floating overlay mockup gently bobbing with glow pulse.
3. Animated “audio waveform” bars in the hero.
4. Scroll-triggered reveal animations for each section.
5. “How it works” pipeline with animated arrows and step highlighting.
6. Card hover animations (lift, soft shadow, border glow).
7. Sticky navbar with blur and active section indicator.
8. Parallax background blobs/noise gradients.
9. CTA button microinteractions (magnetic hover / shimmer).
10. Footer fade-in and social icon hover transitions.

Animation should be performant (GPU-friendly transforms/opacities, reduced-motion support).

## Required pages/sections

Create these sections on a single-page website (plus optional legal pages):

1. **Navbar**
   - Logo: Invisible AI Assistant
   - Links: Features, How It Works, Use Cases, FAQ, Download
   - CTA button: Download for Windows

2. **Hero**
   - Headline: “Your Invisible AI Copilot for Live Interviews”
   - Subheadline: “Listens to speaker output, detects questions, and gives instant AI answers in a floating overlay.”
   - Primary CTA: Download for Windows
   - Secondary CTA: Watch Demo
   - Right side: animated app/overlay mockup

3. **Trust Strip**
   - Short badges: Local Speech Recognition, Real-Time Transcripts, Windows Native Integration, Low Latency

4. **Features Grid**
   - Floating desktop overlay
   - System audio listening (speaker output)
   - Real-time partial + final transcripts
   - Automatic interview question detection
   - Instant AI response in overlay
   - Built for Google Meet / Zoom / Browser learning videos

5. **How It Works** (animated pipeline)
   - Speaker Output
   - Speech Recognition
   - Transcript Stream
   - Question Detection
   - AI Answer
   - Overlay Display

6. **Use Cases**
   - Interview preparation
   - Live technical mock interviews
   - Learning from video tutorials
   - Communication practice

7. **Why It Feels Instant**
   - Native Windows audio pipeline
   - Stream-based processing
   - Low overhead architecture
   - Continuous listening mode

8. **FAQ**
   - Does it require VB-CABLE? (No, direct speaker capture supported)
   - Is speech recognition local? (Yes)
   - Which platforms are supported? (Windows desktop)
   - Does it work with Meet/Zoom/browser audio? (Yes)

9. **Final CTA**
   - “Ready to use an invisible AI edge?”
   - Buttons: Download / Contact

10. **Footer**
   - Product links, social links, privacy, terms, copyright

## Content tone

- Confident, crisp, modern.
- Avoid hypey buzzwords.
- Keep copy conversion-focused and skimmable.

## Technical constraints

- Build production-quality code.
- Accessibility: proper contrast, keyboard navigation, semantic HTML, aria labels.
- SEO: title/meta/og tags, structured heading hierarchy.
- Performance: optimize images, lazy-load non-critical assets, avoid heavy JS.
- Include reduced-motion fallback.

## Deliverables

1. Full website code/components.
2. Reusable design system tokens (colors, spacing, radius, shadows).
3. Animation config (durations/easing/stagger).
4. Placeholder screenshots/illustrations for app preview.
5. Instructions for replacing placeholders with real assets.

If needed, choose a modern stack (Next.js + Tailwind + Framer Motion) and output complete implementable code.

---

## Optional shorter prompt (quick mode)

Design a premium dark-themed landing page for **Invisible AI Assistant** (Windows desktop app). It should showcase a floating AI overlay that listens to system speaker output (Meet/Zoom/browser), performs local speech recognition, detects interview questions, and shows instant AI answers. Include smooth scroll animations, hero mockup animation, animated “How it works” pipeline, features, use-cases, FAQ, and strong Download CTA. Style: glassmorphism + neon accents, modern typography, high conversion focus, responsive and accessible.

