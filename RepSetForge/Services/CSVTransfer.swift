import Foundation
import SwiftData

enum CSVTransfer {
  static let header = "date,exercise,set_type,weight_kg,reps,rpe"

  @MainActor
  static func exportString(from sessions: [WorkoutSession]) -> String {
    let rows = sessions
      .filter { $0.status == .completed }
      .sorted { $0.startedAt < $1.startedAt }
      .flatMap(exportRows)
    return ([header] + rows).joined(separator: "\n")
  }

  @MainActor
  static func importString(_ csv: String, in modelContext: ModelContext) throws -> Int {
    let rows = parseRows(csv)
    guard rows.first?.map({ $0.lowercased() }) == header.components(separatedBy: ",") else {
      throw CSVTransferError.invalidHeader
    }

    let existingExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
    var exercisesByKey = Dictionary(uniqueKeysWithValues: existingExercises.map { ($0.canonicalNameKey, $0) })
    let parsedRows = try rows.dropFirst().compactMap(CSVImportRow.init)
    let grouped = Dictionary(grouping: parsedRows) { Calendar.current.startOfDay(for: $0.date) }

    for (day, dayRows) in grouped {
      let session = WorkoutSession(
        name: "CSV Import",
        startedAt: day,
        endedAt: Calendar.current.date(byAdding: .minute, value: max(dayRows.count * 3, 1), to: day),
        status: .completed
      )
      modelContext.insert(session)

      let exerciseGroups = Dictionary(grouping: dayRows) { $0.exerciseName }
      let orderedNames = exerciseGroups.keys.sorted()
      var sessionExercises: [SessionExercise] = []

      for (order, exerciseName) in orderedNames.enumerated() {
        let key = ExerciseDeduplicator.canonicalNameKey(for: exerciseName)
        let exercise = exercisesByKey[key] ?? Exercise(name: exerciseName)
        if exercisesByKey[key] == nil {
          exercisesByKey[key] = exercise
          modelContext.insert(exercise)
        }

        let sessionExercise = SessionExercise(session: session, exercise: exercise, order: order)
        modelContext.insert(sessionExercise)
        let sets = (exerciseGroups[exerciseName] ?? []).enumerated().map { offset, row in
          SetEntry(
            sessionExercise: sessionExercise,
            index: offset + 1,
            type: row.type,
            weightKg: row.weightKg,
            reps: row.reps,
            rpe: row.rpe,
            completedAt: row.date
          )
        }
        sets.forEach(modelContext.insert)
        sessionExercise.sets = sets
        sessionExercises.append(sessionExercise)
      }

      session.exercises = sessionExercises
    }

    try modelContext.save()
    HistoricalSessionInvalidator.rebuildPRs(for: Set(exercisesByKey.values.map(\.persistentModelID)), in: modelContext)
    try modelContext.save()
    return parsedRows.count
  }

  private static func exportRows(session: WorkoutSession) -> [String] {
    (session.exercises ?? [])
      .sorted { $0.order < $1.order }
      .flatMap { sessionExercise in
        (sessionExercise.sets ?? [])
          .filter { $0.completedAt != nil }
          .sorted { $0.index < $1.index }
          .map { set in
            [
              csvDateString(set.completedAt ?? session.startedAt),
              escaped(sessionExercise.exercise?.name ?? "Exercise"),
              set.type.rawValue,
              set.weightKg.map(decimalString) ?? "",
              set.reps.map(String.init) ?? "",
              set.rpe.map(decimalString) ?? ""
            ].joined(separator: ",")
          }
      }
  }

  private static func parseRows(_ csv: String) -> [[String]] {
    csv
      .split(whereSeparator: \.isNewline)
      .map { parseLine(String($0)) }
      .filter { !$0.isEmpty }
  }

  private static func parseLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var isQuoted = false
    var index = line.startIndex

    while index < line.endIndex {
      let character = line[index]
      if character == "\"" {
        let next = line.index(after: index)
        if isQuoted, next < line.endIndex, line[next] == "\"" {
          current.append(character)
          index = next
        } else {
          isQuoted.toggle()
        }
      } else if character == ",", !isQuoted {
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        current = ""
      } else {
        current.append(character)
      }
      index = line.index(after: index)
    }

    fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
    return fields
  }

  private static func escaped(_ value: String) -> String {
    guard value.contains(",") || value.contains("\"") else { return value }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private static func csvDateString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

  private static func decimalString(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

enum CSVTransferError: Error {
  case invalidHeader
  case invalidRow
}

private struct CSVImportRow {
  let date: Date
  let exerciseName: String
  let type: SetEntryType
  let weightKg: Decimal?
  let reps: Int?
  let rpe: Decimal?

  init(_ fields: [String]) throws {
    guard fields.count == 6 else { throw CSVTransferError.invalidRow }
    guard let date = ISO8601DateFormatter().date(from: fields[0]) else { throw CSVTransferError.invalidRow }
    guard !fields[1].isEmpty else { throw CSVTransferError.invalidRow }

    self.date = date
    exerciseName = fields[1]
    type = SetEntryType(rawValue: fields[2]) ?? .working
    weightKg = fields[3].isEmpty ? nil : Decimal(string: fields[3])
    reps = fields[4].isEmpty ? nil : Int(fields[4])
    rpe = fields[5].isEmpty ? nil : Decimal(string: fields[5])
  }
}
