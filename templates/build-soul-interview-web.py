#!/usr/bin/env python3
"""Build the bp-promo web page from the same source as the artifact.

One source of truth (soul-interview.src.html) -> two outputs:
  · the Artifact   — base64 fonts (CSP blocks font CDNs), light + dark
  · the web page   — /fonts/*.woff2 (house convention), light-only to match
                     its sibling /kit/install/soul, BP navbar lockup, noindex

Run:  python3 build-web.py
"""
import base64, pathlib, re, sys

HERE = pathlib.Path(__file__).parent
SRC = (HERE / "soul-interview.src.html").read_text()
FONTS = pathlib.Path("/Users/ozluv/Documents/Projects/bp-promo/public/fonts")

# ── 1. the Artifact build: inline the fonts ────────────────────────────────
art = SRC
for w in ("400", "500", "700", "800"):
    art = art.replace(f"__F{w}__", base64.b64encode((FONTS / f"fira-sans-{w}.woff2").read_bytes()).decode())
assert "__F" not in art, "unsubstituted font placeholder"
(HERE / "soul-interview.html").write_text(art)

# ── 2. the web build ───────────────────────────────────────────────────────
web = SRC

# 2a. local @font-face, matching PublicLayout.astro's convention
face = "\n".join(
    f"@font-face{{font-family:'Fira Sans';src:url('/fonts/fira-sans-{w}.woff2') format('woff2');"
    f"font-weight:{w};font-style:normal;font-display:swap}}"
    for w in ("400", "500", "700", "800")
)
web, n = re.subn(
    r"@font-face\{font-family:\"Fira Sans\".*?__F800__\) format\(\"woff2\"\)\}",
    face, web, flags=re.S)
assert n == 1, f"font block not replaced (n={n})"
assert "__F" not in web

# 2b. drop both dark-theme blocks — /kit/install/soul is light-only, and two
#     sibling kit pages must not disagree about theme.
web, n = re.subn(
    r"@media \(prefers-color-scheme:dark\)\{\s*:root:not\(\[data-theme=\"light\"\]\)\{.*?\n  \}\n\}\n", "", web, flags=re.S)
assert n == 1, f"dark media block not removed (n={n})"
web, n = re.subn(r':root\[data-theme="dark"\]\{.*?\n\}\n', "", web, flags=re.S)
assert n == 1, f"dark stamp block not removed (n={n})"
assert "data-theme" not in web and "prefers-color-scheme" not in web

# 2c. swap the page mark for the full BP lockup used across the kit
old_mark = re.search(r'<a class="mark" href="#top">.*?</a>', web, re.S)
assert old_mark, "nav mark not found"
web = web.replace(old_mark.group(0), """<a class="mark" href="#top" aria-label="Beautiful Possibilities">
      <svg class="bp-mark" viewBox="0 0 64 64" width="26" height="26" fill="currentColor" aria-hidden="true" focusable="false">
        <path class="s-main" d="M30 17 L34.5 29.5 L47 34 L34.5 38.5 L30 51 L25.5 38.5 L13 34 L25.5 29.5 Z"></path>
        <path class="s-twk" d="M44 14 L46 19 L51 21 L46 23 L44 28 L42 23 L37 21 L42 19 Z"></path>
        <path class="s-twk2" d="M49 40 L50.4 43.1 L53.5 44.5 L50.4 45.9 L49 49 L47.6 45.9 L44.5 44.5 L47.6 43.1 Z"></path>
      </svg>
      <span class="bp-word"><span class="bp-w1">Beautiful</span> <span class="bp-w2">Possibilities</span></span>
    </a>""")

# the two counter-rotating twinkles from soul.html / PublicLayout
web = web.replace(
    "@keyframes spinCW{to{transform:rotate(360deg)}}",
    "@keyframes spinCW{to{transform:rotate(360deg)}}\n@keyframes spinCCW{to{transform:rotate(-360deg)}}")
web = web.replace(
    ".s-main{transform-box:fill-box;transform-origin:center;animation:spinCW 22s linear infinite}",
    ".s-main{transform-box:fill-box;transform-origin:center;animation:spinCW 20s linear infinite}\n"
    ".s-twk{transform-box:fill-box;transform-origin:center;animation:spinCCW 15s linear infinite}\n"
    ".s-twk2{transform-box:fill-box;transform-origin:center;animation:spinCW 12s linear infinite}\n"
    ".bp-word{font-size:.95rem;line-height:1;letter-spacing:-.01em;white-space:nowrap}\n"
    ".bp-w1{font-weight:500;color:var(--ink-soft)}\n"
    ".bp-w2{font-weight:800;color:var(--ink)}")
web = web.replace(
    "@media (prefers-reduced-motion:reduce){.s-main{animation:none}}",
    "@media (prefers-reduced-motion:reduce){.s-main,.s-twk,.s-twk2{animation:none}}")
web = web.replace(".railnav .mark b{font-weight:800;font-size:.9rem;letter-spacing:-.01em;white-space:nowrap}", "")

# 2d. wrap as a standalone document
title = re.search(r"<title>(.*?)</title>", web).group(1)
body = web.split("</style>", 1)[1]
style = web.split("<style>", 1)[1].split("</style>", 1)[0]

doc = f"""<!doctype html>
<!-- Hermes Kit · The SOUL Interview — the OPERATOR's script: one person interviews
     another with a recorder running. Sibling of soul.html, which is the person-facing
     self-interview prompt. Generated from hermes/templates by build-web.py — edit the
     source, not this file. Hosted at beautiful-possibilities.com/kit/install/soul-interview -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{title}</title>
<link rel="preload" href="/fonts/fira-sans-500.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/fira-sans-400.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/fira-sans-800.woff2" as="font" type="font/woff2" crossorigin>
<style>{style}</style>
</head>
<body>{body}</body>
</html>
"""
(HERE / "soul-interview.web.html").write_text(doc)

print(f"artifact : soul-interview.html      {(HERE/'soul-interview.html').stat().st_size/1024:>6.0f} KB")
print(f"web page : soul-interview.web.html  {(HERE/'soul-interview.web.html').stat().st_size/1024:>6.0f} KB")
