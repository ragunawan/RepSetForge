import Foundation

/// Playable hero archetypes for the passive RPG scene. The MVP defaults the
/// player to `.knight`; the raw value is persisted on RPGEncounterState so a
/// class-selection screen can be added later without a migration.
enum RPGClass: String, Codable, CaseIterable, Identifiable, Sendable {
    case knight
    case ranger
    case mage
    case monk
    case rogue

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Drives which basic-attack visual the passive scene plays.
    enum WeaponStyle: String, Sendable {
        case melee      // sword slash
        case ranged     // bow shot
        case cast       // staff cast
        case fist       // strike
        case dagger     // fast dash/slash
    }

    var weaponStyle: WeaponStyle {
        switch self {
        case .knight: return .melee
        case .ranger: return .ranged
        case .mage: return .cast
        case .monk: return .fist
        case .rogue: return .dagger
        }
    }

    var flavor: String {
        switch self {
        case .knight: return "Durable melee fighter with sword and shield."
        case .ranger: return "Ranged hunter striking with quick precision."
        case .mage: return "Elemental caster wielding a focus staff."
        case .monk: return "Balanced endurance fighter with iron fists."
        case .rogue: return "Fast skirmisher dealing burst damage."
        }
    }

    /// Hero animation kinds. Frame counts must match scripts/generate_pixel_assets.py.
    enum HeroAnimation: String, Sendable {
        case idle
        case walk
        case attack
        case cast

        var frameCount: Int {
            switch self {
            case .idle, .walk: return 4
            case .attack, .cast: return 3
            }
        }
    }

    /// Asset name for one animation frame. Looping animations wrap the index;
    /// one-shot animations (attacks, casts) clamp on their final frame.
    func spriteFrame(_ animation: HeroAnimation, index: Int, looping: Bool = true) -> String {
        let count = animation.frameCount
        let frame = looping ? ((index % count) + count) % count : min(max(index, 0), count - 1)
        return "rpg_class_\(rawValue)_\(animation.rawValue)\(frame)"
    }
}
