#!/usr/bin/env python3
"""Generates Setbound.xcodeproj/project.pbxproj"""

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
    "SetboundApp":            u(1, 0x01),
    "ContentView":             u(1, 0x02),
    "SetboundTheme":          u(1, 0x03),
    "MuscleGroup":             u(1, 0x04),
    "QuestStatus":             u(1, 0x05),
    "ExerciseSet":             u(1, 0x06),
    "Exercise":                u(1, 0x07),
    "Quest":                   u(1, 0x08),
    "PlayerCharacter":         u(1, 0x09),
    "MuscleProgress":          u(1, 0x0A),
    "Achievement":             u(1, 0x0B),
    "ProgressionService":      u(1, 0x0C),
    "AchievementService":      u(1, 0x0D),
    "PersistenceController":   u(1, 0x0E),
    "QuestDashboardView":      u(1, 0x0F),
    "QuestListView":           u(1, 0x10),
    "QuestDetailView":         u(1, 0x11),
    "ExerciseLoggingView":     u(1, 0x12),
    "CharacterProgressView":   u(1, 0x13),
    "QuestHistoryView":        u(1, 0x14),
    "AchievementsView":        u(1, 0x15),
    "QuestCompletionView":     u(1, 0x16),
    "PixelQuestCard":          u(1, 0x17),
    "PixelXPBar":              u(1, 0x18),
    "PixelBadge":              u(1, 0x19),
    "PixelStatPanel":          u(1, 0x1A),
    "PixelButton":             u(1, 0x1B),
    "PixelAchievementCard":    u(1, 0x1C),
    "PixelDivider":            u(1, 0x1D),
    "QuestCompletionRewardRow": u(1, 0x1E),
    "Assets":                  u(1, 0x1F),
    "PROD_APP":                u(1, 0x20),  # Setbound.app
    "PROD_TEST":               u(1, 0x21),  # SetboundTests.xctest
    "TEST_Progression":        u(1, 0x22),
    "TEST_Achievement":        u(1, 0x23),
    "TEST_Integration":        u(1, 0x24),
}

# Build files
BF = {k: u(2, i + 1) for i, k in enumerate(FR.keys()) if not k.startswith("PROD_")}

# Groups
GR = {
    "Root":       u(3, 0x01),
    "Products":   u(3, 0x02),
    "Setbound":   u(3, 0x03),
    "Models":     u(3, 0x04),
    "Views":      u(3, 0x05),
    "Components": u(3, 0x06),
    "Services":   u(3, 0x07),
    "Persistence": u(3, 0x08),
    "Tests":      u(3, 0x09),
}

# Targets
TG_APP  = u(4, 0x01)
TG_TEST = u(4, 0x02)

# Config lists
CL_PROJECT = u(5, 0x01)
CL_APP     = u(5, 0x02)
CL_TEST    = u(5, 0x03)

# Build configurations
BC_PROJ_DBG = u(6, 0x01)
BC_PROJ_REL = u(6, 0x02)
BC_APP_DBG  = u(6, 0x03)
BC_APP_REL  = u(6, 0x04)
BC_TEST_DBG = u(6, 0x05)
BC_TEST_REL = u(6, 0x06)

# Build phases
BP_APP_SRC  = u(7, 0x01)
BP_APP_RES  = u(7, 0x02)
BP_APP_FRM  = u(7, 0x03)
BP_TEST_SRC = u(7, 0x04)
BP_TEST_FRM = u(7, 0x05)

# Dependencies / proxy
TD_TEST = u(9, 0x01)
CI_TEST = u(9, 0x02)

# ── App source files (path relative to Setbound/ folder) ──────────────────
APP_SOURCES = [
    ("SetboundApp",          "SetboundApp.swift"),
    ("ContentView",           "ContentView.swift"),
    ("SetboundTheme",        "SetboundTheme.swift"),
    ("MuscleGroup",           "Models/MuscleGroup.swift"),
    ("QuestStatus",           "Models/QuestStatus.swift"),
    ("ExerciseSet",           "Models/ExerciseSet.swift"),
    ("Exercise",              "Models/Exercise.swift"),
    ("Quest",                 "Models/Quest.swift"),
    ("PlayerCharacter",       "Models/PlayerCharacter.swift"),
    ("MuscleProgress",        "Models/MuscleProgress.swift"),
    ("Achievement",           "Models/Achievement.swift"),
    ("ProgressionService",    "Services/ProgressionService.swift"),
    ("AchievementService",    "Services/AchievementService.swift"),
    ("PersistenceController", "Persistence/PersistenceController.swift"),
    ("QuestDashboardView",    "Views/QuestDashboardView.swift"),
    ("QuestListView",         "Views/QuestListView.swift"),
    ("QuestDetailView",       "Views/QuestDetailView.swift"),
    ("ExerciseLoggingView",   "Views/ExerciseLoggingView.swift"),
    ("CharacterProgressView", "Views/CharacterProgressView.swift"),
    ("QuestHistoryView",      "Views/QuestHistoryView.swift"),
    ("AchievementsView",      "Views/AchievementsView.swift"),
    ("QuestCompletionView",   "Views/QuestCompletionView.swift"),
    ("PixelQuestCard",        "Views/Components/PixelQuestCard.swift"),
    ("PixelXPBar",            "Views/Components/PixelXPBar.swift"),
    ("PixelBadge",            "Views/Components/PixelBadge.swift"),
    ("PixelStatPanel",        "Views/Components/PixelStatPanel.swift"),
    ("PixelButton",           "Views/Components/PixelButton.swift"),
    ("PixelAchievementCard",  "Views/Components/PixelAchievementCard.swift"),
    ("PixelDivider",          "Views/Components/PixelDivider.swift"),
    ("QuestCompletionRewardRow", "Views/Components/QuestCompletionRewardRow.swift"),
]

TEST_SOURCES = [
    ("TEST_Progression", "SetboundTests/ProgressionServiceTests.swift"),
    ("TEST_Achievement", "SetboundTests/AchievementServiceTests.swift"),
    ("TEST_Integration", "SetboundTests/IntegrationTests.swift"),
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
    a("\t\t/* End PBXBuildFile section */")
    a("")

    # ── PBXContainerItemProxy ───────────────────────────────────────────────
    a("\t\t/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{CI_TEST} /* PBXContainerItemProxy */ = {{")
    a(f"\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
    a(f"\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {TG_APP};")
    a(f"\t\t\tremoteInfo = Setbound;")
    a(f"\t\t}};")
    a("\t\t/* End PBXContainerItemProxy section */")
    a("")

    # ── PBXFileReference ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXFileReference section */")
    a(f"\t\t{FR['PROD_APP']} /* Setbound.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Setbound.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{FR['PROD_TEST']} /* SetboundTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SetboundTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for key, path in APP_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{FR['Assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t{FR[key]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    a("\t\t/* End PBXFileReference section */")
    a("")

    # ── PBXFrameworksBuildPhase ─────────────────────────────────────────────
    a("\t\t/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{BP_APP_FRM} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a(f"\t\t{BP_TEST_FRM} /* Frameworks */ = {{")
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

    # Root group
    a(f"\t\t{GR['Root']} = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{GR['Setbound']} /* Setbound */,")
    a(f"\t\t\t\t{GR['Tests']} /* SetboundTests */,")
    a(f"\t\t\t\t{GR['Products']} /* Products */,")
    a(f"\t\t\t);")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # Products group
    a(f"\t\t{GR['Products']} /* Products */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['PROD_APP']} /* Setbound.app */,")
    a(f"\t\t\t\t{FR['PROD_TEST']} /* SetboundTests.xctest */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = Products;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    # Setbound group (main app folder)
    a(f"\t\t{GR['Setbound']} /* Setbound */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    a(f"\t\t\t\t{FR['SetboundApp']} /* SetboundApp.swift */,")
    a(f"\t\t\t\t{FR['ContentView']} /* ContentView.swift */,")
    a(f"\t\t\t\t{FR['SetboundTheme']} /* SetboundTheme.swift */,")
    a(f"\t\t\t\t{GR['Models']} /* Models */,")
    a(f"\t\t\t\t{GR['Services']} /* Services */,")
    a(f"\t\t\t\t{GR['Persistence']} /* Persistence */,")
    a(f"\t\t\t\t{GR['Views']} /* Views */,")
    a(f"\t\t\t\t{FR['Assets']} /* Assets.xcassets */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = Setbound;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    def simple_group(grp_key, grp_path, file_keys):
        a(f"\t\t{GR[grp_key]} /* {grp_key} */ = {{")
        a(f"\t\t\tisa = PBXGroup;")
        a(f"\t\t\tchildren = (")
        for fk in file_keys:
            fn = FR[fk]
            filename = dict(APP_SOURCES)[fk].split("/")[-1]
            a(f"\t\t\t\t{fn} /* {filename} */,")
        a(f"\t\t\t);")
        a(f"\t\t\tpath = {grp_path};")
        a(f"\t\t\tsourceTree = \"<group>\";")
        a(f"\t\t}};")

    simple_group("Models", "Models", ["MuscleGroup", "QuestStatus", "ExerciseSet", "Exercise", "Quest", "PlayerCharacter", "MuscleProgress", "Achievement"])
    simple_group("Services", "Services", ["ProgressionService", "AchievementService"])
    simple_group("Persistence", "Persistence", ["PersistenceController"])

    # Views group
    a(f"\t\t{GR['Views']} /* Views */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key in ["QuestDashboardView", "QuestListView", "QuestDetailView", "ExerciseLoggingView",
                "CharacterProgressView", "QuestHistoryView", "AchievementsView", "QuestCompletionView"]:
        filename = dict(APP_SOURCES)[key].split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t\t{GR['Components']} /* Components */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = Views;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    simple_group("Components", "Components", ["PixelQuestCard", "PixelXPBar", "PixelBadge", "PixelStatPanel",
                                               "PixelButton", "PixelAchievementCard", "PixelDivider", "QuestCompletionRewardRow"])

    # Tests group
    a(f"\t\t{GR['Tests']} /* SetboundTests */ = {{")
    a(f"\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = (")
    for key, path in TEST_SOURCES:
        filename = path.split("/")[-1]
        a(f"\t\t\t\t{FR[key]} /* {filename} */,")
    a(f"\t\t\t);")
    a(f"\t\t\tpath = SetboundTests;")
    a(f"\t\t\tsourceTree = \"<group>\";")
    a(f"\t\t}};")

    a("\t\t/* End PBXGroup section */")
    a("")

    # ── PBXNativeTarget ────────────────────────────────────────────────────
    a("\t\t/* Begin PBXNativeTarget section */")
    a(f"\t\t{TG_APP} /* Setbound */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_APP} /* Build configuration list for PBXNativeTarget \"Setbound\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_APP_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_APP_FRM} /* Frameworks */,")
    a(f"\t\t\t\t{BP_APP_RES} /* Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t);")
    a(f"\t\t\tname = Setbound;")
    a(f"\t\t\tproductName = Setbound;")
    a(f"\t\t\tproductReference = {FR['PROD_APP']} /* Setbound.app */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    a(f"\t\t}};")
    a(f"\t\t{TG_TEST} /* SetboundTests */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {CL_TEST} /* Build configuration list for PBXNativeTarget \"SetboundTests\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{BP_TEST_SRC} /* Sources */,")
    a(f"\t\t\t\t{BP_TEST_FRM} /* Frameworks */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t\t{TD_TEST} /* PBXTargetDependency */,")
    a(f"\t\t\t);")
    a(f"\t\t\tname = SetboundTests;")
    a(f"\t\t\tproductName = SetboundTests;")
    a(f"\t\t\tproductReference = {FR['PROD_TEST']} /* SetboundTests.xctest */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
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
    a(f"\t\t\t\t}};")
    a(f"\t\t\t}};")
    a(f"\t\t\tbuildConfigurationList = {CL_PROJECT} /* Build configuration list for PBXProject \"Setbound\" */;")
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
    a(f"\t\t\t\t{TG_APP} /* Setbound */,")
    a(f"\t\t\t\t{TG_TEST} /* SetboundTests */,")
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
    a("\t\t/* End PBXSourcesBuildPhase section */")
    a("")

    # ── PBXTargetDependency ─────────────────────────────────────────────────
    a("\t\t/* Begin PBXTargetDependency section */")
    a(f"\t\t{TD_TEST} /* PBXTargetDependency */ = {{")
    a(f"\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {TG_APP} /* Setbound */;")
    a(f"\t\t\ttargetProxy = {CI_TEST} /* PBXContainerItemProxy */;")
    a(f"\t\t}};")
    a("\t\t/* End PBXTargetDependency section */")
    a("")

    # ── XCBuildConfiguration ────────────────────────────────────────────────
    a("\t\t/* Begin XCBuildConfiguration section */")

    def project_config(uuid, name):
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
        debug_only = name == "Debug"
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
        a(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a(f"\t\t\t\tDEVELOPMENT_TEAM = 5T5444U7W2;")
        if debug:
            a(f"\t\t\t\tENABLE_TESTABILITY = YES;")
        a(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a(f"\t\t\t\tENABLE_PREVIEWS = YES;")
        a(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Setbound;")
        a(f"\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown\";")
        a(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait\";")
        a(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        a(f"\t\t\t\tMARKETING_VERSION = 1.0;")
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.Setbound;")
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
        a(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.SetboundTests;")
        a(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a(f"\t\t\t\tSDKROOT = iphoneos;")
        a(f"\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
        a(f"\t\t\t\tSWIFT_VERSION = 6.0;")
        a(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        a(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Setbound.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Setbound\";")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    test_config(BC_TEST_DBG, "Debug")
    test_config(BC_TEST_REL, "Release")

    a("\t\t/* End XCBuildConfiguration section */")
    a("")

    # ── XCConfigurationList ─────────────────────────────────────────────────
    a("\t\t/* Begin XCConfigurationList section */")
    a(f"\t\t{CL_PROJECT} /* Build configuration list for PBXProject \"Setbound\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_PROJ_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_PROJ_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_APP} /* Build configuration list for PBXNativeTarget \"Setbound\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_APP_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_APP_REL} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{CL_TEST} /* Build configuration list for PBXNativeTarget \"SetboundTests\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{BC_TEST_DBG} /* Debug */,")
    a(f"\t\t\t\t{BC_TEST_REL} /* Release */,")
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
    proj_dir = os.path.join(base, "Setbound.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
    content = pbxproj()
    with open(pbxproj_path, "w") as f:
        f.write(content)
    print(f"Generated: {pbxproj_path}")
    print(f"Lines: {len(content.splitlines())}")
