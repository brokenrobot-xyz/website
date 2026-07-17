---
version: alpha
name: Broken Robot (dark)
description: Dark theme override — same token names as DESIGN.md, dark values.
colors:
    bg: '#17150f'
    surface: '#201d17'
    surface-2: '#2a2620'
    text: '#f4efe4'
    muted: '#a89e8d'
    border: '#332e25'
    accent: '#f59e0b'
    accent-ink: '#fbbf24'
    primary: '{colors.accent}'
    code-bg: '#0f0e0b'
    code-text: '#ece6da'
    code-line: '#262320'
typography:
    display:
        fontFamily: 'Space Grotesk'
    prose:
        fontFamily: 'Newsreader'
    mono:
        fontFamily: 'Space Mono'
components:
    page:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.text}'
    surface:
        backgroundColor: '{colors.surface}'
        textColor: '{colors.text}'
    muted-text:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.muted}'
    link:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.accent-ink}'
    code-block:
        backgroundColor: '{colors.code-bg}'
        textColor: '{colors.code-text}'
---

## Overview

Dark theme for Broken Robot — the `html[data-theme='dark']` override. Token names match `DESIGN.md`;
only the values differ, and the full rationale lives in the light file. This file exists as a
first-class source so the linter can contrast-check the dark theme independently and the generator can
emit the dark value block.

## Colors

Same semantic roles as the light theme, over a deep warm-charcoal paper stack with lighter
foreground. `accent-ink` shifts to a brighter amber (`#fbbf24`) so links stay legible on dark
surfaces; `accent` itself is unchanged across themes.
