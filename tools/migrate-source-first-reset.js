"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline/promises");
const { stdin, stdout } = require("process");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const legacyRoot = path.join(repoRoot, "step-templates");
const sourceRoot = path.join(repoRoot, "src", "step-templates");
const backupRoot = path.join(repoRoot, "step-templates-orig");

function pathExists(targetPath) {
  return fs.existsSync(targetPath);
}

function removePath(targetPath) {
  if (pathExists(targetPath)) {
    fs.rmSync(targetPath, { recursive: true, force: true });
  }
}

function runGit(args) {
  execFileSync("git", args, {
    cwd: repoRoot,
    stdio: "inherit",
  });
}

function captureGit(args) {
  return execFileSync("git", args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  }).trim();
}

function isTrackedAtHead(targetPath) {
  return captureGit(["ls-tree", "--name-only", "HEAD", targetPath]).length > 0;
}

async function confirmReset(rl) {
  const answer = (await rl.question("Reset this migration run back to branch HEAD? [y/N] ")).trim().toLowerCase();
  return answer === "y" || answer === "yes";
}

async function main() {
  const rl = readline.createInterface({ input: stdin, output: stdout });

  try {
    console.log("Source-first migration reset");
    console.log(`Repo root: ${repoRoot}`);
    console.log("This will:");
    console.log("- restore tracked step-templates and src/step-templates to current branch HEAD");
    console.log("- remove step-templates-orig/");
    console.log("- remove any untracked src/step-templates/ leftovers");

    const confirmed = await confirmReset(rl);
    if (!confirmed) {
      console.log("Aborted.");
      return;
    }

    const restorePaths = ["step-templates"];
    const sourceTrackedAtHead = isTrackedAtHead("src/step-templates");
    if (sourceTrackedAtHead) {
      restorePaths.push("src/step-templates");
    }

    runGit(["restore", "--source=HEAD", "--staged", "--worktree", ...restorePaths]);

    if (!sourceTrackedAtHead) {
      runGit(["rm", "-r", "-f", "--cached", "--ignore-unmatch", "src/step-templates"]);
    }

    removePath(backupRoot);

    if (pathExists(sourceRoot)) {
      const entries = fs.readdirSync(sourceRoot);
      if (entries.length === 0) {
        removePath(sourceRoot);
      }
    }

    if (pathExists(sourceRoot)) {
      removePath(sourceRoot);
    }

    if (!pathExists(legacyRoot)) {
      throw new Error("step-templates/ is missing after reset.");
    }

    console.log("Reset complete.");
    console.log("- restored tracked step-templates and src/step-templates to branch HEAD");
    console.log("- removed step-templates-orig/");
    console.log("- removed src/step-templates/ leftovers");
  } finally {
    rl.close();
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
