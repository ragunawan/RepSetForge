import Foundation
import Observation
import SwiftData

/// Phases of the passive Home-scene loop. The view renders sprites and effects
/// purely from this state; all pacing lives in the view model's tasks.
enum RPGScenePhase: String, Equatable {
    case walking
    case enemyAppearing
    case enemyAttacking
    case playerAttacking
    case skillUsed
    case enemyHit
    case enemyDefeated
    case bossDefeated
}

/// A short-lived floating combat text entry.
struct RPGCombatEvent: Identifiable, Equatable {
    enum Kind {
        case damage
        case skill
        case status
    }

    let id = UUID()
    let text: String
    let kind: Kind
    /// Horizontal jitter (in points) so stacked numbers don't overlap.
    let jitter: CGFloat
}

/// Drives the passive RPG encounter loop: walk → enemy appears → auto attacks
/// and occasional skills → defeat → walk again. When a milestone boss is
/// active it replaces all normal spawns until the milestone quest is done.
///
/// Two cancellable tasks run while the scene is visible: the encounter loop
/// (beats of 0.3–1s) and a frame ticker that advances sprite animation every
/// 0.15s. The owning view stops both whenever the scene is off screen or the
/// app is backgrounded.
@MainActor
@Observable
final class RPGEncounterViewModel {

    /// Seconds per animation frame; attack beats are multiples of this so
    /// one-shot animations land exactly on their frame counts.
    static let frameDuration: Double = 0.15

    // MARK: Rendered state

    private(set) var phase: RPGScenePhase = .walking
    private(set) var frameTick = 0
    private(set) var currentMonster: RPGMonster?
    private(set) var currentBoss: RPGBoss?
    private(set) var activeSkill: RPGSkill?
    private(set) var combatEvents: [RPGCombatEvent] = []
    private(set) var playerClass: RPGClass = .knight

    private var phaseStartTick = 0
    /// The hero holds the follow-through of their last swing while the enemy reacts.
    private var lastActionAnimation: RPGClass.HeroAnimation = .attack

    var isBossFight: Bool { currentBoss != nil }

    var backgroundAsset: String {
        currentBoss?.backgroundAsset ?? "rpg_bg_field"
    }

    private var ticksIntoPhase: Int { max(0, frameTick - phaseStartTick) }

    /// Current hero sprite frame, derived from phase + animation tick.
    var playerSpriteAsset: String {
        switch phase {
        case .walking, .enemyAppearing:
            return playerClass.spriteFrame(.walk, index: frameTick)
        case .playerAttacking:
            return playerClass.spriteFrame(lastActionAnimation, index: ticksIntoPhase, looping: false)
        case .skillUsed:
            return playerClass.spriteFrame(lastActionAnimation, index: ticksIntoPhase, looping: false)
        case .enemyHit:
            return playerClass.spriteFrame(lastActionAnimation, index: .max, looping: false)
        case .enemyAttacking, .enemyDefeated, .bossDefeated:
            return playerClass.spriteFrame(.idle, index: frameTick)
        }
    }

    /// Current enemy sprite frame, or nil when the field is empty.
    var enemySpriteAsset: String? {
        if let boss = currentBoss {
            switch phase {
            case .enemyAttacking:
                return boss.spriteFrame(.attack, index: ticksIntoPhase)
            case .bossDefeated:
                // Boss collapse plays at half speed for weight.
                return boss.spriteFrame(.defeat, index: ticksIntoPhase / 2)
            default:
                return boss.spriteFrame(.idle, index: frameTick)
            }
        }
        guard let monster = currentMonster else { return nil }
        switch phase {
        case .enemyAttacking:
            return monster.spriteFrame(.attack, index: ticksIntoPhase)
        case .enemyHit:
            return monster.spriteFrame(.hit, index: 0)
        case .enemyDefeated:
            return monster.spriteFrame(.defeat, index: ticksIntoPhase)
        default:
            return monster.spriteFrame(.idle, index: frameTick)
        }
    }

    var statusText: String {
        if let boss = currentBoss {
            if phase == .bossDefeated { return boss.defeatText }
            let quest = RPGBossRegistry.milestoneQuest(for: boss)
            return quest.map { "\(boss.name) — \($0.detail)" } ?? boss.phaseText
        }
        if let monster = currentMonster {
            return monster.name
        }
        return "Wandering the training fields…"
    }

    // MARK: Configuration

    private var snapshot = RPGProgressionSnapshot()
    private var state: RPGEncounterState?
    private var equippedLoadout: [RPGEquipmentSlot: RPGEquipment] = [:]
    private var skillCooldowns: [String: Date] = [:]
    private var rng = SystemRandomNumberGenerator()
    private var loopTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?

    /// Called by the view whenever SwiftData state changes (level-ups, quest
    /// completions). Safe to call repeatedly; boss activation happens here so
    /// a milestone level reached mid-fight is picked up on the next beat.
    func configure(snapshot: RPGProgressionSnapshot, state: RPGEncounterState?) {
        self.snapshot = snapshot
        self.state = state
        if let state {
            playerClass = state.rpgClass
            BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot)
        }
        equippedLoadout = RPGEquipmentRegistry.loadout(for: playerClass, atLevel: snapshot.currentLevel)
    }

    var loadout: [RPGEquipmentSlot: RPGEquipment] { equippedLoadout }

    // MARK: Loop control

    func start() {
        if loopTask == nil {
            loopTask = Task { [weak self] in
                await self?.run()
            }
        }
        if tickerTask == nil {
            tickerTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.frameDuration))
                    self?.frameTick += 1
                }
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: Passive loop

    private func run() async {
        while !Task.isCancelled {
            if let state, let boss = BossMilestoneService.activeBoss(state: state) {
                await fightBoss(boss)
            } else {
                await walk(seconds: Double.random(in: 2.0...3.5, using: &rng))
                guard !Task.isCancelled else { return }
                if let state, let boss = BossMilestoneService.activeBoss(state: state) {
                    await fightBoss(boss)
                } else if let monster = MonsterSpawnService.randomMonster(forLevel: snapshot.currentLevel, using: &rng) {
                    await fight(monster)
                }
            }
        }
    }

    private func setPhase(_ newPhase: RPGScenePhase) {
        guard phase != newPhase else { return }
        phase = newPhase
        phaseStartTick = frameTick
    }

    private func walk(seconds: Double) async {
        setPhase(.walking)
        currentMonster = nil
        var remaining = seconds
        while remaining > 0 && !Task.isCancelled {
            await sleep(0.3)
            remaining -= 0.3
        }
    }

    private func fight(_ monster: RPGMonster) async {
        currentMonster = monster
        setPhase(.enemyAppearing)
        await sleep(0.8)
        guard !Task.isCancelled else { return }

        // The monster gets the first lunge; the hero counters.
        setPhase(.enemyAttacking)
        await sleep(Self.frameDuration * 3)

        var hitsRemaining = MonsterSpawnService.hitsToDefeat(monster)
        while hitsRemaining > 0 && !Task.isCancelled {
            let skill = pickSkill(bossFight: false)
            hitsRemaining -= await attack(with: skill)
        }
        guard !Task.isCancelled else { return }

        setPhase(.enemyDefeated)
        emit(.init(text: "Defeated!", kind: .status, jitter: 0))
        await sleep(Self.frameDuration * 4)
        currentMonster = nil
    }

    private func fightBoss(_ boss: RPGBoss) async {
        if currentBoss != boss {
            currentBoss = boss
            currentMonster = nil
            setPhase(.enemyAppearing)
            emit(.init(text: boss.phaseText, kind: .status, jitter: 0))
            await sleep(1.2)
        }

        // One round of passive attacks, then the boss retaliates and the
        // milestone quest is re-checked.
        for _ in 0..<4 where !Task.isCancelled {
            let skill = pickSkill(bossFight: true)
            _ = await attack(with: skill)
        }
        guard !Task.isCancelled else { return }

        setPhase(.enemyAttacking)
        await sleep(Self.frameDuration * 4)
        guard !Task.isCancelled, let state else { return }

        if BossMilestoneService.isActiveBossDefeated(state: state, snapshot: snapshot) {
            setPhase(.bossDefeated)
            emit(.init(text: boss.defeatText, kind: .status, jitter: 0))
            BossMilestoneService.completeActiveBoss(state: state)
            try? state.modelContext?.save()
            await sleep(2.0)
            currentBoss = nil
            setPhase(.walking)
        } else {
            await sleep(0.6)
        }
    }

    /// Performs one basic attack or skill; returns how many "hits" it counts for.
    private func attack(with skill: RPGSkill?) async -> Int {
        if let skill {
            activeSkill = skill
            skillCooldowns[skill.id] = Date.now.addingTimeInterval(skill.cooldown)
            lastActionAnimation = (skill.animation == .slash || skill.animation == .dash) ? .attack : .cast
            setPhase(.skillUsed)
            emit(.init(text: skill.name, kind: .skill, jitter: CGFloat.random(in: -8...8, using: &rng)))
            await sleep(Self.frameDuration * 4)
        } else {
            lastActionAnimation = .attack
            setPhase(.playerAttacking)
            await sleep(Self.frameDuration * 3)
        }
        guard !Task.isCancelled else { return 0 }

        setPhase(.enemyHit)
        let damage = damageAmount(isSkill: skill != nil)
        emit(.init(text: "-\(damage)", kind: .damage, jitter: CGFloat.random(in: -10...10, using: &rng)))
        await sleep(Self.frameDuration * 3)
        activeSkill = nil
        return skill != nil ? 2 : 1
    }

    /// Flavor damage number scaled by level and the equipped weapon's bonuses.
    private func damageAmount(isSkill: Bool) -> Int {
        let weaponBonus = equippedLoadout[.weapon]?.bonuses.values.reduce(0, +) ?? 0
        let base = 2 + snapshot.currentLevel + weaponBonus
        let spread = Int.random(in: 0...max(2, base / 4), using: &rng)
        return (base + spread) * (isSkill ? 2 : 1)
    }

    /// Occasionally selects a skill: ~30% chance per beat, respecting cooldowns
    /// and weighting by each skill's passive usage weight.
    private func pickSkill(bossFight: Bool) -> RPGSkill? {
        guard Int.random(in: 0..<100, using: &rng) < 30 else { return nil }
        let now = Date.now
        let ready = RPGSkillRegistry
            .usable(by: playerClass, atLevel: snapshot.currentLevel, bossFight: bossFight)
            .filter { (skillCooldowns[$0.id] ?? .distantPast) <= now }
        guard !ready.isEmpty else { return nil }

        let totalWeight = ready.reduce(0) { $0 + $1.passiveWeight }
        var roll = Int.random(in: 0..<totalWeight, using: &rng)
        for skill in ready {
            roll -= skill.passiveWeight
            if roll < 0 { return skill }
        }
        return ready.last
    }

    // MARK: Helpers

    private func emit(_ event: RPGCombatEvent) {
        combatEvents.append(event)
        let id = event.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            self?.combatEvents.removeAll { $0.id == id }
        }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
