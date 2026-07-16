import SwiftUI
import SwiftData
import Charts

/// §5 Home, v1.7 four modules: resume banner, week-at-a-glance, recommended
/// next session, Body dual-axis chart. Placeholder/locked states on first run.
struct HomeView: View {
    var vm: WorkoutViewModel
    var onResume: () -> Void = {}
    var onStart: (Routine?) -> Void = { _ in }
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \BodyMetric.date) private var bodyMetrics: [BodyMetric]
    @Query private var sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(spacing: DT.Spacing.cardGap) {
                if vm.store.isActive { resumeBanner }
                weekStrip
                recommendedNext
                BodyModule(metrics: bodyMetrics)
            }
            .padding(.horizontal, DT.Spacing.s12 + 2)
            .padding(.vertical, DT.Spacing.s8)
        }
        .background(DT.Colors.surface)
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    // Module 1 — resume banner
    private var resumeBanner: some View {
        Button(action: onResume) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WORKOUT IN PROGRESS")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.signal)
                    Text(vm.session?.name ?? "")
                        .font(DT.Type.body.weight(.bold))
                    if let start = vm.session?.startedAt {
                        HStack(spacing: 4) {
                            Text(start, style: .timer).monospacedDigit()
                            Text("· \(vm.doneSets) sets done")
                        }
                        .font(DT.Type.secondary)
                        .foregroundStyle(DT.Colors.textSecondary)
                    }
                }
                Spacer()
                Text("Resume ›")
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(DT.Colors.signal)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(DT.Colors.signalDim)
                    .clipShape(Capsule())
            }
            .padding(DT.Spacing.cardPadding)
            .background(DT.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.signal))
        }
        .buttonStyle(.plain)
    }

    // Module 2 — week-at-a-glance
    private var weekStrip: some View {
        let completed = sessions.filter { $0.status == .completed }
        let cal = Calendar.current
        let weekSessions = completed.filter { cal.isDate($0.startedAt, equalTo: .now, toGranularity: .weekOfYear) }
        let weekSets = weekSessions.reduce(0) { $0 + ($1.exercises ?? []).reduce(0) { $0 + ($1.sets?.count ?? 0) } }
        let weekPRs = weekSessions.reduce(0) { $0 + ($1.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isPR).count }

        return card {
            HStack {
                Text("THIS WEEK").font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
                Spacer()
            }
            HStack {
                stat("\(weekSessions.count)", "SESSIONS")
                Spacer()
                stat("\(weekSets)", "SETS")
                Spacer()
                stat("\(weekPRs)", "PRS", color: DT.Colors.pr)
            }
            .padding(.top, DT.Spacing.s8)
            if weekSessions.isEmpty {
                Text("No sessions yet this week — start one from a routine below.")
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textTertiary)
                    .padding(.top, DT.Spacing.s4)
            }
        }
    }

    // Module 3 — recommended next: least-recently-performed routine
    private var recommendedNext: some View {
        let next = routines
            .filter { $0.archivedAt == nil }
            .min { ($0.lastPerformedAt ?? .distantPast) < ($1.lastPerformedAt ?? .distantPast) }
        return card {
            Text("RECOMMENDED NEXT").font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(next?.name ?? "Create a routine")
                        .font(DT.Type.body.weight(.bold))
                    Text(next?.lastPerformedAt.map { "Last done \($0.formatted(.relative(presentation: .named)))" }
                         ?? "Build one in Library to get recommendations")
                        .font(DT.Type.secondary)
                        .foregroundStyle(DT.Colors.textSecondary)
                }
                Spacer()
                Button {
                    onStart(next)
                } label: {
                    Text("Start")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.signal)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(DT.Colors.signalDim)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(DT.Colors.signal))
                }
            }
            .padding(.top, DT.Spacing.s4)
        }
    }

    private func stat(_ value: String, _ label: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DT.Type.numericLarge)
                .foregroundStyle(color ?? DT.Colors.textPrimary)
            Text(label).font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
        }
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DT.Spacing.cardPadding)
            .background(DT.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.hairline))
    }
}

/// Module 4 — §5 Body: dual-axis weight (solid, signal, left) + BF% (dashed,
/// grey, right) with W/M/Y control and period paging. Sparse BF% handling
/// per spec: interpolate ≤14d, render nothing beyond; no-BF% period shows
/// the weight line alone with a dimmed right-axis label.
struct BodyModule: View {
    let metrics: [BodyMetric]
    @State private var range: BodyChartMath.Range = .week
    @State private var offset = 0

    private var weightSeries: BodyChartMath.Series {
        let samples = metrics.compactMap { m -> BodyChartMath.Sample? in
            guard let w = m.bodyweightKg else { return nil }
            return .init(date: m.date, value: NSDecimalNumber(decimal: w).doubleValue)
        }
        return BodyChartMath.aggregate(samples: samples, range: range, offset: offset, now: .now)
    }

    private var bfSeries: BodyChartMath.Series {
        let samples = metrics.compactMap { m -> BodyChartMath.Sample? in
            guard let bf = m.bodyFatPct else { return nil }
            return .init(date: m.date, value: bf)
        }
        let slotDays = Double(range.days) / Double(range.points)
        return BodyChartMath.interpolateGaps(
            BodyChartMath.aggregate(samples: samples, range: range, offset: offset, now: .now),
            slotDays: slotDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s8) {
            HStack {
                Text("BODY").font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
                Spacer()
                ForEach(BodyChartMath.Range.allCases, id: \.self) { r in
                    Button(r.rawValue) { range = r; offset = 0 }
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(range == r ? DT.Colors.signal : DT.Colors.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(range == r ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(range == r ? DT.Colors.signal : DT.Colors.hairline))
                }
            }
            HStack {
                Button("‹ \(BodyChartMath.periodLabel(range: range, offset: offset + 1, now: .now))") {
                    offset += 1
                }
                .foregroundStyle(DT.Colors.textSecondary)
                Spacer()
                Text(BodyChartMath.periodLabel(range: range, offset: offset, now: .now))
                    .foregroundStyle(DT.Colors.textPrimary)
                Spacer()
                Button(offset == 0 ? "NOW" : "\(BodyChartMath.periodLabel(range: range, offset: offset - 1, now: .now)) ›") {
                    if offset > 0 { offset -= 1 }
                }
                .foregroundStyle(DT.Colors.textSecondary)
                .opacity(offset == 0 ? 0.3 : 1)
            }
            .font(DT.Type.eyebrow)
            .monospacedDigit()

            if weightSeries.points.compactMap({ $0 }).isEmpty {
                lockedState
            } else {
                chartContent
            }
        }
        .padding(DT.Spacing.cardPadding)
        .background(DT.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.hairline))
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            if g.translation.width > 40 { offset += 1 }
            if g.translation.width < -40, offset > 0 { offset -= 1 }
        })
    }

    private var lockedState: some View {
        VStack(spacing: DT.Spacing.s8) {
            Text("Not enough data this period")
                .font(DT.Type.secondary)
                .foregroundStyle(DT.Colors.textSecondary)
            Text("Log today's weight")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.signal)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    @ViewBuilder
    private var chartContent: some View {
        let w = weightSeries
        let bf = bfSeries
        let hasBF = !bf.points.compactMap({ $0 }).isEmpty

        // Header row: current values + period deltas.
        HStack {
            if let latest = w.latest {
                Text("WEIGHT \(latest, specifier: "%.1f") kg")
                    .foregroundStyle(DT.Colors.signal)
                + Text(w.delta.map { " (\($0 > 0 ? "+" : "")\($0.formatted(.number.precision(.fractionLength(1)))))" } ?? "")
                    .foregroundStyle(DT.Colors.textTertiary)
            }
            Spacer()
            if hasBF, let latest = bf.latest {
                Text("BODY FAT \(latest, specifier: "%.1f")%")
                    .foregroundStyle(DT.Colors.textSecondary)
                + Text(bf.delta.map { " (\($0 > 0 ? "+" : "")\($0.formatted(.number.precision(.fractionLength(1)))))" } ?? "")
                    .foregroundStyle(DT.Colors.textTertiary)
            } else {
                Text("No body-fat data")
                    .foregroundStyle(DT.Colors.textTertiary)
            }
        }
        .font(DT.Type.secondary)
        .monospacedDigit()

        Chart {
            ForEach(Array(w.points.enumerated()), id: \.offset) { i, v in
                if let v {
                    LineMark(x: .value("t", i), y: .value("kg", v), series: .value("s", "weight"))
                        .foregroundStyle(DT.Colors.signal)
                        .lineStyle(StrokeStyle(lineWidth: 1.8))
                }
            }
            if hasBF {
                ForEach(Array(bf.points.enumerated()), id: \.offset) { i, v in
                    if let v {
                        LineMark(x: .value("t", i), y: .value("bf", v), series: .value("s", "bf"))
                            .foregroundStyle(DT.Colors.textSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [3, 2]))
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .frame(height: 72)

        // Legend: line style ↔ axis mapping.
        HStack(spacing: DT.Spacing.s12) {
            Text("— WEIGHT (LEFT)").foregroundStyle(DT.Colors.signal)
            Text("- - BODY FAT % (RIGHT)").foregroundStyle(hasBF ? DT.Colors.textSecondary : DT.Colors.textTertiary)
        }
        .font(DT.Type.eyebrow)
    }
}
