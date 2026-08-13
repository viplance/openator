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
// Developer ID builds do not carry an App Store provisioning profile. Keep
// their entitlements separate from Openator.entitlements, which is used for
// App Store distribution and includes profile-backed identifiers.
const entitlements = join(root, "Openator.DeveloperID.entitlements");
const signingIdentity = "Developer ID Application: Dzmitry Sharko (W37L5728Y6)";

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

await mkdir(distRoot, { recursive: true });
await rm(stagedAppBundle, { recursive: true, force: true });

console.log("Building Swift release binary...");
await run("swift", ["build", "-c", "release"]);

console.log("Assembling app bundle...");
await mkdir(macOSDir, { recursive: true });
await mkdir(resourcesDir, { recursive: true });
await cp(swiftBinary, appBinary);
await chmod(appBinary, 0o755);

// Copy Info.plist
const plistSrc = join(root, "Info.plist");
await cp(plistSrc, join(appContents, "Info.plist"));

// Copy icon if available
const iconPath = join(root, "assets", "icon.icns");
try {
  await access(iconPath);
  await cp(iconPath, join(resourcesDir, "AppIcon.icns"));
} catch {
  console.warn("Warning: assets/icon.icns not found. Run `pnpm icon` first.");
}

console.log(`Signing with: ${signingIdentity}`);
await run("codesign", [
  "--force",
  "--deep",
  "--options", "runtime",
  "--entitlements",
  entitlements,
  "--sign",
  signingIdentity,
  stagedAppBundle,
]);

// Publish only a fully assembled and signed bundle.
await rm(appBundle, { recursive: true, force: true });
await rename(stagedAppBundle, appBundle);

console.log(`Done. App bundle: ${appBundle}`);
