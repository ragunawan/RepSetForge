import Foundation

/// §6 Settings CSV import/export. Schema (spec-fixed):
/// `date,exercise,set_type,weight_kg,reps,rpe`
enum CSVCodec {
    static let header = "date,exercise,set_type,weight_kg,reps,rpe"

    struct Row: Equatable {
        var date: Date
        var exercise: String
        var setType: SetType
        var weightKg: Decimal?
        var reps: Int?
        var rpe: Double?
    }

    private static let dateFormat: Date.ISO8601FormatStyle = .iso8601

    static func export(rows: [Row]) -> String {
        var lines = [header]
        for r in rows {
            let fields = [
                r.date.formatted(dateFormat),
                escape(r.exercise),
                r.setType.rawValue,
                r.weightKg.map { "\($0)" } ?? "",
                r.reps.map(String.init) ?? "",
                r.rpe.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "",
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Tolerant import: skips a header line, blank lines, and malformed rows
    /// (returned in `skipped` for a summary toast). Never throws away good rows.
    static func importCSV(_ text: String) -> (rows: [Row], skipped: Int) {
        var rows: [Row] = []
        var skipped = 0
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: true).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if i == 0 && trimmed.lowercased().hasPrefix("date,") { continue }
            let fields = splitCSVLine(trimmed)
            guard fields.count >= 3,
                  let date = try? Date(fields[0], strategy: dateFormat),
                  let type = SetType(rawValue: fields[2]) else {
                skipped += 1
                continue
            }
            let name = fields[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { skipped += 1; continue }
            rows.append(Row(
                date: date,
                exercise: name,
                setType: type,
                weightKg: fields.count > 3 ? Decimal(string: fields[3]) : nil,
                reps: fields.count > 4 ? Int(fields[4]) : nil,
                rpe: fields.count > 5 ? Double(fields[5]) : nil))
        }
        return (rows, skipped)
    }

    // Minimal RFC-4180 quoting for exercise names containing , or ".
    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(current); current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        fields.append(current)
        return fields
    }
}
