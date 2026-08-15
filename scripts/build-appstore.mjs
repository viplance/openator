import { mkdir, rm, cp, chmod, access, rename } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const distRoot = join(root, "dist");
const appName = "Openator";
const appBundle = join(distRoot, `${appName}.app`);
const stagedAppBundle = join(distRoot, `${appName}.app.building`);
const appContents = join(stagedAppBundle, "Contents");
const macOSDir = join(appContents, "MacOS");
const resourcesDir = join(appContents, "Resources");
const swiftBinary = join(root, ".build", "release", appName);
const appBinary = join(macOSDir, appName);
const entitlements = join(root, "Openator.entitlements");
const signingIdentity = "Apple Distribution: Dzmitry Sharko (W37L5728Y6)";
const installerIdentity = "3rd Party Mac Developer Installer: Dzmitry Sharko (W37L5728Y6)";
const provisioningProfile = join(
  process.env.HOME,
  "Library/MobileDevice/Provisioning Profiles/Openator_App_Store.provisionprofile"
);
const pkgPath = join(distRoot, `${appName}.pkg`);

function run(command, args, options = {}) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd: root,
      stdio: "inherit",
      ...options,
    });
    child.on("exit", (code) => {
      if (code === 0) return resolvePromise();
      reject(new Error(`${command} ${args.join(" ")} failed with code ${code}`));
    });
    child.on("error", reject);
  });
}

console.log("=== App Store Build ===\n");

// Verify provisioning profile exists
try {
  await access(provisioningProfile);
} catch {
  console.error(`ERROR: Provisioning profile not found: ${provisioningProfile}`);
  process.exit(1);
}

await mkdir(distRoot, { recursive: true });
await rm(stagedAppBundle, { recursive: true, force: true });

console.log("1) Building Swift release binary...");
await run("swift", ["build", "-c", "release"]);

console.log("\n2) Assembling app bundle...");
await mkdir(macOSDir, { recursive: true });
await mkdir(resourcesDir, { recursive: true });
await cp(swiftBinary, appBinary);
await chmod(appBinary, 0o755);

await cp(join(root, "Info.plist"), join(appContents, "Info.plist"));

const iconPath = join(root, "assets", "icon.icns");
try {
  await access(iconPath);
  await cp(iconPath, join(resourcesDir, "AppIcon.icns"));
} catch {
  console.error("ERROR: assets/icon.icns not found. Run `npm run icon` first.");
  process.exit(1);
}

// Embed provisioning profile (required for App Store)
await cp(provisioningProfile, join(appContents, "embedded.provisionprofile"));

console.log("\n3) Compiling asset catalog...");
await run("xcrun", [
  "actool",
  join(root, "Assets.xcassets"),
  "--compile", resourcesDir,
  "--platform", "macosx",
  "--minimum-deployment-target", "13.0",
  "--app-icon", "AppIcon",
  "--output-partial-info-plist", join(distRoot, "partial-info.plist"),
]);

// actool overwrites AppIcon.icns with an incomplete version — restore the full one
await cp(iconPath, join(resourcesDir, "AppIcon.icns"));

console.log("\n4) Stripping extended attributes...");
await run("xattr", ["-cr", stagedAppBundle]);

console.log(`\n5) Signing with: ${signingIdentity}`);
await run("codesign", [
  "--force",
  "--deep",
  "--options", "runtime",
  "--entitlements", entitlements,
  "--sign", signingIdentity,
  stagedAppBundle,
]);

// Atomic swap
await rm(appBundle, { recursive: true, force: true });
await rename(stagedAppBundle, appBundle);

console.log("\n6) Verifying signature...");
await run("codesign", ["--verify", "--deep", "--strict", appBundle]);

console.log("\n7) Verifying entitlements...");
await run("codesign", ["-d", "--entitlements", "-", appBundle]);

console.log(`\n8) Building installer package with: ${installerIdentity}`);
await rm(pkgPath, { force: true });
await run("productbuild", [
  "--component", appBundle, "/Applications",
  "--sign", installerIdentity,
  pkgPath,
]);

console.log(`\n=== Done ===`);
console.log(`App bundle: ${appBundle}`);
console.log(`Installer:  ${pkgPath}`);
console.log(`\nTo upload:  xcrun altool --upload-app -f ${pkgPath} -t macos -u YOUR_APPLE_ID -p @keychain:AC_PASSWORD`);
