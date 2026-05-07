"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline/promises");
const { stdin, stdout } = require("process");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const legacyRoot = path.join(repoRoot, "step-templates");
const legacyLogosRoot = path.join(legacyRoot, "logos");
const sourceRoot = path.join(repoRoot, "src", "step-templates");
const backupRoot = path.join(repoRoot, "step-templates-orig");
const gitignorePath = path.join(repoRoot, ".gitignore");
const legacyAllowlistStart = "# BEGIN source-first legacy template allowlist";
const legacyAllowlistEnd = "# END source-first legacy template allowlist";

function normalizeTemplateName(value) {
  return value.trim().replace(/\.json$/i, "");
}

function parseSelectedTemplateNames(argv) {
  const selectedTemplateNames = [];
  const templatePrefixes = [];
  const positionalTemplateNames = [];

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index].trim();
    if (!value) {
      continue;
    }

    if (value === "--template") {
      const nextValue = argv[index + 1];
      if (!nextValue || nextValue.startsWith("--")) {
        throw new Error("Missing value for --template");
      }

      selectedTemplateNames.push(normalizeTemplateName(nextValue));
      index += 1;
      continue;
    }

    if (value === "--template-prefix") {
      const nextValue = argv[index + 1];
      if (!nextValue || nextValue.startsWith("--")) {
        throw new Error("Missing value for --template-prefix");
      }

      templatePrefixes.push(nextValue.trim());
      index += 1;
      continue;
    }

    positionalTemplateNames.push(normalizeTemplateName(value));
  }

  const allTemplateNames = listMigratedTemplateNames();
  const prefixMatchedTemplateNames = templatePrefixes.flatMap((prefix) => allTemplateNames.filter((templateName) => templateName.startsWith(prefix)));
  const resolvedTemplateNames = [...selectedTemplateNames, ...positionalTemplateNames, ...prefixMatchedTemplateNames]
    .filter(Boolean)
    .filter((value, index, values) => values.indexOf(value) === index)
    .sort();

  if (resolvedTemplateNames.length === 0) {
    throw new Error(
      "Specify one or more templates with --template <name>, --template-prefix <prefix>, or positional template names. Example: node tools/migrate-source-first-reset.js --template Jenkins-Queue-Job --template-prefix github-"
    );
  }

  return resolvedTemplateNames;
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

function pathExists(targetPath) {
  return fs.existsSync(targetPath);
}

function removePath(targetPath) {
  if (pathExists(targetPath)) {
    fs.rmSync(targetPath, { recursive: true, force: true });
  }
}

function getRelativePath(absolutePath) {
  return path.relative(repoRoot, absolutePath);
}

function getLegacyTemplateJsonPath(templateName) {
  return path.join(legacyRoot, `${templateName}.json`);
}

function getSourceTemplateDirectory(templateName) {
  return path.join(sourceRoot, templateName);
}

function getSourceMetadataPath(templateName) {
  return path.join(getSourceTemplateDirectory(templateName), "metadata.json");
}

function getSourceTemplateLogoPath(templateName) {
  return path.join(getSourceTemplateDirectory(templateName), "logo.png");
}

function ensureDirectory(directoryPath) {
  fs.mkdirSync(directoryPath, { recursive: true });
}

function isTrackedAtHead(targetPath) {
  return captureGit(["ls-tree", "--name-only", "HEAD", targetPath]).length > 0;
}

function listTemplateJsonFiles(rootPath) {
  if (!pathExists(rootPath)) {
    return [];
  }

  return fs
    .readdirSync(rootPath)
    .filter((entry) => entry.endsWith(".json"))
    .sort();
}

function listLegacyTemplateNames() {
  return listTemplateJsonFiles(legacyRoot).map((fileName) => fileName.replace(/\.json$/i, ""));
}

function listMigratedTemplateNames() {
  if (!pathExists(sourceRoot)) {
    return [];
  }

  return fs
    .readdirSync(sourceRoot)
    .filter((entry) => !["logos", "tests"].includes(entry))
    .filter((entry) => pathExists(path.join(sourceRoot, entry, "metadata.json")))
    .sort();
}

function readJson(jsonPath) {
  return JSON.parse(fs.readFileSync(jsonPath, "utf8"));
}

function getTemplateCategoryId(template) {
  return ((template.Category || "other") + "").toLowerCase();
}

function getTemplateCategoryIdForMigratedTemplate(templateName) {
  const metadataPath = getSourceMetadataPath(templateName);
  return pathExists(metadataPath) ? getTemplateCategoryId(readJson(metadataPath)) : null;
}

function getTemplateCategoryIdForLegacyTemplate(templateName) {
  const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
  return pathExists(legacyJsonPath) ? getTemplateCategoryId(readJson(legacyJsonPath)) : null;
}

function listMigratedTemplatesUsingCategory(categoryId) {
  return listMigratedTemplateNames().filter((templateName) => getTemplateCategoryIdForMigratedTemplate(templateName) === categoryId);
}

function listLegacyTemplatesUsingCategory(categoryId) {
  return listLegacyTemplateNames().filter((templateName) => !pathExists(getSourceMetadataPath(templateName)) && getTemplateCategoryIdForLegacyTemplate(templateName) === categoryId);
}

function getLogoPath(rootPath, categoryId) {
  return path.join(rootPath, `${categoryId}.png`);
}

function reconcileCategoryLogo(categoryId) {
  const legacyLogoPath = getLogoPath(legacyLogosRoot, categoryId);
  const migratedUsers = listMigratedTemplatesUsingCategory(categoryId);
  const legacyUsers = listLegacyTemplatesUsingCategory(categoryId);
  const totalUsers = Array.from(new Set([...migratedUsers, ...legacyUsers]));
  const legacyExists = pathExists(legacyLogoPath);
  const sourceLogoPaths = migratedUsers.map(getSourceTemplateLogoPath);
  const firstExistingSourceLogoPath = sourceLogoPaths.find((logoPath) => pathExists(logoPath));
  const seedLogoPath = legacyExists ? legacyLogoPath : firstExistingSourceLogoPath;

  if (totalUsers.length === 0 || !seedLogoPath) {
    return;
  }

  if (totalUsers.length === 1 && migratedUsers.length === 1 && legacyUsers.length === 0 && legacyExists) {
    const targetLogoPath = getSourceTemplateLogoPath(migratedUsers[0]);
    ensureDirectory(getSourceTemplateDirectory(migratedUsers[0]));
    runGit(["mv", getRelativePath(legacyLogoPath), getRelativePath(targetLogoPath)]);
    return;
  }

  for (const templateName of migratedUsers) {
    const templateLogoPath = getSourceTemplateLogoPath(templateName);
    if (pathExists(templateLogoPath)) {
      continue;
    }

    ensureDirectory(getSourceTemplateDirectory(templateName));
    fs.copyFileSync(seedLogoPath, templateLogoPath);
  }

  if (legacyUsers.length === 0 && legacyExists) {
    if (!(totalUsers.length === 1 && migratedUsers.length === 1)) {
      fs.rmSync(legacyLogoPath, { force: true });
    }
    return;
  }

  if (legacyUsers.length > 0 && !legacyExists) {
    ensureDirectory(legacyLogosRoot);
    fs.copyFileSync(seedLogoPath, legacyLogoPath);
  }
}

function syncLegacyTemplateAllowlist() {
  const allLegacyTemplateNames = listLegacyTemplateNames().filter((templateName) => !pathExists(getSourceMetadataPath(templateName)));
  const sectionLines = [legacyAllowlistStart, "/step-templates/*.json", ...allLegacyTemplateNames.map((templateName) => `!/step-templates/${templateName}.json`), legacyAllowlistEnd];
  const currentContent = fs.readFileSync(gitignorePath, "utf8");
  const startIndex = currentContent.indexOf(legacyAllowlistStart);
  const endIndex = currentContent.indexOf(legacyAllowlistEnd);
  const sectionText = `${sectionLines.join("\n")}\n`;
  let updatedContent;

  if (startIndex >= 0 && endIndex >= startIndex) {
    const sectionEnd = endIndex + legacyAllowlistEnd.length;
    updatedContent = `${currentContent.slice(0, startIndex)}${sectionText}${currentContent.slice(sectionEnd).replace(/^\n*/, "")}`;
  } else {
    updatedContent = `${currentContent.replace(/\s*$/, "\n\n")}${sectionText}`;
  }

  fs.writeFileSync(gitignorePath, updatedContent);
}

async function confirmReset(rl, selectedTemplateNames) {
  const answer = (await rl.question(`Reset these templates back to branch HEAD? (${selectedTemplateNames.join(", ")}) [y/N] `)).trim().toLowerCase();
  return answer === "y" || answer === "yes";
}

function restoreTemplateState(templateName) {
  const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
  const sourceTemplateDirectory = getSourceTemplateDirectory(templateName);
  const sourceMetadataPath = getSourceMetadataPath(templateName);

  if (isTrackedAtHead(getRelativePath(legacyJsonPath))) {
    runGit(["restore", "--source=HEAD", "--staged", "--worktree", getRelativePath(legacyJsonPath)]);
  }

  if (isTrackedAtHead(getRelativePath(sourceTemplateDirectory))) {
    runGit(["restore", "--source=HEAD", "--staged", "--worktree", getRelativePath(sourceTemplateDirectory)]);
  } else {
    runGit(["rm", "-r", "-f", "--cached", "--ignore-unmatch", getRelativePath(sourceTemplateDirectory)]);
    removePath(sourceTemplateDirectory);
  }

  if (!pathExists(sourceMetadataPath)) {
    removePath(sourceTemplateDirectory);
  }
}

async function main() {
  const selectedTemplateNames = parseSelectedTemplateNames(process.argv.slice(2));
  const rl = readline.createInterface({ input: stdin, output: stdout });

  try {
    console.log("Source-first migration reset");
    console.log(`Repo root: ${repoRoot}`);
    console.log(`Templates: ${selectedTemplateNames.join(", ")}`);
    console.log("This will:");
    console.log("- restore the selected templates to current branch HEAD");
    console.log("- refresh the legacy-template allowlist in .gitignore");
    console.log("- reconcile any logo state affected by the selected templates");
    console.log("- remove step-templates-orig/");

    const confirmed = await confirmReset(rl, selectedTemplateNames);
    if (!confirmed) {
      console.log("Aborted.");
      return;
    }

    const affectedCategoryIds = new Set();
    for (const templateName of selectedTemplateNames) {
      const metadataPath = getSourceMetadataPath(templateName);
      const legacyJsonPath = getLegacyTemplateJsonPath(templateName);

      if (pathExists(metadataPath)) {
        affectedCategoryIds.add(getTemplateCategoryId(readJson(metadataPath)));
      } else if (pathExists(legacyJsonPath)) {
        affectedCategoryIds.add(getTemplateCategoryId(readJson(legacyJsonPath)));
      }
    }

    for (const templateName of selectedTemplateNames) {
      restoreTemplateState(templateName);
    }

    for (const categoryId of affectedCategoryIds) {
      reconcileCategoryLogo(categoryId);
    }

    syncLegacyTemplateAllowlist();
    removePath(backupRoot);

    console.log("Reset complete.");
    console.log("- restored selected templates to branch HEAD");
    console.log("- refreshed .gitignore allowlist");
    console.log("- reconciled affected logos");
    console.log("- removed step-templates-orig/");
  } finally {
    rl.close();
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
