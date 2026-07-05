import CloudKit
import Foundation

/// A global, opt-in leaderboard via CloudKit's **public** database — a
/// materially different sharing model than the rest of this app, which
/// syncs through the *private* database (visible only to the signed-in
/// user's own devices). Publishing here makes a player's chosen display
/// name, level, streak, and quest count visible to every other player of
/// the app; nothing else about their data is ever shared this way.
///
/// This is deliberately scoped down from "friend leaderboards" in the
/// original backlog item: a true friend-only circle needs its own social
/// graph (add/accept/manage relationships), which is a separate, larger
/// feature. A global opt-in leaderboard delivers the comparative-progress
/// value without that added complexity, using CloudKit alone — no external
/// server. Real friend-only leaderboards, shared challenges, and
/// collaborative party quests (which need CloudKit's `CKShare` mechanism,
/// a different mechanism again from a public-database leaderboard) remain
/// open follow-ups.
///
/// Note for production: this container's Development environment
/// auto-creates the queryable/sortable indexes this record type needs the
/// first time a query runs against it. Promoting to a Production
/// environment requires reviewing and configuring those indexes (and the
/// record type's security roles) via the CloudKit Dashboard — a step
/// outside Xcode/this codebase that only the account holder can do.
enum LeaderboardService {
    struct Entry: Identifiable, Equatable {
        let id: String
        let displayName: String
        let level: Int
        let totalXP: Int
        let streakDays: Int
        let completedQuestCount: Int
    }

    private static let recordType = "LeaderboardEntry"
    private static let container = CKContainer(identifier: "iCloud.dev.gnwn.RepSetForge")

    private static func recordID(for userRecordID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "leaderboard-\(userRecordID.recordName)")
    }

    /// Publishes (or updates in place) the current player's entry. Call
    /// this when the player opts in and again whenever they view the
    /// leaderboard, rather than on every quest completion — keeps this
    /// network call decoupled from the core logging flow entirely.
    static func publish(
        displayName: String,
        level: Int,
        totalXP: Int,
        streakDays: Int,
        completedQuestCount: Int
    ) async throws {
        let userRecordID = try await container.userRecordID()
        let record = CKRecord(recordType: recordType, recordID: recordID(for: userRecordID))
        record["displayName"] = displayName
        record["level"] = level
        record["totalXP"] = totalXP
        record["streakDays"] = streakDays
        record["completedQuestCount"] = completedQuestCount
        record["updatedAt"] = Date.now
        _ = try await container.publicCloudDatabase.save(record)
    }

    /// Removes the current player's entry — call when opting out.
    static func removeEntry() async throws {
        let userRecordID = try await container.userRecordID()
        try await container.publicCloudDatabase.deleteRecord(withID: recordID(for: userRecordID))
    }

    /// The current player's own record ID, so the leaderboard view can
    /// highlight their row without a second round-trip.
    static func currentEntryID() async throws -> String {
        try await container.userRecordID().recordName
    }

    /// Top entries by level (ties broken by total XP), highest first.
    static func fetchTopEntries(limit: Int = 50) async throws -> [Entry] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [
            NSSortDescriptor(key: "level", ascending: false),
            NSSortDescriptor(key: "totalXP", ascending: false)
        ]
        let (matchResults, _) = try await container.publicCloudDatabase.records(matching: query, resultsLimit: limit)
        return matchResults.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Entry(
                id: record.recordID.recordName,
                displayName: record["displayName"] as? String ?? "Adventurer",
                level: record["level"] as? Int ?? 1,
                totalXP: record["totalXP"] as? Int ?? 0,
                streakDays: record["streakDays"] as? Int ?? 0,
                completedQuestCount: record["completedQuestCount"] as? Int ?? 0
            )
        }
    }

    /// 1-based rank of the given entry ID within an already-fetched,
    /// already-sorted list — pure and separately testable from the
    /// network call that produces the list.
    static func rank(of entryID: String, in entries: [Entry]) -> Int? {
        entries.firstIndex { $0.id == entryID }.map { $0 + 1 }
    }
}
