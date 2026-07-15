#!/usr/bin/env python3
"""Generates RepSetForge.xcodeproj/project.pbxproj

Three targets: RepSetForge (app), RepSetForgeTests, RepSetForgeUITests.
Watch and Widget extension targets return once TODO.md's v1.0 build-order
steps that need them (Live Activity, then the v1.1 Watch companion) land —
see TODO.md for the plan; don't add target scaffolding ahead of real source
files that need it.
"""

import os

# ── UUID scheme: AA + type_hex + 18 zeros + 2-digit sequence ──────────────
# type 0=project, 1=file refs, 2=build files, 3=groups
# type 4=targets, 5=config lists, 6=build configs, 7=build phases, 9=deps

def u(type_hex, seq):
    return f"AA0{type_hex}000000000000000000{seq:02X}"

# ── UUIDs ──────────────────────────────────────────────────────────────────
PROJECT = u(0, 0x01)

# File references
FR = {
    "RepSetForgeApp":        u(1, 0x01),
    "ContentView":           u(1, 0x02),
    "RepSetForgeTheme":      u(1, 0x03),
    "MuscleGroup":           u(1, 0x04),
    "Equipment":             u(1, 0x05),
    "SetType":               u(1, 0x06),
    "ProgressionRuleType":   u(1, 0x07),
    "WorkoutSessionStatus":  u(1, 0x08),
    "PRKind":                u(1, 0x09),
    "Exercise":              u(1, 0x0A),
    "Routine":               u(1, 0x0B),
    "RoutineItem":           u(1, 0x0C),
    "ProgressionRule":       u(1, 0x0D),
    "WorkoutSession":        u(1, 0x0E),
    "SessionExercise":       u(1, 0x0F),
    "SetEntry":              u(1, 0x10),
    "PRRecord":              u(1, 0x11),
    "BodyMetric":            u(1, 0x12),
    "RepSetForgeSchema":     u(1, 0x13),
    "PersistenceController": u(1, 0x14),
    "ExerciseDedupService":  u(1, 0x15),
    "Assets":                u(1, 0x16),
    "Entitlements":          u(1, 0x17),
    "PROD_APP":              u(1, 0x18),  # RepSetForge.app
    "PROD_TEST":             u(1, 0x19),  # RepSetForgeTests.xctest
    "PROD_UITEST":           u(1, 0x1A),  # RepSetForgeUITests.xctest
    "TEST_ExerciseDedup":    u(1, 0x1B),
    "TEST_SetEntryE1RM":     u(1, 0x1C),
    "UITEST_App":            u(1, 0x1D),
    "RestTimerManager":      u(1, 0x1E),
    "PersonalRecordService": u(1, 0x1F),
    "ExerciseFocusView":     u(1, 0x20),
    "ExerciseIndexSheet":    u(1, 0x21),
    "ActiveWorkoutView":     u(1, 0x22),
    "StartWorkoutSheet":     u(1, 0x23),
    "AddExerciseSheet":      u(1, 0x24),
    "SetRowView":            u(1, 0x25),
    "RPEChipRow":            u(1, 0x26),
    "ExerciseTrendChart":    u(1, 0x27),
    "RestTimerPill":         u(1, 0x28),
    "TEST_PersonalRecord":   u(1, 0x29),
    "TEST_RestTimer":        u(1, 0x2A),
    "FinishWorkoutConfirmationSheet": u(1, 0x2B),
    "WorkoutSummaryView":    u(1, 0x2C),
    "HomeStatsService":      u(1, 0x2D),
    "LogBodyMetricSheet":    u(1, 0x2E),
    "HomeView":              u(1, 0x2F),
    "TEST_HomeStats":        u(1, 0x30),
    "RoutineLibraryView":    u(1, 0x31),
    "RoutineBuilderView":    u(1, 0x32),
    "ProgressionLadderService": u(1, 0x33),
    "ProgressionPanelView":  u(1, 0x34),
    "TEST_ProgressionLadder": u(1, 0x35),
    "ExerciseHistoryService": u(1, 0x36),
    "ExerciseDetailView":    u(1, 0x37),
    "HistoryView":           u(1, 0x38),
    "TEST_ExerciseHistory":  u(1, 0x39),
}

# Build files (one per compiled/copied file reference, excluding products)
BF = {k: u(2, i + 1) for i, k in enumerate(FR.keys()) if not k.startswith("PROD_")}

# Groups
GR = {
    "Root":        u(3, 0x01),
    "Products":    u(3, 0x02),
    "RepSetForge": u(3, 0x03),
    "Models":      u(3, 0x04),
    "Services":    u(3, 0x05),
    "Persistence": u(3, 0x06),
    "Tests":       u(3, 0x07),
    "UITests":     u(3, 0x08),
    "Views":       u(3, 0x09),
    "Components":  u(3, 0x0A),
}

# Targets
TG_APP    = u(4, 0x01)
TG_TEST   = u(4, 0x02)
TG_UITEST = u(4, 0x03)

# Config lists
CL_PROJECT = u(5, 0x01)
CL_APP     = u(5, 0x02)
CL_TEST    = u(5, 0x03)
CL_UITEST  = u(5, 0x04)

# Build configurations
BC_PROJ_DBG   = u(6, 0x01)
BC_PROJ_REL   = u(6, 0x02)
BC_APP_DBG    = u(6, 0x03)
BC_APP_REL    = u(6, 0x04)
BC_TEST_DBG   = u(6, 0x05)
BC_TEST_REL   = u(6, 0x06)
BC_UITEST_DBG = u(6, 0x07)
BC_UITEST_REL = u(6, 0x08)

# Build phases
BP_APP_SRC    = u(7, 0x01)
BP_APP_RES    = u(7, 0x02)
BP_APP_FRM    = u(7, 0x03)
BP_TEST_SRC   = u(7, 0x04)
BP_TEST_FRM   = u(7, 0x05)
BP_UITEST_SRC = u(7, 0x06)
BP_UITEST_FRM = u(7, 0x07)

# Dependencies / proxy
TD_TEST   = u(9, 0x01)
CI_TEST   = u(9, 0x02)
TD_UITEST = u(9, 0x03)
CI_UITEST = u(9, 0x04)

# ── App source files (path relative to RepSetForge/ folder) ──────────────
APP_SOURCES = [
    ("RepSetForgeApp",        "RepSetForgeApp.swift"),
    ("ContentView",           "ContentView.swift"),
    ("RepSetForgeTheme",      "RepSetForgeTheme.swift"),
    ("MuscleGroup",           "Models/MuscleGroup.swift"),
    ("Equipment",             "Models/Equipment.swift"),
    ("SetType",               "Models/SetType.swift"),
    ("ProgressionRuleType",   "Models/ProgressionRuleType.swift"),
    ("WorkoutSessionStatus",  "Models/WorkoutSessionStatus.swift"),
    ("PRKind",                "Models/PRKind.swift"),
    ("Exercise",              "Models/Exercise.swift"),
    ("Routine",               "Models/Routine.swift"),
    ("RoutineItem",           "Models/RoutineItem.swift"),
    ("ProgressionRule",       "Models/ProgressionRule.swift"),
    ("WorkoutSession",        "Models/WorkoutSession.swift"),
    ("SessionExercise",       "Models/SessionExercise.swift"),
    ("SetEntry",              "Models/SetEntry.swift"),
    ("PRRecord",              "Models/PRRecord.swift"),
    ("BodyMetric",            "Models/BodyMetric.swift"),
    ("RepSetForgeSchema",     "Persistence/RepSetForgeSchema.swift"),
    ("PersistenceController", "Persistence/PersistenceController.swift"),
    ("ExerciseDedupService",  "Services/ExerciseDedupService.swift"),
    ("RestTimerManager",      "Services/RestTimerManager.swift"),
    ("PersonalRecordService", "Services/PersonalRecordService.swift"),
    ("HomeStatsService",      "Services/HomeStatsService.swift"),
    ("ProgressionLadderService", "Services/ProgressionLadderService.swift"),
    ("ExerciseHistoryService", "Services/ExerciseHistoryService.swift"),
    ("ExerciseFocusView",     "Views/ExerciseFocusView.swift"),
    ("ExerciseIndexSheet",    "Views/ExerciseIndexSheet.swift"),
    ("ActiveWorkoutView",     "Views/ActiveWorkoutView.swift"),
    ("StartWorkoutSheet",     "Views/StartWorkoutSheet.swift"),
    ("AddExerciseSheet",      "Views/AddExerciseSheet.swift"),
    ("FinishWorkoutConfirmationSheet", "Views/FinishWorkoutConfirmationSheet.swift"),
    ("WorkoutSummaryView",    "Views/WorkoutSummaryView.swift"),
    ("HomeView",              "Views/HomeView.swift"),
    ("LogBodyMetricSheet",    "Views/LogBodyMetricSheet.swift"),
    ("RoutineLibraryView",    "Views/RoutineLibraryView.swift"),
    ("RoutineBuilderView",    "Views/RoutineBuilderView.swift"),
    ("ProgressionPanelView",  "Views/ProgressionPanelView.swift"),
    ("ExerciseDetailView",    "Views/ExerciseDetailView.swift"),
    ("HistoryView",           "Views/HistoryView.swift"),
    ("SetRowView",            "Views/Components/SetRowView.swift"),
    ("RPEChipRow",            "Views/Components/RPEChipRow.swift"),
    ("ExerciseTrendChart",    "Views/Components/ExerciseTrendChart.swift"),
    ("RestTimerPill",         "Views/Components/RestTimerPill.swift"),
]

MODEL_KEYS = [
    "MuscleGroup", "Equipment", "SetType", "ProgressionRuleType", "WorkoutSessionStatus", "PRKind",
    "Exercise", "Routine", "RoutineItem", "ProgressionRule", "WorkoutSession",
    "SessionExercise", "SetEntry", "PRRecord", "BodyMetric",
]
SERVICE_KEYS = [
    "ExerciseDedupService", "RestTimerManager", "PersonalRecordService", "HomeStatsService",
    "ProgressionLadderService", "ExerciseHistoryService",
]
PERSISTENCE_KEYS = ["RepSetForgeSchema", "PersistenceController"]
VIEW_KEYS = [
    "ExerciseFocusView", "ExerciseIndexSheet", "ActiveWorkoutView", "StartWorkoutSheet", "AddExerciseSheet",
    "FinishWorkoutConfirmationSheet", "WorkoutSummaryView", "HomeView", "LogBodyMetricSheet",
    "RoutineLibraryView", "RoutineBuilderView", "ProgressionPanelView", "ExerciseDetailView", "HistoryView",
]
COMPONENT_KEYS = ["SetRowView", "RPEChipRow", "ExerciseTrendChart", "RestTimerPill"]

TEST_SOURCES = [
    ("TEST_ExerciseDedup", "RepSetForgeTests/ExerciseDedupServiceTests.swift"),
    ("TEST_SetEntryE1RM",  "RepSetForgeTests/SetEntryE1RMTests.swift"),
    ("TEST_PersonalRecord", "RepSetForgeTests/PersonalRecordServiceTests.swift"),
    ("TEST_RestTimer",     "RepSetForgeTests/RestTimerManagerTests.swift"),
    ("TEST_HomeStats",     "RepSetForgeTests/HomeStatsServiceTests.swift"),
    ("TEST_ProgressionLadder", "RepSetForgeTests/ProgressionLadderServiceTests.swift"),
    ("TEST_ExerciseHistory", "RepSetForgeTests/ExerciseHistoryServiceTests.swift"),
]

UI_TEST_SOURCES = [
    ("UITEST_App", "RepSetForgeUITests/RepSetForgeUITests.swift"),
]


def pbxproj():
    lines = []
    a = lines.append

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 77;")
    a("\tobjects = {")
    a("")

    # ── PBXBuildFile ────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXBuildFile section */")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    a(f"\t\t{BF['Assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FR['Assets']} /* Assets.xcassets */; }};")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{BF[key]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {FR[key]} /* {filename} */; }};")
    a("\t\t/* End PBXBuildFile section */")
    a("")

    # ── PBXContainerItemProxy ───────────────────────────────────────────────
    a("\t\t/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{CI_TEST} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_APP};")
    a(f"\t\t\tremoteInfo = RepSetForge;")
    a(f"\t\t}};")
    a(f"\t\t{CI_UITEST} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_APP};")
    a(f"\t\t\tremoteInfo = RepSetForge;")
    a(f"\t\t}};")
    a("\t\t/* End PBXContainerItemProxy section */")
    a("")

    # ── PBXFileReference ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXFileReference section */")
    a(f"\t\t{FR['PROD_APP']} /* RepSetForge.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RepSetForge.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_TEST']} /* RepSetForgeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RepSetForgeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RepSetForgeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['Assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['Entitlements']} /* RepSetForge.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = RepSetForge.entitlements; sourceTree = \"<group>\"; }};")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a("\t\t/* End PBXFileReference section */")
    a("")

    # ── PBXFrameworksBuildPhase ─────────────────────────────────────────────
    a("\t\t/* Begin PBXFrameworksBuildPhase section */")
    for phase in (BP_APP_FRM, BP_TEST_FRM, BP_UITEST_FRM):
        a(f"\t\t{phase} /* Frameworks */ = {{")
        a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
        a(f"\t\t\tbuildActionMask = 2147483647;")
        a(f"\t\t\tfiles = (")
        a(f"\t\t\t);")
        a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        a(f"\t\t}};")
    a("\t\t/* End PBXFrameworksBuildPhase section */")
    a("")

    # ── PBXGroup ─────────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXGroup section */")

    a(f"\t\t{GR['Root']} = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{GR['RepSetForge']} /* RepSetForge */,")
    a(f"\t\t\t\t{GR['Tests']} /* RepSetForgeTests */,")
    a(f"\t\t\t\t{GR['UITests']} /* RepSetForgeUITests */,")
    a(f"\t\t\t\t{GR['Products']} /* Products */,")
    a(f"\t\t\t);")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a(f"\t\t{GR['Products']} /* Products */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['PROD_APP']} /* RepSetForge.app */,")
    a(f"\t\t\t\t{FR['PROD_TEST']} /* RepSetForgeTests.xctest */,")
    a(f"\t\t\t\t{FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = Products;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a(f"\t\t{GR['RepSetForge']} /* RepSetForge */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['RepSetForgeApp']} /* RepSetForgeApp.swift */,")
    a(f"\t\t\t\t{FR['ContentView']} /* ContentView.swift */,")
    a(f"\t\t\t\t{FR['RepSetForgeTheme']} /* RepSetForgeTheme.swift */,")
    a(f"\t\t\t\t{GR['Models']} /* Models */,")
    a(f"\t\t\t\t{GR['Services']} /* Services */,")
    a(f"\t\t\t\t{GR['Persistence']} /* Persistence */,")
    a(f"\t\t\t\t{GR['Views']} /* Views */,")
    a(f"\t\t\t\t{FR['Assets']} /* Assets.xcassets */,")
    a(f"\t\t\t\t{FR['Entitlements']} /* RepSetForge.entitlements */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForge;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    app_sources_by_key = dict(APP_SOURCES)

    def simple_group(grp_key, grp_path, file_keys):
        a(f"\t\t{GR[grp_key]} /* {grp_key} */ = {{")
        a(f"\t\t\tisa = PBXGroup;")
        a(f"\t\t\tchildren = (")
        for fk in file_keys:
            filename = app_sources_by_key[fk].split("/")[-1]
            a(f"\t\t\t\t{FR[fk]} /* {filename} */,")
        a(f"\t\t\t);")
        a(f"\t\t\tpath = {grp_path};")
        a(f"\t\t\tsourceTree = \"<group>\";")
        a(f"\t\t}};")

    simple_group("Models", "Models", MODEL_KEYS)
    simple_group("Services", "Services", SERVICE_KEYS)
    simple_group("Persistence", "Persistence", PERSISTENCE_KEYS)

    a(f"\t\t{GR['Views']} /* Views */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for fk in VIEW_KEYS:
        filename = app_sources_by_key[fk].split("/")[-1]
        a(f"\t\t\t\t{FR[fk]} /* {filename} */,")
    a(f"\t\t\t\t{GR['Components']} /* Components */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = Views;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    simple_group("Components", "Components", COMPONENT_KEYS)

    a(f"\t\t{GR['Tests']} /* RepSetForgeTests */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForgeTests;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a(f"\t\t{GR['UITests']} /* RepSetForgeUITests */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = RepSetForgeUITests;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a("\t\t/* End PBXGroup section */")
    a("")

    # ── PBXNativeTarget ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXNativeTarget section */")
    a(f"\t\t{TG_APP} /* RepSetForge */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_APP} /* Build configuration list for PBXNativeTarget \"RepSetForge\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_APP_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_APP_FRM} /* Frameworks */,")
    a(f"\t\t\t\t{BP_APP_RES} /* Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForge;")
    a(f"\t\t\tproductName = RepSetForge;")
    a(f"\t\t\tproductReference = {FR['PROD_APP']} /* RepSetForge.app */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_TEST} /* RepSetForgeTests */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_TEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeTests\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_TEST_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_TEST_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_TEST} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForgeTests;")
    a(f"\t\t\tproductName = RepSetForgeTests;")
    a(f"\t\t\tproductReference = {FR['PROD_TEST']} /* RepSetForgeTests.xctest */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_UITEST} /* RepSetForgeUITests */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_UITEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeUITests\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_UITEST_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_UITEST_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_UITEST} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = RepSetForgeUITests;")
    a(f"\t\t\tproductName = RepSetForgeUITests;")
    a(f"\t\t\tproductReference = {FR['PROD_UITEST']} /* RepSetForgeUITests.xctest */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";")
    a(f"\t\t}};")
    a("\t\t/* End PBXNativeTarget section */")
    a("")

    # ── PBXProject ─────────────────────────────────────────────────────────
    a("\t\t/* Begin PBXProject section */")
    a(f"\t\t{PROJECT} /* Project object */ = {{")
    a(f"\t\t\tisa = PBXProject;")
    a(f"\t\t\tattributes = {{")
    a(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a(f"\t\t\t\tLastSwiftUpdateCheck = 1600;")
    a(f"\t\t\t\tLastUpgradeCheck = 1600;")
    a(f"\t\t\t\tTargetAttributes = {{")
    a(f"\t\t\t\t\t{TG_APP} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_TEST} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t\tTestTargetID = {TG_APP};")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t\t{TG_UITEST} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a(f"\t\t\t\t\t\tDevelopmentTeam = 5T5444U7W2;")
    a(f"\t\t\t\t\t\tProvisioningStyle = Automatic;")
    a(f"\t\t\t\t\t\tTestTargetID = {TG_APP};")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t}};")
    a(f"\t\t\t}};")
    a(f"\t\t\tbuildConfigurationList = {CL_PROJECT} /* Build configuration list for PBXProject \"RepSetForge\" */;")
    a(f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a(f"\t\t\tdevelopmentRegion = en;")
    a(f"\t\t\thasScannedForEncodings = 0;")
    a(f"\t\t\tknownRegions = (")
    a(f"\t\t\t\ten,")
    a(f"\t\t\t\tBase,")
    a(f"\t\t\t);")
    a(f"\t\t\tmainGroup = {GR['Root']};")
    a(f"\t\t\tproductRefGroup = {GR['Products']} /* Products */;")
    a(f"\t\t\tprojectDirPath = \"\";")
    a(f"\t\t\tprojectRoot = \"\";")
    a(f"\t\t\ttargets = (")
    a(f"\t\t\t\t{TG_APP} /* RepSetForge */,")
    a(f"\t\t\t\t{TG_TEST} /* RepSetForgeTests */,")
    a(f"\t\t\t\t{TG_UITEST} /* RepSetForgeUITests */,")
    a(f"\t\t\t);")
    a(f"\t\t}};")
    a("\t\t/* End PBXProject section */")
    a("")

    # ── PBXResourcesBuildPhase ──────────────────────────────────────────────
    a("\t\t/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{BP_APP_RES} /* Resources */ = {{")
    a(f"\t\t\tisa = PBXResourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t\t{BF['Assets']} /* Assets.xcassets in Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXResourcesBuildPhase section */")
    a("")

    # ── PBXSourcesBuildPhase ────────────────────────────────────────────────
    a("\t\t/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{BP_APP_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_TEST_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_UITEST_SRC} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for key, path in UI_TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{BF[key]} /* {filename} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("\t\t/* End PBXSourcesBuildPhase section */")
    a("")

    # ── PBXTargetDependency ─────────────────────────────────────────────────
    a("\t\t/* Begin PBXTargetDependency section */")
    a(f"\t\t{TD_TEST} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_APP} /* RepSetForge */;")
    a(f"\t\t\ttargetProxy = {CI_TEST} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a(f"\t\t{TD_UITEST} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_APP} /* RepSetForge */;")
    a(f"\t\t\ttargetProxy = {CI_UITEST} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a("\t\t/* End PBXTargetDependency section */")
    a("")

    # ── XCBuildConfiguration ────────────────────────────────────────────────
    a("\t\t/* Begin XCBuildConfiguration section */")

    def project_config(uuid, name):
        debug_only = name == "Debug"
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        a(f"\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        a(f"\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
        a(f"\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
        a(f"\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        a(f"\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        a(f"\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
        a(f"\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
        a(f"\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_COMMA = YES;")
        a(f"\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
        a(f"\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
        a(f"\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
        a(f"\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
        a(f"\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
        a(f"\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;")
        a(f"\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
        a(f"\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
        a(f"\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
        a(f"\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
        a(f"\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
        a(f"\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
        a(f"\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
        a(f"\t\t\t\tCOPY_PHASE_STRIP = NO;")
        a(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = {'dwarf' if debug_only else 'dwarf-with-dsym'};")
        a(f"\t\t\t\tENABLE_NS_ASSERTIONS = {'YES' if debug_only else 'NO'};")
        a(f"\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        a(f"\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
        a(f"\t\t\t\tGCC_DYNAMIC_NO_PIC = {'NO' if debug_only else 'YES'};")
        a(f"\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
        a(f"\t\t\t\tGCC_OPTIMIZATION_LEVEL = {'0' if debug_only else 's'};")
        a(f"\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
        if debug_only:
            a(f"\t\t\t\t\t\"DEBUG=1\",")
        a(f"\t\t\t\t\t\"$(inherited)\",")
        a(f"\t\t\t\t);")
        a(f"\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
        a(f"\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
        a(f"\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
        a(f"\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
        a(f"\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
        a(f"\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = {'INCLUDE_SOURCE' if debug_only else 'NO'};")
        a(f"\t\t\t\tMTL_FAST_MATH = YES;")
        a(f"\t\t\t\tONLY_ACTIVE_ARCH = {'YES' if debug_only else 'NO'};")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        if debug_only:
            a(f"\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
            a(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            a(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    project_config(BC_PROJ_DBG, "Debug")
    project_config(BC_PROJ_REL, "Release")

    def app_config(uuid, name):
        debug = name == "Debug"
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        a(f"\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
        a(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = RepSetForge/RepSetForge.entitlements;")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        if debug:
            a(f"\t\t\t\tENABLE_TESTABILITY = YES;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = RepSetForge;")
        a(f"\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown\";")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait\";")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    app_config(BC_APP_DBG, "Debug")
    app_config(BC_APP_REL, "Release")

    def test_config(uuid, name):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForgeTests;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/RepSetForge.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RepSetForge\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    test_config(BC_TEST_DBG, "Debug")
    test_config(BC_TEST_REL, "Release")

    def uitest_config(uuid, name):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForgeUITests;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t\tTEST_TARGET_NAME = RepSetForge;")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    uitest_config(BC_UITEST_DBG, "Debug")
    uitest_config(BC_UITEST_REL, "Release")

    a("\t\t/* End XCBuildConfiguration section */")
    a("")

    # ── XCConfigurationList ─────────────────────────────────────────────────
    a("\t\t/* Begin XCConfigurationList section */")
    a(f"\t\t{CL_PROJECT} /* Build configuration list for PBXProject \"RepSetForge\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_PROJ_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_PROJ_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_APP} /* Build configuration list for PBXNativeTarget \"RepSetForge\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_APP_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_APP_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_TEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeTests\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_TEST_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_TEST_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_UITEST} /* Build configuration list for PBXNativeTarget \"RepSetForgeUITests\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_UITEST_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_UITEST_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a("\t\t/* End XCConfigurationList section */")
    a("")

    a("\t};")
    a(f"\trootObject = {PROJECT} /* Project object */;")
    a("}")

    return "\n".join(lines)


if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    proj_dir = os.path.join(base, "RepSetForge.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
    content = pbxproj()
    with open(pbxproj_path, "w") as f:
        f.write(content)
    print(f"Generated: {pbxproj_path}")
    print(f"Lines: {len(content.splitlines())}")
