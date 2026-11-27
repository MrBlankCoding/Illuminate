.pragma library

// The colour math behind Theme. Every colour in the UI comes from one seed:
// a hue and how vivid it is (the HSL saturation of the colour the user picked).
// Lightness is never taken from the seed. Each role instead asks for a target
// luminance and solves for the lightness that hits it, so a yellow seed and a
// blue seed come out with the same contrast between text and background.
// Pure functions only; Theme binds them to the active space and mode.

// WCAG relative luminance of an sRGB triple in 0..1
function luminanceRgb(r, g, b) {
    function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

function luminance(c) {
    return luminanceRgb(c.r, c.g, c.b)
}

function contrast(a, b) {
    const la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function hslToRgb(h, s, l) {
    function channel(n) {
        const k = (n + h * 12) % 12
        const a = s * Math.min(l, 1 - l)
        return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1))
    }
    return [channel(0), channel(8), channel(4)]
}

// the colour of hue h and saturation s whose luminance is y
function tone(h, s, y) {
    let lo = 0, hi = 1
    for (let i = 0; i < 18; ++i) {
        const mid = (lo + hi) / 2
        const rgb = hslToRgb(h, s, mid)
        if (luminanceRgb(rgb[0], rgb[1], rgb[2]) < y)
            lo = mid
        else
            hi = mid
    }
    return Qt.hsla(h, s, (lo + hi) / 2, 1)
}

// a grey seed still has to name a hue; any will do
function seedHue(seed) {
    return seed.hslHue < 0 ? 0 : seed.hslHue
}

function seedVividness(seed) {
    return seed.hslHue < 0 ? 0 : seed.hslSaturation
}

// The base roles for a seed. Surfaces only take a fraction of the seed's
// vividness so pages stay readable; the sidebar, which frames the window,
// takes the most. The accent rises quickly so even a muted seed keeps a
// lively accent, and goes grey only for a fully grey seed.
function palette(hue, vividness, dark) {
    const h = hue
    const v = Math.max(0, Math.min(1, vividness))
    const accentSat = 1 - Math.pow(1 - v, 3)
    const p = dark ? {
        sidebarBg:   tone(h, 0.50 * v, 0.008 + 0.016 * v),
        bg:          tone(h, 0.22 * v, 0.016),
        surface:     tone(h, 0.20 * v, 0.032),
        surfaceHigh: tone(h, 0.18 * v, 0.052),
        border:      tone(h, 0.16 * v, 0.085),
        text:        tone(h, 0.40 * v, 0.76),
        textMuted:   tone(h, 0.18 * v, 0.27),
        accent:      tone(h, 0.90 * accentSat, 0.42),
        danger:      tone(0.97, 0.85, 0.36)
    } : {
        sidebarBg:   tone(h, 0.70 * v, 0.80 - 0.14 * v),
        bg:          tone(h, 0.40 * v, 0.94),
        surface:     tone(h, 0.32 * v, 0.855),
        surfaceHigh: tone(h, 0.30 * v, 0.775),
        border:      tone(h, 0.25 * v, 0.60),
        text:        tone(h, 0.35 * v, 0.016),
        textMuted:   tone(h, 0.18 * v, 0.13),
        accent:      tone(h, 0.95 * accentSat, 0.12),
        danger:      tone(0.97, 0.70, 0.12)
    }
    p.progressBg = p.surfaceHigh
    // whichever of white and the near-black text reads better on the accent
    const white = Qt.color("#ffffff")
    const ink = dark ? p.bg : p.text
    p.onAccent = contrast(p.accent, white) >= contrast(p.accent, ink) ? white : ink
    return p
}

function paletteForSeed(seed, dark) {
    return palette(seedHue(seed), seedVividness(seed), dark)
}
