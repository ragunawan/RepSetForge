import Testing
@testable import RepSetForge

struct ExerciseDedupServiceTests {
    @Test func canonicalKeyStripsPunctuationAndCase() {
        #expect(Exercise.canonicalKey(for: "Bench Press!") == "bench press")
        #expect(Exercise.canonicalKey(for: "  Row  ") == "row")
    }

    @Test func levenshteinDistanceIsSymmetricAndCorrect() {
        let a = "bench press"
        let b = "bench pres"
        #expect(ExerciseDedupService.levenshteinDistance(a, b) == ExerciseDedupService.levenshteinDistance(b, a))
        #expect(ExerciseDedupService.levenshteinDistance(a, b) == 1)
        #expect(ExerciseDedupService.levenshteinDistance("row", "row") == 0)
    }

    @Test func tokenSubsetMatchesShorterNameWithinLonger() {
        #expect(ExerciseDedupService.isTokenSubset("row", "cable row seated"))
        #expect(!ExerciseDedupService.isTokenSubset("bench press", "leg press"))
    }

    @Test func similarExercisesFindsCloseAndSubsetMatchesButExcludesUnrelated() {
        let row = Exercise(name: "Cable Row (Seated)", equipment: .cable)
        let bench = Exercise(name: "Bench Press", equipment: .barbell)
        let candidates = [row, bench]

        let matches = ExerciseDedupService.similarExercises(to: "Row", in: candidates)
        #expect(matches.contains { $0.exercise === row })
        #expect(!matches.contains { $0.exercise === bench })
    }

    @Test func similarExercisesExcludesExactCanonicalMatch() {
        let bench = Exercise(name: "Bench Press", equipment: .barbell)
        let matches = ExerciseDedupService.similarExercises(to: "Bench Press", in: [bench])
        #expect(matches.isEmpty)
    }
}
