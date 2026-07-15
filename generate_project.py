#!/usr/bin/env python3
from pathlib import Path
import hashlib

ROOT = Path(__file__).parent
PROJECT = ROOT / "RepSetForge.xcodeproj"
SCHEME_DIR = PROJECT / "xcshareddata" / "xcschemes"


def uid(seed: str) -> str:
    return hashlib.sha1(seed.encode()).hexdigest().upper()[:24]


def source_files(*bases: str):
    files = []
    for base in bases:
        root = ROOT / base
        if root.exists():
            files.extend(str(p.relative_to(ROOT)) for p in root.rglob("*.swift"))
    return sorted(files)


def plist_files(base: str):
    root = ROOT / base
    return sorted(str(p.relative_to(ROOT)) for p in root.rglob("*.plist")) if root.exists() else []


objects = {}


def add(k, v):
    objects[k] = v


def quote_list(values):
    return ", ".join(values)


project_id = uid("project")
main_group = uid("main_group")
products_group = uid("products_group")

targets = {
    "app": {
        "name": "RepSetForge",
        "product": "RepSetForge.app",
        "product_type": "com.apple.product-type.application",
        "explicit_type": "wrapper.application",
        "sources": source_files("RepSetForge", "RepSetForgeShared"),
        "group_path": "RepSetForge",
        "extra_groups": ["RepSetForgeShared"],
    },
    "widgets": {
        "name": "RepSetForgeWidgets",
        "product": "RepSetForgeWidgets.appex",
        "product_type": "com.apple.product-type.app-extension",
        "explicit_type": "wrapper.app-extension",
        "sources": source_files("RepSetForgeWidgets", "RepSetForgeShared"),
        "group_path": "RepSetForgeWidgets",
        "extra_groups": ["RepSetForgeShared"],
    },
    "watch": {
        "name": "RepSetForgeWatch",
        "product": "RepSetForgeWatch.app",
        "product_type": "com.apple.product-type.application",
        "explicit_type": "wrapper.application",
        "sources": source_files("RepSetForgeWatch"),
        "group_path": "RepSetForgeWatch",
        "extra_groups": [],
    },
    "tests": {
        "name": "RepSetForgeTests",
        "product": "RepSetForgeTests.xctest",
        "product_type": "com.apple.product-type.bundle.unit-test",
        "explicit_type": "wrapper.cfbundle",
        "sources": source_files("RepSetForgeTests"),
        "group_path": "RepSetForgeTests",
        "extra_groups": [],
    },
}

for key, target in targets.items():
    target["target_id"] = uid(f"{key}:target")
    target["product_id"] = uid(f"{key}:product")
    target["sources_phase"] = uid(f"{key}:sources")
    target["frameworks_phase"] = uid(f"{key}:frameworks")
    target["resources_phase"] = uid(f"{key}:resources")
    target["config_debug"] = uid(f"{key}:debug")
    target["config_release"] = uid(f"{key}:release")
    target["config_list"] = uid(f"{key}:config_list")
    target["build_files"] = []
    target["file_refs"] = []

all_file_refs = {}


def file_ref(path: str):
    if path in all_file_refs:
        return all_file_refs[path]
    ref = uid("ref:" + path)
    file_type = "sourcecode.swift" if path.endswith(".swift") else "text.plist.xml"
    add(ref, f'isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{path}"; sourceTree = SOURCE_ROOT;')
    all_file_refs[path] = ref
    return ref


for key, target in targets.items():
    for path in target["sources"]:
        ref = file_ref(path)
        bf = uid(f"build:{key}:{path}")
        add(bf, f"isa = PBXBuildFile; fileRef = {ref};")
        target["build_files"].append(bf)
        target["file_refs"].append((path, ref))

for path in plist_files("RepSetForgeWidgets") + plist_files("RepSetForgeWatch"):
    file_ref(path)

for target in targets.values():
    add(target["product_id"], f'isa = PBXFileReference; explicitFileType = {target["explicit_type"]}; includeInIndex = 0; path = {target["product"]}; sourceTree = BUILT_PRODUCTS_DIR;')

add(products_group, f'isa = PBXGroup; children = ({quote_list(t["product_id"] for t in targets.values())}); name = Products; sourceTree = "<group>";')

group_ids = []
for group_path in ["RepSetForge", "RepSetForgeShared", "RepSetForgeWidgets", "RepSetForgeWatch", "RepSetForgeTests"]:
    group_id = uid("group:" + group_path)
    children = []
    for path, ref in all_file_refs.items():
        if path.startswith(group_path + "/"):
            children.append(ref)
    add(group_id, f'isa = PBXGroup; children = ({quote_list(children)}); path = {group_path}; sourceTree = "<group>";')
    group_ids.append(group_id)

add(main_group, f'isa = PBXGroup; children = ({quote_list(group_ids + [products_group])}); sourceTree = "<group>";')

for target in targets.values():
    add(target["sources_phase"], f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({quote_list(target["build_files"])}); runOnlyForDeploymentPostprocessing = 0;')
    add(target["frameworks_phase"], "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    add(target["resources_phase"], "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")

embed_widgets_phase = uid("app:embed_widgets")
embed_watch_phase = uid("app:embed_watch")
widget_embed_bf = uid("embed:widgets")
watch_embed_bf = uid("embed:watch")
add(widget_embed_bf, f'isa = PBXBuildFile; fileRef = {targets["widgets"]["product_id"]}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }};')
add(watch_embed_bf, f'isa = PBXBuildFile; fileRef = {targets["watch"]["product_id"]}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }};')
add(embed_widgets_phase, f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({widget_embed_bf}); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;')
add(embed_watch_phase, f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; files = ({watch_embed_bf}); name = "Embed Watch Content"; runOnlyForDeploymentPostprocessing = 0;')

proj_debug = uid("proj_debug")
proj_release = uid("proj_release")
proj_config_list = uid("proj_config_list")

common_project_settings = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				DEVELOPMENT_TEAM = "";
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_VERSION = 6.0;
"""


def config(name, settings):
    return f"""isa = XCBuildConfiguration; buildSettings = {{
{settings}
			}}; name = {name};"""


add(proj_debug, config("Debug", common_project_settings + "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n"))
add(proj_release, config("Release", common_project_settings))
add(proj_config_list, f'isa = XCConfigurationList; buildConfigurations = ({proj_debug}, {proj_release}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

app_settings_debug = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = RepSetForge/RepSetForge.entitlements;
				CODE_SIGN_STYLE = Automatic;
				ENABLE_TESTABILITY = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = RepSetForge/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_EMIT_LOC_STRINGS = YES;
"""
app_settings_release = app_settings_debug.replace('				ENABLE_TESTABILITY = YES;\n', '').replace('				SWIFT_OPTIMIZATION_LEVEL = "-Onone";\n', '')

widget_settings = """
				CODE_SIGN_ENTITLEMENTS = RepSetForgeWidgets/RepSetForgeWidgets.entitlements;
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = RepSetForgeWidgets/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge.widgets;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
"""

watch_settings = """
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = RepSetForgeWatch/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForge.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 10.0;
"""

test_settings = """
				BUNDLE_LOADER = "$(TEST_HOST)";
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = dev.gnwn.RepSetForgeTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/RepSetForge.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RepSetForge";
"""

target_settings = {
    "app": (app_settings_debug, app_settings_release),
    "widgets": (widget_settings + '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n', widget_settings),
    "watch": (watch_settings + '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n', watch_settings),
    "tests": (test_settings, test_settings),
}

for key, target in targets.items():
    debug_settings, release_settings = target_settings[key]
    add(target["config_debug"], config("Debug", debug_settings))
    add(target["config_release"], config("Release", release_settings))
    add(target["config_list"], f'isa = XCConfigurationList; buildConfigurations = ({target["config_debug"]}, {target["config_release"]}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

dependencies = {key: [] for key in targets}


def target_dependency(owner: str, dependency: str):
    proxy = uid(f"proxy:{owner}:{dependency}")
    dep = uid(f"dependency:{owner}:{dependency}")
    add(proxy, f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {targets[dependency]["target_id"]}; remoteInfo = {targets[dependency]["name"]};')
    add(dep, f'isa = PBXTargetDependency; target = {targets[dependency]["target_id"]}; targetProxy = {proxy};')
    dependencies[owner].append(dep)


target_dependency("app", "widgets")
target_dependency("tests", "app")

for key, target in targets.items():
    phases = [target["sources_phase"], target["frameworks_phase"], target["resources_phase"]]
    if key == "app":
        phases.append(embed_widgets_phase)
    add(target["target_id"], f'isa = PBXNativeTarget; buildConfigurationList = {target["config_list"]}; buildPhases = ({quote_list(phases)}); buildRules = (); dependencies = ({quote_list(dependencies[key])}); name = {target["name"]}; productName = {target["name"]}; productReference = {target["product_id"]}; productType = "{target["product_type"]}";')

target_attributes = " ".join(f'{target["target_id"]} = {{ CreatedOnToolsVersion = 26.6; }};' for target in targets.values())
add(project_id, f'isa = PBXProject; attributes = {{ LastSwiftUpdateCheck = 2660; LastUpgradeCheck = 2660; TargetAttributes = {{ {target_attributes} }}; }}; buildConfigurationList = {proj_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = ({quote_list(target["target_id"] for target in targets.values())});')

PROJECT.mkdir(exist_ok=True)
SCHEME_DIR.mkdir(parents=True, exist_ok=True)

with (PROJECT / "project.pbxproj").open("w") as f:
    f.write("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n")
    for key, value in sorted(objects.items()):
        f.write(f"\t\t{key} = {{{value}}};\n")
    f.write(f"\t}};\n\trootObject = {project_id};\n}}\n")

scheme_entries = "\n".join(
    f'''      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[key]["target_id"]}" BuildableName="{targets[key]["product"]}" BlueprintName="{targets[key]["name"]}" ReferencedContainer="container:RepSetForge.xcodeproj"/>
      </BuildActionEntry>'''
    for key in ["app", "widgets"]
)

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
{scheme_entries}
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["tests"]["target_id"]}" BuildableName="RepSetForgeTests.xctest" BlueprintName="RepSetForgeTests" ReferencedContainer="container:RepSetForge.xcodeproj"/>
      </TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["app"]["target_id"]}" BuildableName="RepSetForge.app" BlueprintName="RepSetForge" ReferencedContainer="container:RepSetForge.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["app"]["target_id"]}" BuildableName="RepSetForge.app" BlueprintName="RepSetForge" ReferencedContainer="container:RepSetForge.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(SCHEME_DIR / "RepSetForge.xcscheme").write_text(scheme)

watch_scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["watch"]["target_id"]}" BuildableName="RepSetForgeWatch.app" BlueprintName="RepSetForgeWatch" ReferencedContainer="container:RepSetForge.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"/>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["watch"]["target_id"]}" BuildableName="RepSetForgeWatch.app" BlueprintName="RepSetForgeWatch" ReferencedContainer="container:RepSetForge.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets["watch"]["target_id"]}" BuildableName="RepSetForgeWatch.app" BlueprintName="RepSetForgeWatch" ReferencedContainer="container:RepSetForge.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(SCHEME_DIR / "RepSetForgeWatch.xcscheme").write_text(watch_scheme)
print("Generated RepSetForge.xcodeproj")
