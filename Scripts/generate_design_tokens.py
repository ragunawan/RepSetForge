#!/usr/bin/env python3
"""Generate RepSetForge/Design/DesignTokens.swift from Docs/repsetforge-tokens.json.

Run from repo root: python3 Scripts/generate_design_tokens.py
Never edit DesignTokens.swift by hand.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = json.loads((ROOT / "Docs" / "repsetforge-tokens.json").read_text())
OUT = ROOT / "RepSetForge" / "Design" / "DesignTokens.swift"


def parse_color(value: str):
    """Return (r, g, b, a) floats 0-1 from #RRGGBB or rgba(r,g,b,a)."""
    value = value.strip()
    if value.startswith("#"):
        h = value[1:]
        return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)
    m = re.match(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)", value)
    if not m:
        raise ValueError(f"unparseable color: {value}")
    r, g, b, a = m.groups()
    return int(r) / 255, int(g) / 255, int(b) / 255, float(a)


def swift_weight(w: int) -> str:
    return {
        500: ".medium", 600: ".semibold", 700: ".bold", 800: ".heavy",
    }.get(w, ".regular")


dark = TOKENS["color"]["dark"]
light = TOKENS["color"]["light"]
assert set(dark) == set(light), "dark/light token keys must match"

lines = []
lines.append("// DesignTokens.swift")
lines.append("// GENERATED from Docs/repsetforge-tokens.json by Scripts/generate_design_tokens.py — DO NOT EDIT.")
lines.append(f"// Token set: {TOKENS['meta']['name']} v{TOKENS['meta']['version']}")
lines.append("")
lines.append("import SwiftUI")
lines.append("import UIKit")
lines.append("")
lines.append("enum DT {")

# Colors — adaptive light/dark pairs via UIColor dynamic provider.
lines.append("    enum Color2 {")  # placeholder replaced below
lines.pop()
lines.append("    enum Colors {")
for name in dark:
    dr, dg, db, da = parse_color(dark[name])
    lr, lg, lb, la = parse_color(light[name])
    lines.append(f"        static let {name} = Color(UIColor {{ trait in")
    lines.append("            trait.userInterfaceStyle == .dark")
    lines.append(f"                ? UIColor(red: {dr:.4f}, green: {dg:.4f}, blue: {db:.4f}, alpha: {da:.4f})")
    lines.append(f"                : UIColor(red: {lr:.4f}, green: {lg:.4f}, blue: {lb:.4f}, alpha: {la:.4f})")
    lines.append("        })")
lines.append("    }")
lines.append("")

# Typography — monospaced throughout; numeric styles get tabular figures via .monospacedDigit().
lines.append("    enum Type {")
for name, spec in TOKENS["typography"]["scale"].items():
    size = spec["size"]
    weight = swift_weight(spec["weight"])
    is_numeric = spec.get("family") == "numeric"
    expr = f"Font.system(size: {size}, weight: {weight}, design: .monospaced)"
    if is_numeric:
        expr += ".monospacedDigit()"
    lines.append(f"        static let {name} = {expr}")
    if "tracking" in spec:
        lines.append(f"        static let {name}Tracking: CGFloat = {spec['tracking'] * size:.2f}  // em {spec['tracking']} × {size}pt")
lines.append("    }")
lines.append("")

# Spacing
sp = TOKENS["spacing"]
lines.append("    enum Spacing {")
lines.append(f"        static let base: CGFloat = {sp['base']}")
for i, step in enumerate(sp["steps"], start=1):
    lines.append(f"        static let s{step}: CGFloat = {step}")
lines.append(f"        static let screenGutter: CGFloat = {sp['screenGutter']}")
lines.append(f"        static let cardPadding: CGFloat = {sp['cardPadding']}")
lines.append(f"        static let cardGap: CGFloat = {sp['cardGap']}")
lines.append(f"        static let setRowHeightVisual: CGFloat = {sp['setRowHeightVisual']}")
lines.append(f"        static let setRowHitTarget: CGFloat = {sp['setRowHitTarget']}")
lines.append("    }")
lines.append("")

# Radius
lines.append("    enum Radius {")
for name, val in TOKENS["radius"].items():
    lines.append(f"        static let {name}: CGFloat = {val}")
lines.append("    }")
lines.append("")

# Motion — durations in seconds; springs per token curve, reduced-motion handled at call sites.
motion = TOKENS["motion"]
lines.append("    enum Motion {")
lines.append(f"        static let setCompleteDuration: Double = {motion['setComplete']['duration'] / 1000}")
lines.append("        // spring cubic-bezier(0.34,1.56,0.64,1) ≈ bouncy spring")
lines.append(f"        static let setComplete = Animation.spring(response: {motion['setComplete']['duration'] / 1000}, dampingFraction: 0.6)")
lines.append(f"        static let stateChangeDuration: Double = {motion['stateChange']['duration'] / 1000}")
lines.append(f"        static let stateChange = Animation.easeOut(duration: {motion['stateChange']['duration'] / 1000})")
lines.append("        static let reducedMotionFade = Animation.easeInOut(duration: 0.15)")
lines.append("    }")
lines.append("")

# Touch targets
lines.append("    enum Touch {")
lines.append("        static let minimum: CGFloat = 44")
lines.append("        static let setCompleteWidth: CGFloat = 52")
lines.append("        static let setCompleteHeight: CGFloat = 44")
lines.append("        static let tabBarItem: CGFloat = 48")
lines.append("    }")
lines.append("")

# Elevation
lines.append("    enum Elevation {")
lines.append("        // flat: 1px hairline border only, no shadow")
lines.append("        static let raisedShadowColor = SwiftUI.Color.black.opacity(0.45)")
lines.append("        static let raisedShadowRadius: CGFloat = 20")
lines.append("        static let raisedShadowY: CGFloat = 6")
lines.append("        static let fabShadowOpacity: Double = 0.35")
lines.append("        static let fabShadowRadius: CGFloat = 14")
lines.append("        static let fabShadowY: CGFloat = 4")
lines.append("    }")
lines.append("}")
lines.append("")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines))
print(f"wrote {OUT.relative_to(ROOT)} ({len(lines)} lines)")
