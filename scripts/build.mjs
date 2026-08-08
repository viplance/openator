import { mkdir, rm, cp, readFile, writeFile, chmod, access } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const distRoot = join(root, "dist");
const appName = "Openator";
const appBundle = join(distRoot, `${appName}.app`);
const appContents = join(appBundle, "Contents");
const macOSDir = join(appContents, "MacOS");
const resourcesDir = join(appContents, "Resources");
const swiftBinary = join(root, ".build", "release", appName);
const appBinary = join(macOSDir, appName);
const entitlements = join(root, "Openator.entitlements");
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
await rm(appBundle, { recursive: true, force: true });

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
  appBundle,
]);

console.log(`Done. App bundle: ${appBundle}`);
