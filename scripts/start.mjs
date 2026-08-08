import { access } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const appName = "Openator";
const appBundle = join(root, "dist", `${appName}.app`);
const execFileAsync = promisify(execFile);

function runNode(scriptPath) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(process.execPath, [scriptPath], {
      cwd: root,
      stdio: "inherit",
      env: process.env,
    });
    child.on("exit", (code) =>
      code === 0
        ? resolvePromise()
        : reject(new Error(`script exited with code ${code}`))
    );
    child.on("error", reject);
  });
}

async function main() {
  console.log("\n=== Openator: start ===\n");

  console.log("1) Building…");
  await runNode(join(root, "scripts", "build.mjs"));

  console.log("\n2) Stopping any running instance…");
  try {
    await execFileAsync("pkill", [
      "-f",
      "Openator.app/Contents/MacOS/Openator",
    ]);
  } catch {
    // pkill returns 1 if no process matched
  }

  try {
    await access(appBundle);
  } catch {
    throw new Error(`App bundle not found: ${appBundle}`);
  }

  console.log(`3) Launching… → ${appBundle}`);
  const child = spawn("open", [appBundle], {
    cwd: root,
    stdio: "inherit",
  });
  child.on("exit", (code) => {
    if (code !== 0) console.error(`open exited with code ${code}`);
  });

  console.log("\nOpenator is running in the menu bar (top-right).");
  console.log(
    "If prompted, allow Openator to be set as your default browser.\n"
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
