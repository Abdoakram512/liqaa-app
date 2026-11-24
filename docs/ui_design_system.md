# LIQAA — Mobile UI/UX Design System Specification

## 1. Design Vision & Emotional Tone

LIQAA's visual design combines the educational warmth of **Duolingo**, the playful charm of **Khan Academy Kids**, and the organic simplicity of **Sago Mini**.

- **Target Audience:** Egyptian Arabic-speaking children (ages 4–9), along with their parents and speech-language pathologists.
- **Visual Personality:** Cheerful, encouraging, patient, tactile, and clear.
- **RTL-First:** Arabic is designed as the primary native layout direction, with bidirectional mirroring for English LTR.

---

## 2. Color Palette & Token Architecture

| Token Name | Hex Code | Role | Usage |
| --- | --- | --- | --- |
| `primary` | `#F59E0B` | Brand Warm Amber | Primary CTA buttons, key badges, logo accents |
| `primaryDark` | `#D97706` | Deep Honey | Emphasized headlines, active border states |
| `primaryLight` | `#FDE68A` | Soft Amber Glow | Soundwave halo rings, subtle card outlines |
| `primaryContainer`| `#FEF3C7` | Warm Cream Tint | Speech bubbles, active selection chips |
| `secondary` | `#8B5CF6` | Playful Purple | Secondary buttons, educational game cards |
| `secondaryContainer`| `#EDE9FE`| Lavender Tint | Educational puzzle backgrounds |
| `background` | `#FFFDF9` | Warm Off-White | Scaffold background, natural soft paper feel |
| `surface` | `#FFFFFF` | Card Surface | Elevated cards, text field containers |
| `textPrimary` | `#1E293B` | Deep Slate | Main readable body text, input values |
| `textSecondary` | `#64748B` | Slate Gray | Subtitles, supporting educational notes |
| `success` | `#10B981` | Emerald Green | Correct pronunciation, valid input feedback |
| `error` | `#EF4444` | Soft Coral Red | Validation hints, correction prompts |

---

## 3. Typography & Arabic Hierarchy

Typography utilizes Google Fonts **Cairo** and **Noto Sans Arabic** with balanced line heights to prevent Arabic diacritic clipping:

| Style Name | Font Size | Weight | Line Height | Application |
| --- | --- | --- | --- | --- |
| `displayLarge` | 32sp | Bold (700) | 1.3 | Splash titles, victory milestones |
| `headlineSmall`| 24sp | Bold (700) | 1.35 | Onboarding headings, welcome greetings |
| `titleMedium` | 18sp | SemiBold (600) | 1.4 | Screen app bars, card titles |
| `bodyLarge` | 16sp | Regular (400) | 1.5 | Input values, core paragraphs |
| `bodyMedium` | 14sp | Regular (400) | 1.55 | Explanatory notes, instructions |
| `labelLarge` | 15sp | Bold (700) | 1.2 | Primary button text, role selector chips |
| `labelSmall` | 12sp | Medium (500) | 1.2 | Badges, character status tags |

---

## 4. Tactile Shapes, Radii & Shadows

- **Buttons & Chips:** Pill radius (`BorderRadius.circular(AppSpacing.radiusPill) = 999.r`).
- **Cards & Dialogs:** Smooth organic curves (`BorderRadius.circular(24.r)`).
- **Text Fields:** Generous rounded rectangles (`BorderRadius.circular(18.r)`).
- **Soft Shadows:**
  - Ambient: `BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))`
  - Interactive: `BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 16, offset: Offset(0, 4))`
  - Ground Shadow: `BoxShadow(color: Color(0x2E1E293B), blurRadius: 18, offset: Offset(0, 4))`

---

## 5. Input & Interaction Components

1. **`YasserTextField`:**
   - 18px rounded border with smooth AnimatedContainer depth.
   - 20px horizontal padding, 18px vertical padding for large touch targets (exceeds 48x48dp minimum).
   - Password reveal eye toggle with instant dispatch to Yasser peeking hooks.
   - Distinct focus color ring in `AppColors.primary`.

2. **`PrimaryButton`:**
   - Tactile 3D-effect pill with subtle elevation.
   - Integrated loading spinner.
   - Haptic feedback on press.

3. **`YasserCharacter`:**
   - Unified character renderer with live Rive and 2.5D fallback.
   - Ambient organic breathing physics.
   - Direct tap interaction response.
