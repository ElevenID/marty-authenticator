"""Run the CI Gradle adapter in an owned Gradle 8.11.1 fixture.

The real Cargokit Gradle plugin and artifact scripts execute here. Android/Flutter
project interfaces and ELF payloads are controlled fixtures; this is not an APK
build, installed-device run or native cryptographic qualification.
"""
from __future__ import annotations

import argparse
import errno
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

from android_native_artifacts import BRIDGE, INPUTS, NDK, ONNX_RUNTIME, TARGETS
from test_verify_android_native_bridge import elf


ROOT = Path(__file__).resolve().parents[1]
GRADLE = None

BUILD = r'''
import org.gradle.api.tasks.*

class FixtureJni { void srcDir(File value) {} }
class FixtureSourceSet {
    final String name
    def jniLibs = new FixtureJni()
    FixtureSourceSet(String name) { this.name = name }
}
class FixtureVariant {
    final String name
    def buildType = new Expando(name: 'debug')
    FixtureVariant(String name) { this.name = name }
}
class FlutterPlugin implements Plugin<Project> {
    Project project
    void apply(Project project) { this.project = project }
    List<String> getTargetPlatforms() {
        (project.findProperty('target-platform') ?: 'android-arm,android-arm64,android-x64').split(',').toList()
    }
}
abstract class FixtureFlutterTask extends DefaultTask {
    @Input String flavor
    @Input String targetPath
    @Input String buildMode
    @Input List<String> targetPlatformValues
    @Input @Optional String dartDefines
    @TaskAction void executeFixture() {
        def destination = new File(project.rootProject.projectDir.parentFile, "build/observed/${name}.json")
        destination.parentFile.mkdirs()
        destination.text = groovy.json.JsonOutput.toJson([flavor:flavor, target:targetPath,
            mode:buildMode, targets:targetPlatformValues, dartDefines:dartDefines])
    }
}
def workspace = rootProject.projectDir.parentFile
allprojects { buildDir = new File(workspace, "build/${project.name}") }
project(':app') {
    apply plugin: FlutterPlugin
    def variants = container(FixtureVariant)
    variants.create('netknightsDebug')
    variants.create('netknights_debugDebug')
    extensions.add('android', new Expando(libraryVariants: variants, ndkVersion:'28.2.13676358',
        sdkDirectory:System.getenv('ANDROID_SDK_ROOT'),
        compileSdkVersion:'android-36', defaultConfig:new Expando(minSdkVersion:new Expando(apiLevel:26))))
    ['NetknightsDebug':'netknights', 'Netknights_debugDebug':'netknights_debug'].each { suffix, variant ->
        def compile = tasks.register("compileFlutterBuild${suffix}", FixtureFlutterTask) {
            flavor = project.hasProperty('fixtureWrongFlavor') ? 'wrong' : variant
            targetPath = project.hasProperty('fixtureWrongTarget') ? new File(workspace, 'lib/wrong.dart').path : project.property('target')
            buildMode = 'debug'
            targetPlatformValues = project.property('target-platform').split(',').toList()
            dartDefines = project.hasProperty('fixtureWrongDefines') ? 'unexpected' : null
        }
        tasks.register("assemble${suffix}") {
            dependsOn(compile, ':marty_authenticator_bridge:mergeDebugNativeLibs')
            doLast {
                def output = new File(workspace, "build/observed/assembled-${variant}")
                output.parentFile.mkdirs()
                output.text = 'assembled'
            }
        }
    }
}
project(':marty_authenticator_bridge') {
    extensions.add('android', new Expando(sourceSets: container(FixtureSourceSet)))
    apply from: new File(workspace, 'rust_builder/cargokit/gradle/plugin.gradle')
    cargokit { manifestDir = '../../rust'; libname = 'marty_authenticator_bridge' }
    tasks.register('mergeDebugNativeLibs')
    tasks.matching { it.name.startsWith('cargokitCargoBuild') }.configureEach {
        onlyIf { !project.hasProperty('fixtureSkipSource') }
    }
}
'''

PRODUCER = r'''
import os,struct
from pathlib import Path
target=os.environ['CARGOKIT_TARGET_PLATFORMS']
abis={'android-arm':('armeabi-v7a',1,40),'android-arm64':('arm64-v8a',2,183),'android-x64':('x86_64',2,62)}
abi,kind,machine=abis[target]
data=bytearray(120);data[:7]=b'\x7fELF'+bytes((kind,1,1));struct.pack_into('<HH',data,16,3,machine)
if kind==2:
    struct.pack_into('<Q',data,32,64);struct.pack_into('<HH',data,54,56,1);struct.pack_into('<Q',data,112,16384)
else:
    struct.pack_into('<I',data,28,64);struct.pack_into('<HH',data,42,32,1);struct.pack_into('<I',data,92,4096)
struct.pack_into('<I',data,64,1)
output=Path(os.environ['CARGOKIT_OUTPUT_DIR'])/abi;output.mkdir(parents=True,exist_ok=True)
(output/'libmarty_authenticator_bridge.so').write_bytes(bytes(data)+b'DEBUG_ONLY')
(output/'libonnxruntime.so').write_bytes(bytes(data))
'''


class GradleAdapterContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="wallet-gradle-adapter-")
        cls.addClassCleanup(cls.cleanup)
        cls.home = Path(cls.temporary.name)
        cls.repo = cls.home / "candidate"
        cls.temp = cls.home / "runtime"
        cls.temp.mkdir()
        cls.repo.mkdir()
        for name in INPUTS:
            file = cls.repo / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("controlled fixture\n")
        for name in ("scripts/android_native_artifacts.py", "scripts/verify_android_native_bridge.py",
                     ".github/scripts/android-native-artifacts.init.gradle",
                     "rust_builder/cargokit/gradle/plugin.gradle"):
            destination = cls.repo / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)
        (cls.repo / "scripts/make_fixture_native.py").write_text(PRODUCER)
        runner = cls.repo / "rust_builder/cargokit/run_build_tool.sh"
        runner.write_text('#!/bin/sh\nset -eu\ntest "$1" = build-gradle\n'
                          'python3 "$CARGOKIT_ROOT_PROJECT_DIR/../scripts/make_fixture_native.py"\n')
        shutil.copymode(ROOT / "rust_builder/cargokit/run_build_tool.sh", runner)
        (cls.repo / "rust_builder/android/onnxruntime-android.lock.json").write_text(json.dumps({
            "libraries": {abi: {"sha256":hashlib.sha256(elf(abi)).hexdigest()} for abi in TARGETS}
        }))
        (cls.repo / "android/build.gradle").write_text(BUILD)
        (cls.repo / "android/settings.gradle").write_text("rootProject.name='adapter-fixture'\ninclude ':app', ':marty_authenticator_bridge'\n")
        (cls.repo / "android/app").mkdir(exist_ok=True)
        (cls.repo / "android/app/build.gradle").write_text("// Controlled Android interfaces are configured by the root fixture.\n")
        (cls.repo / "android/marty_authenticator_bridge").mkdir()
        (cls.repo / "android/marty_authenticator_bridge/build.gradle").write_text("// The real Cargokit plugin is configured by the root fixture.\n")
        (cls.repo / "android/gradle.properties").write_text("org.gradle.jvmargs=-Xmx512m -Dfile.encoding=UTF-8\n")
        (cls.repo / "lib").mkdir()
        (cls.repo / "lib/main_document.dart").write_text("// controlled entrypoint\n")
        (cls.repo / ".gitignore").write_text("build/\n.gradle/\n__pycache__/\n")
        subprocess.run(["git", "init", "-q", str(cls.repo)], check=True)
        subprocess.run(["git", "-C", str(cls.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(cls.repo), "-c", "user.name=Fixture", "-c",
                        "user.email=fixture@example.invalid", "commit", "-qm", "adapter fixture"], check=True)
        cls.commit = subprocess.check_output(["git", "-C", str(cls.repo), "rev-parse", "HEAD"], text=True).strip()
        sdk = cls.temp / "sdk"
        ndk = sdk / "ndk" / NDK
        binary_dir = ndk / "toolchains/llvm/prebuilt/linux-x86_64/bin"
        binary_dir.mkdir(parents=True)
        (ndk / "source.properties").write_text(f"Pkg.Revision = {NDK}\n")
        implementation = binary_dir / "llvm-objcopy"
        implementation.write_text("#!/usr/bin/env python3\nimport pathlib,sys\n"
                                  "assert pathlib.Path(sys.argv[0]).name == 'llvm-strip'\n"
                                  "assert sys.argv[1:3] == ['--strip-unneeded','-o']\n"
                                  "pathlib.Path(sys.argv[3]).write_bytes(pathlib.Path(sys.argv[4]).read_bytes().removesuffix(b'DEBUG_ONLY'))\n")
        implementation.chmod(0o755)
        (binary_dir / "llvm-strip").symlink_to(implementation)
        cls.gradle_home = cls.temp / "gradle-user"
        cls.gradle_home.mkdir()
        existing_dists = Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle"))) / "wrapper/dists"
        if existing_dists.is_dir():
            (cls.gradle_home / "wrapper").mkdir()
            (cls.gradle_home / "wrapper/dists").symlink_to(existing_dists.resolve(), target_is_directory=True)
        cls.env = dict(os.environ, GITHUB_ACTIONS="true", GITHUB_REPOSITORY="ElevenID/marty-authenticator",
                       GITHUB_SHA=cls.commit, GITHUB_RUN_ID="123456", GITHUB_RUN_ATTEMPT="2",
                       GITHUB_WORKSPACE=str(cls.repo), RUNNER_TEMP=str(cls.temp),
                       ANDROID_SDK_ROOT=str(sdk), CARGO_PROFILE_DEV_DEBUG="0",
                       GRADLE_USER_HOME=str(cls.gradle_home))
        cls.artifacts = cls.temp / "downloaded"
        cls.artifacts.mkdir()
        for abi, (platform, _) in TARGETS.items():
            shutil.rmtree(cls.repo / "build", ignore_errors=True)
            output = cls.artifacts / f"wallet-native-123456-2-{cls.commit}-{abi}"
            result = cls.run_gradle("source", output, platform, ["martyExportAndroidNativeArtifact"], [f"-PmartyNativeAbi={abi}"])
            if result.returncode:
                raise AssertionError("actual Cargokit/CI source fixture failed:\n" + result.stdout[-18000:])

    @classmethod
    def cleanup(cls):
        try:
            if hasattr(cls, "env"):
                subprocess.run([str(GRADLE), "--stop"], cwd=cls.repo / "android", env=cls.env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        finally:
            # Gradle's stop command can return just before the owned daemon
            # finishes flushing its cache. Retry only that bounded cleanup race.
            deadline = time.monotonic() + 5
            while True:
                try:
                    cls.temporary.cleanup()
                    break
                except OSError as error:
                    if error.errno != errno.ENOTEMPTY or time.monotonic() >= deadline:
                        raise
                    time.sleep(0.1)

    @classmethod
    def run_gradle(cls, mode, output, platforms, tasks, extra=None):
        command = [str(GRADLE), "--console=plain", "--stacktrace", "--daemon",
                   "--init-script", str(cls.repo / ".github/scripts/android-native-artifacts.init.gradle"),
                   f"-Ptarget={cls.repo}/lib/main_document.dart", f"-Ptarget-platform={platforms}",
                   "-Pbase-application-name=android.app.Application", f"-PmartyNativeMode={mode}",
                   f"-PmartyNativeArtifactRoot={output}", *(extra or []), *tasks]
        return subprocess.run(command, cwd=cls.repo / "android", env=cls.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)

    def setUp(self):
        shutil.rmtree(self.repo / "build", ignore_errors=True)

    def assemble(self, extra=None, platforms="android-arm,android-arm64,android-x64"):
        return self.run_gradle("assemble", self.artifacts, platforms,
                               ["assembleNetknightsDebug", "assembleNetknights_debugDebug"], extra)

    def test_both_flavors_execute_with_exact_entrypoint_and_three_native_outputs(self):
        result = self.assemble()
        self.assertEqual(result.returncode, 0, result.stdout[-18000:])
        observed = self.repo / "build/observed"
        for suffix, flavor in (("NetknightsDebug", "netknights"), ("Netknights_debugDebug", "netknights_debug")):
            data = json.loads((observed / f"compileFlutterBuild{suffix}.json").read_text())
            self.assertEqual(data["flavor"], flavor)
            self.assertEqual(data["target"], str(self.repo / "lib/main_document.dart"))
            self.assertEqual(set(data["targets"]), {value[0] for value in TARGETS.values()})
            self.assertIsNone(data["dartDefines"])
            self.assertTrue((observed / f"assembled-{flavor}").exists())
        for abi in TARGETS:
            native = self.repo / "build/marty_authenticator_bridge/jniLibs/debug" / abi
            self.assertEqual((native / BRIDGE).read_bytes(), elf(abi) + b"DEBUG_ONLY")
            self.assertEqual((native / ONNX_RUNTIME).read_bytes(), elf(abi))

    def test_changed_entrypoint_or_dart_defines_are_rejected(self):
        for option in ("fixtureWrongTarget", "fixtureWrongDefines"):
            result = self.assemble([f"-P{option}=true"])
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Both original Flutter flavors", result.stdout)

    def test_changed_flavor_or_missing_target_is_rejected(self):
        result = self.assemble(["-PfixtureWrongFlavor=true"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Both original Flutter flavors", result.stdout)
        result = self.assemble(platforms="android-arm64")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("all three reviewed Android targets", result.stdout)

    def test_stale_outputs_do_not_qualify_a_skipped_source_task(self):
        native = self.repo / "build/marty_authenticator_bridge/jniLibs/debug/x86_64"
        native.mkdir(parents=True)
        artifact = self.artifacts / f"wallet-native-123456-2-{self.commit}-x86_64"
        for name in (BRIDGE, ONNX_RUNTIME):
            shutil.copyfile(artifact / name, native / name)
        result = self.run_gradle("source", self.temp / "skipped-source", "android-x64",
                                 ["martyExportAndroidNativeArtifact"],
                                 ["-PmartyNativeAbi=x86_64", "-PfixtureSkipSource=true"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source-build action did not execute", result.stdout)
        self.assertFalse((self.temp / "skipped-source").exists())

    def test_wrong_run_artifact_fails_before_either_flavor_is_assembled(self):
        path = self.artifacts / f"wallet-native-123456-2-{self.commit}-arm64-v8a/manifest.json"
        original = path.read_text()
        altered = json.loads(original)
        altered["context"]["runAttempt"] = "1"
        path.write_text(json.dumps(altered))
        try:
            result = self.assemble()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("provenance does not match", result.stdout)
            self.assertFalse((self.repo / "build/observed/assembled-netknights").exists())
            self.assertFalse((self.repo / "build/observed/assembled-netknights_debug").exists())
        finally:
            path.write_text(original)


def main():
    global GRADLE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gradle", type=Path, required=True)
    args = parser.parse_args()
    GRADLE = args.gradle.resolve(strict=True)
    version = subprocess.check_output([str(GRADLE), "--version"], text=True)
    if "Gradle 8.11.1\n" not in version:
        raise SystemExit("The adapter fixture requires exactly Gradle8.11.1")
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(GradleAdapterContract)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise SystemExit(1)
    print(json.dumps({"scope":"actual Gradle adapter with controlled Android interfaces and synthetic ELF",
                      "gradle":"8.11.1", "tests":result.testsRun,
                      "adapterSha256":hashlib.sha256((ROOT / '.github/scripts/android-native-artifacts.init.gradle').read_bytes()).hexdigest()}, sort_keys=True))


if __name__ == "__main__":
    main()
