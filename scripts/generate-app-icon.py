#!/usr/bin/env python3
"""
Generate the WSPT To Do app icon (design option "5a": green tile, chevron
knocked through to the cream queue behind) at all sizes required by
WSPTTodo/WSPTTodo/Assets.xcassets/AppIcon.appiconset, for both macOS (rounded
squircle + soft shadow, baked in) and iOS (full-bleed square; the OS applies
its own mask).

Source: Claude Design canvas "WSPT To Do App UI", turn 5, option 5a
(https://claude.ai/design/p/bd3126ec-24af-432c-a4ca-65a876a2afd9). Content
geometry/colors are copied verbatim from the three hand-tuned optical sizes
in that design (176px/64px/32px tiers) and reused at the appiconset sizes
closest to each tier.

Requires `rsvg-convert` (brew install librsvg). Re-run this after changing
the icon; it overwrites the PNGs in place under AppIcon.appiconset.
"""
import os
import subprocess

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPICONSET = os.path.join(
    REPO_ROOT, "WSPTTodo", "WSPTTodo", "Assets.xcassets", "AppIcon.appiconset"
)

CREAM_BG = '<linearGradient id="creamBg" x1="0%" y1="0%" x2="27%" y2="100%"><stop offset="0%" stop-color="#fffdf9"/><stop offset="100%" stop-color="#f3ece0"/></linearGradient>'

# Content tiers, copied verbatim (coords/stroke-widths/opacities) from the
# design doc's 176px / 64px / 32px renderings of option 5a.
TIER_L_DEFS = '''
<mask id="chevL"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/></mask>
<mask id="barsL"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="19" stroke-linecap="round" stroke-linejoin="round"/></mask>
<linearGradient id="grnL" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#55916a"/><stop offset="0.55" stop-color="#3f7a4e"/><stop offset="1" stop-color="#305f3d"/></linearGradient>
'''
TIER_L_BODY = '''
<g mask="url(#barsL)">
<rect x="15" y="21.6" width="70" height="7.4" rx="3.7" fill="#3f7a4e"/>
<rect x="15" y="37" width="54.6" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.62"/>
<rect x="15" y="52.4" width="39.2" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.38"/>
<rect x="15" y="67.8" width="23.8" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.2"/>
</g>
<rect width="100" height="100" fill="url(#grnL)" mask="url(#chevL)" opacity="0.82"/>
'''

TIER_M_DEFS = '''
<mask id="chevM"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/></mask>
<mask id="barsM"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/></mask>
'''
TIER_M_BODY = '''
<g mask="url(#barsM)">
<rect x="15" y="21.6" width="70" height="7.4" rx="3.7" fill="#3f7a4e"/>
<rect x="15" y="37" width="54.6" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.62"/>
<rect x="15" y="52.4" width="39.2" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.38"/>
<rect x="15" y="67.8" width="23.8" height="7.4" rx="3.7" fill="#3f7a4e" opacity="0.2"/>
</g>
<rect width="100" height="100" fill="#3f7a4e" mask="url(#chevM)" opacity="0.82"/>
'''

TIER_S_DEFS = '''
<mask id="chevS"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/></mask>
<mask id="barsS"><rect width="100" height="100" fill="#fff"/><polyline points="43,26 73,50 43,74" fill="none" stroke="#000" stroke-width="23" stroke-linecap="round" stroke-linejoin="round"/></mask>
'''
TIER_S_BODY = '''
<g mask="url(#barsS)">
<rect x="14" y="22" width="72" height="9" rx="4.5" fill="#3f7a4e"/>
<rect x="14" y="45.5" width="53" height="9" rx="4.5" fill="#3f7a4e" opacity="0.55"/>
<rect x="14" y="69" width="34" height="9" rx="4.5" fill="#3f7a4e" opacity="0.3"/>
</g>
<rect width="100" height="100" fill="#3f7a4e" mask="url(#chevS)" opacity="0.85"/>
'''

TIERS = {
    "L": (TIER_L_DEFS, TIER_L_BODY),
    "M": (TIER_M_DEFS, TIER_M_BODY),
    "S": (TIER_S_DEFS, TIER_S_BODY),
}

# Relative geometry for the macOS rounded-squircle treatment, expressed as
# fractions of the canvas so it scales identically at every pixel size.
CONTENT_FRACTION = 0.90625  # content square / canvas (matches the design's tile proportions)
RADIUS_FRACTION = 0.2261    # corner radius / content square (matches the 40/176 ratio in the design)
SHADOW_DY_FRACTION = 0.00586
SHADOW_BLUR_FRACTION = 0.0078125
SHADOW_OPACITY = 0.30


def content_svg(tier_defs, tier_body):
    return f'''<defs>{CREAM_BG}{tier_defs}</defs>
<rect width="100" height="100" fill="url(#creamBg)"/>
{tier_body}'''


def ios_svg(tier):
    tier_defs, tier_body = TIERS[tier]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
{content_svg(tier_defs, tier_body)}
</svg>'''


def mac_svg(tier):
    tier_defs, tier_body = TIERS[tier]
    content_side = CONTENT_FRACTION * 100
    margin = (100 - content_side) / 2
    radius = RADIUS_FRACTION * content_side
    dy = SHADOW_DY_FRACTION * 100
    blur = SHADOW_BLUR_FRACTION * 100
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<defs>
{CREAM_BG}
{tier_defs}
<filter id="shadow" x="-50%" y="-50%" width="200%" height="200%">
<feGaussianBlur in="SourceGraphic" stdDeviation="{blur}"/>
</filter>
<clipPath id="tileClip">
<rect x="{margin}" y="{margin}" width="{content_side}" height="{content_side}" rx="{radius}" ry="{radius}"/>
</clipPath>
</defs>
<rect x="{margin}" y="{margin + dy}" width="{content_side}" height="{content_side}" rx="{radius}" ry="{radius}" fill="#2b2723" opacity="{SHADOW_OPACITY}" filter="url(#shadow)"/>
<g clip-path="url(#tileClip)">
<g transform="translate({margin},{margin}) scale({content_side / 100.0})">
{content_svg(tier_defs, tier_body)}
</g>
</g>
</svg>'''


def render(svg_text, size, out_path):
    svg_path = out_path + ".svg"
    with open(svg_path, "w") as f:
        f.write(svg_text)
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", out_path, svg_path],
        check=True,
    )
    os.remove(svg_path)


# macOS sizes -> content tier (matches nearest hand-tuned optical size in the design)
MAC_SIZES = {
    16: "S",
    32: "S",
    64: "M",
    128: "M",
    256: "L",
    512: "L",
    1024: "L",
}

if __name__ == "__main__":
    for size, tier in MAC_SIZES.items():
        render(mac_svg(tier), size, os.path.join(APPICONSET, f"mac-{size}.png"))
        print(f"wrote mac-{size}.png")

    # iOS: single 1024 universal size, full-bleed square (no rounding/shadow baked in)
    render(ios_svg("L"), 1024, os.path.join(APPICONSET, "ios-1024.png"))
    print("wrote ios-1024.png")

    print(
        "\nRename mac-*.png / ios-1024.png to the filenames listed in "
        "Contents.json (icon_16x16.png, icon_16x16@2x.png, icon_32x32.png, "
        "icon_32x32@2x.png, icon_128x128.png, icon_128x128@2x.png, "
        "icon_256x256.png, icon_256x256@2x.png, icon_512x512.png, "
        "icon_512x512@2x.png, icon_1024x1024.png) — several appiconset slots "
        "share one rendered size (e.g. mac-32.png fills both 16x16@2x and "
        "32x32@1x)."
    )
