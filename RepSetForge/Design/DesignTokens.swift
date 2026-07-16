// DesignTokens.swift
// GENERATED from Docs/repsetforge-tokens.json by Scripts/generate_design_tokens.py — DO NOT EDIT.
// Token set: RepSetForge v1.0

import SwiftUI
import UIKit

enum DT {
    enum Colors {
        static let surface = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.0510, green: 0.0588, blue: 0.0706, alpha: 1.0000)
                : UIColor(red: 0.9686, green: 0.9725, blue: 0.9804, alpha: 1.0000)
        })
        static let surfaceRaised = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.0863, green: 0.0980, blue: 0.1176, alpha: 1.0000)
                : UIColor(red: 1.0000, green: 1.0000, blue: 1.0000, alpha: 1.0000)
        })
        static let surfaceInput = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.1137, green: 0.1294, blue: 0.1529, alpha: 1.0000)
                : UIColor(red: 0.9333, green: 0.9412, blue: 0.9569, alpha: 1.0000)
        })
        static let hairline = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.1490, green: 0.1686, blue: 0.2000, alpha: 1.0000)
                : UIColor(red: 0.8863, green: 0.8980, blue: 0.9176, alpha: 1.0000)
        })
        static let textPrimary = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.9490, green: 0.9569, blue: 0.9686, alpha: 1.0000)
                : UIColor(red: 0.0667, green: 0.0784, blue: 0.0941, alpha: 1.0000)
        })
        static let textSecondary = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.5451, green: 0.5765, blue: 0.6314, alpha: 1.0000)
                : UIColor(red: 0.3608, green: 0.3961, blue: 0.4471, alpha: 1.0000)
        })
        static let textTertiary = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.3529, green: 0.3843, blue: 0.4392, alpha: 1.0000)
                : UIColor(red: 0.5961, green: 0.6275, blue: 0.6745, alpha: 1.0000)
        })
        static let signal = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.1882, green: 0.8980, blue: 0.5216, alpha: 1.0000)
                : UIColor(red: 0.1216, green: 0.6627, blue: 0.4078, alpha: 1.0000)
        })
        static let signalDim = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.1882, green: 0.8980, blue: 0.5216, alpha: 0.1400)
                : UIColor(red: 0.1216, green: 0.6627, blue: 0.4078, alpha: 0.1200)
        })
        static let onSignal = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.0275, green: 0.0745, blue: 0.0471, alpha: 1.0000)
                : UIColor(red: 1.0000, green: 1.0000, blue: 1.0000, alpha: 1.0000)
        })
        static let pr = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.9608, green: 0.7725, blue: 0.2588, alpha: 1.0000)
                : UIColor(red: 0.7216, green: 0.5255, blue: 0.0431, alpha: 1.0000)
        })
        static let prDim = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.9608, green: 0.7725, blue: 0.2588, alpha: 0.1400)
                : UIColor(red: 0.7216, green: 0.5255, blue: 0.0431, alpha: 0.1200)
        })
        static let warning = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 1.0000, green: 0.4784, blue: 0.3490, alpha: 1.0000)
                : UIColor(red: 0.8510, green: 0.3333, blue: 0.1843, alpha: 1.0000)
        })
        static let destructive = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 1.0000, green: 0.3647, blue: 0.3647, alpha: 1.0000)
                : UIColor(red: 0.8510, green: 0.2118, blue: 0.2118, alpha: 1.0000)
        })
    }

    enum Type {
        static let largeTitle = Font.system(size: 26, weight: .heavy, design: .monospaced)
        static let largeTitleTracking: CGFloat = -0.78  // em -0.03 × 26pt
        static let title = Font.system(size: 20, weight: .heavy, design: .monospaced)
        static let titleTracking: CGFloat = -0.40  // em -0.02 × 20pt
        static let heading = Font.system(size: 15, weight: .heavy, design: .monospaced)
        static let body = Font.system(size: 14, weight: .semibold, design: .monospaced)
        static let secondary = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let eyebrow = Font.system(size: 10, weight: .bold, design: .monospaced)
        static let eyebrowTracking: CGFloat = 1.00  // em 0.1 × 10pt
        static let numericLarge = Font.system(size: 20, weight: .semibold, design: .monospaced).monospacedDigit()
        static let numericRow = Font.system(size: 13, weight: .medium, design: .monospaced).monospacedDigit()
    }

    enum Spacing {
        static let base: CGFloat = 4
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let screenGutter: CGFloat = 10
        static let cardPadding: CGFloat = 10
        static let cardGap: CGFloat = 8
        static let setRowHeightVisual: CGFloat = 36
        static let setRowHitTarget: CGFloat = 44
    }

    enum Radius {
        static let card: CGFloat = 10
        static let input: CGFloat = 8
        static let pill: CGFloat = 22
        static let checkbox: CGFloat = 8
        static let segment: CGFloat = 9
        static let phoneSheet: CGFloat = 34
    }

    enum Motion {
        static let setCompleteDuration: Double = 0.25
        // spring cubic-bezier(0.34,1.56,0.64,1) ≈ bouncy spring
        static let setComplete = Animation.spring(response: 0.25, dampingFraction: 0.6)
        static let stateChangeDuration: Double = 0.2
        static let stateChange = Animation.easeOut(duration: 0.2)
        static let reducedMotionFade = Animation.easeInOut(duration: 0.15)
    }

    enum Touch {
        static let minimum: CGFloat = 44
        static let setCompleteWidth: CGFloat = 52
        static let setCompleteHeight: CGFloat = 44
        static let tabBarItem: CGFloat = 48
    }

    enum Elevation {
        // flat: 1px hairline border only, no shadow
        static let raisedShadowColor = SwiftUI.Color.black.opacity(0.45)
        static let raisedShadowRadius: CGFloat = 20
        static let raisedShadowY: CGFloat = 6
        static let fabShadowOpacity: Double = 0.35
        static let fabShadowRadius: CGFloat = 14
        static let fabShadowY: CGFloat = 4
    }
}
