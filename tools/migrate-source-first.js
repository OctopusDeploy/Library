"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline/promises");
const { stdin, stdout } = require("process");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const legacyRoot = path.join(repoRoot, "step-templates");
const legacyLogosRoot = path.join(legacyRoot, "logos");
const backupRoot = path.join(repoRoot, "step-templates-orig");
const sourceRoot = path.join(repoRoot, "src", "step-templates");
const placeholderPrefix = "__SOURCE_FILE__:";
const gitignorePath = path.join(repoRoot, ".gitignore");
const legacyAllowlistStart = "# BEGIN source-first legacy template allowlist";
const legacyAllowlistEnd = "# END source-first legacy template allowlist";
const ansiReset = "\u001b[0m";
const ansiBold = "\u001b[1m";
const ansiDim = "\u001b[2m";
const ansiGreen = "\u001b[32m";
const ansiRed = "\u001b[31m";
const ansiYellow = "\u001b[33m";
const ansiBlue = "\u001b[34m";
const ansiCyan = "\u001b[36m";

const scriptDefinitions = [
  {
    sourceBaseName: "scriptbody",
    legacyBaseName: "ScriptBody",
    propertyName: "Octopus.Action.Script.ScriptBody",
    getExtension(template) {
      const syntax = (((template || {}).Properties || {})["Octopus.Action.Script.Syntax"] || "PowerShell").toLowerCase();
      if (syntax === "bash") {
        return ".sh";
      }

      if (syntax === "python") {
        return ".py";
      }

      return ".ps1";
    },
    shouldExtract(template) {
      const properties = (template || {}).Properties || {};
      const scriptSource = properties["Octopus.Action.Script.ScriptSource"] || "Inline";
      return scriptSource === "Inline" && typeof properties[this.propertyName] === "string" && properties[this.propertyName].length > 0;
    },
  },
  {
    sourceBaseName: "predeploy",
    legacyBaseName: "PreDeploy",
    propertyName: "Octopus.Action.CustomScripts.PreDeploy.ps1",
    getExtension() {
      return ".ps1";
    },
    shouldExtract(template) {
      const value = (((template || {}).Properties || {})[this.propertyName] || "");
      return typeof value === "string" && value.length > 0;
    },
  },
  {
    sourceBaseName: "deploy",
    legacyBaseName: "Deploy",
    propertyName: "Octopus.Action.CustomScripts.Deploy.ps1",
    getExtension() {
      return ".ps1";
    },
    shouldExtract(template) {
      const value = (((template || {}).Properties || {})[this.propertyName] || "");
      return typeof value === "string" && value.length > 0;
    },
  },
  {
    sourceBaseName: "postdeploy",
    legacyBaseName: "PostDeploy",
    propertyName: "Octopus.Action.CustomScripts.PostDeploy.ps1",
    getExtension() {
      return ".ps1";
    },
    shouldExtract(template) {
      const value = (((template || {}).Properties || {})[this.propertyName] || "");
      return typeof value === "string" && value.length > 0;
    },
  },
];

const excludedValidationFields = new Set(["ExportedAt", "LastModifiedOn", "LastModifiedAt", "LastModfiedAt"]);

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

  const allTemplateNames = listLegacyTemplateNames();
  const prefixMatchedTemplateNames = templatePrefixes.flatMap((prefix) => allTemplateNames.filter((templateName) => templateName.startsWith(prefix)));
  const resolvedTemplateNames = [...selectedTemplateNames, ...positionalTemplateNames, ...prefixMatchedTemplateNames]
    .filter(Boolean)
    .filter((value, index, values) => values.indexOf(value) === index)
    .sort();

  if (resolvedTemplateNames.length === 0) {
    throw new Error(
      "Specify one or more templates with --template <name>, --template-prefix <prefix>, or positional template names. Example: node tools/migrate-source-first.js --template Jenkins-Queue-Job --template-prefix github-"
    );
  }

  return resolvedTemplateNames;
}

function listTemplateJsonFiles(rootPath) {
  if (!fs.existsSync(rootPath)) {
    return [];
  }

  return fs
    .readdirSync(rootPath)
    .filter((entry) => entry.endsWith(".json"))
    .sort();
}

function listLegacyTemplateNames() {
  return listTemplateJsonFiles(legacyRoot).map(getTemplateNameFromFileName);
}

function listMigratedTemplateNames() {
  if (!fs.existsSync(sourceRoot)) {
    return [];
  }

  return fs
    .readdirSync(sourceRoot)
    .filter((entry) => !["logos", "tests"].includes(entry))
    .filter((entry) => fs.existsSync(path.join(sourceRoot, entry, "metadata.json")))
    .sort();
}

function runGit(args) {
  execFileSync("git", args, {
    cwd: repoRoot,
    stdio: "inherit",
  });
}

function colorize(color, text) {
  return `${color}${text}${ansiReset}`;
}

function log(message, type = "info") {
  if (type === "blank") {
    console.log("");
    return;
  }

  if (type === "banner") {
    console.log(colorize(ansiBold + ansiBlue, message));
    return;
  }

  if (type === "error") {
    console.log(colorize(ansiBold + ansiRed, message));
    return;
  }

  if (type === "step") {
    console.log("");
    console.log(colorize(ansiBold + ansiBlue, message));
    return;
  }

  if (type === "note") {
    console.log(colorize(ansiYellow, `NOTE ${message}`));
    return;
  }

  if (type === "success") {
    console.log(`${colorize(ansiGreen, "DONE")} ${message}`);
    return;
  }

  if (type === "action") {
    console.log(`${colorize(ansiCyan, "ACTION")} ${message}`);
    return;
  }

  if (type === "pass") {
    console.log(`${ansiGreen}PASS${ansiReset} ${message}`);
    return;
  }

  if (type === "fail") {
    console.log(`${ansiRed}FAIL${ansiReset} ${message}`);
    return;
  }

  console.log(message);
}

function normalizeForComparison(value) {
  if (Array.isArray(value)) {
    return value.map(normalizeForComparison);
  }

  if (value && typeof value === "object") {
    const result = {};
    for (const [key, childValue] of Object.entries(value)) {
      if (excludedValidationFields.has(key)) {
        continue;
      }

      result[key] = normalizeForComparison(childValue);
    }

    return result;
  }

  return value;
}

function diffObjects(left, right, currentPath = "$") {
  if (typeof left !== typeof right) {
    return [`${currentPath}: type mismatch (${typeof left} !== ${typeof right})`];
  }

  if (Array.isArray(left) && Array.isArray(right)) {
    if (left.length !== right.length) {
      return [`${currentPath}: array length mismatch (${left.length} !== ${right.length})`];
    }

    for (let index = 0; index < left.length; index += 1) {
      const nested = diffObjects(left[index], right[index], `${currentPath}[${index}]`);
      if (nested.length > 0) {
        return nested;
      }
    }

    return [];
  }

  if (left && typeof left === "object" && right && typeof right === "object") {
    const leftKeys = Object.keys(left).sort();
    const rightKeys = Object.keys(right).sort();

    if (leftKeys.join("|") !== rightKeys.join("|")) {
      return [`${currentPath}: key mismatch (${leftKeys.join(", ")} !== ${rightKeys.join(", ")})`];
    }

    for (const key of leftKeys) {
      const nested = diffObjects(left[key], right[key], `${currentPath}.${key}`);
      if (nested.length > 0) {
        return nested;
      }
    }

    return [];
  }

  if (left !== right) {
    return [`${currentPath}: value mismatch (${JSON.stringify(left)} !== ${JSON.stringify(right)})`];
  }

  return [];
}

async function confirmStep(rl, prompt) {
  const answer = (await rl.question(`${prompt} [y/N] `)).trim().toLowerCase();
  if (answer !== "y" && answer !== "yes") {
    log("Aborted.");
    return false;
  }

  return true;
}

function getTemplateNameFromFileName(fileName) {
  return fileName.replace(/\.json$/i, "");
}

function getLegacyTemplateJsonPath(templateName) {
  return path.join(legacyRoot, `${templateName}.json`);
}

function getBackupTemplateJsonPath(templateName) {
  return path.join(backupRoot, `${templateName}.json`);
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

function getRelativePath(absolutePath) {
  return path.relative(repoRoot, absolutePath);
}

function ensureDirectory(directoryPath) {
  fs.mkdirSync(directoryPath, { recursive: true });
}

function readJson(jsonPath) {
  return JSON.parse(fs.readFileSync(jsonPath, "utf8"));
}

function getTemplateCategoryId(template) {
  return ((template.Category || "other") + "").toLowerCase();
}

function getTemplateCategoryIdForMigratedTemplate(templateName) {
  const metadataPath = getSourceMetadataPath(templateName);
  if (!fs.existsSync(metadataPath)) {
    return null;
  }

  return getTemplateCategoryId(readJson(metadataPath));
}

function getTemplateCategoryIdForLegacyTemplate(templateName) {
  const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
  if (!fs.existsSync(legacyJsonPath)) {
    return null;
  }

  return getTemplateCategoryId(readJson(legacyJsonPath));
}

function listMigratedTemplatesUsingCategory(categoryId) {
  return listMigratedTemplateNames().filter((templateName) => getTemplateCategoryIdForMigratedTemplate(templateName) === categoryId);
}

function listLegacyTemplatesUsingCategory(categoryId) {
  return listLegacyTemplateNames().filter((templateName) => !fs.existsSync(getSourceMetadataPath(templateName)) && getTemplateCategoryIdForLegacyTemplate(templateName) === categoryId);
}

function getLogoPath(rootPath, categoryId) {
  return path.join(rootPath, `${categoryId}.png`);
}

function reconcileCategoryLogo(categoryId) {
  const legacyLogoPath = getLogoPath(legacyLogosRoot, categoryId);
  const migratedUsers = listMigratedTemplatesUsingCategory(categoryId);
  const legacyUsers = listLegacyTemplatesUsingCategory(categoryId);
  const totalUsers = Array.from(new Set([...migratedUsers, ...legacyUsers]));
  const legacyExists = fs.existsSync(legacyLogoPath);
  const sourceLogoPaths = migratedUsers.map(getSourceTemplateLogoPath);
  const firstExistingSourceLogoPath = sourceLogoPaths.find((logoPath) => fs.existsSync(logoPath));
  const seedLogoPath = legacyExists ? legacyLogoPath : firstExistingSourceLogoPath;

  if (totalUsers.length === 0 || !seedLogoPath) {
    return;
  }

  if (totalUsers.length === 1 && migratedUsers.length === 1 && legacyUsers.length === 0 && legacyExists) {
    const targetLogoPath = getSourceTemplateLogoPath(migratedUsers[0]);
    ensureDirectory(getSourceTemplateDirectory(migratedUsers[0]));
    log(`MOVE ${getRelativePath(legacyLogoPath)} -> ${getRelativePath(targetLogoPath)} ${colorize(ansiDim, "(preserve history)")}`, "action");
    runGit(["mv", getRelativePath(legacyLogoPath), getRelativePath(targetLogoPath)]);
    return;
  }

  for (const templateName of migratedUsers) {
    const templateLogoPath = getSourceTemplateLogoPath(templateName);
    if (fs.existsSync(templateLogoPath)) {
      continue;
    }

    ensureDirectory(getSourceTemplateDirectory(templateName));
    fs.copyFileSync(seedLogoPath, templateLogoPath);
    log(`COPY ${getRelativePath(seedLogoPath)} -> ${getRelativePath(templateLogoPath)} ${colorize(ansiDim, "(template logo)")}`, "action");
  }

  if (legacyUsers.length === 0 && legacyExists) {
    if (!(totalUsers.length === 1 && migratedUsers.length === 1)) {
      fs.rmSync(legacyLogoPath, { force: true });
      log(`REMOVE ${getRelativePath(legacyLogoPath)} ${colorize(ansiDim, "(last legacy user migrated)")}`, "action");
    }
    return;
  }

  if (legacyUsers.length > 0 && !legacyExists) {
    ensureDirectory(legacyLogosRoot);
    fs.copyFileSync(seedLogoPath, legacyLogoPath);
    log(`COPY ${getRelativePath(seedLogoPath)} -> ${getRelativePath(legacyLogoPath)} ${colorize(ansiDim, "(restore legacy logo)")}`, "action");
  }
}

function syncLegacyTemplateAllowlist() {
  const allLegacyTemplateNames = listLegacyTemplateNames().filter((templateName) => !fs.existsSync(getSourceMetadataPath(templateName)));
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
  log(`Updated .gitignore legacy template allowlist (${allLegacyTemplateNames.length} remaining legacy templates)`, "success");
}

function ensureSelectedTemplatesCanMigrate(selectedTemplateNames) {
  for (const templateName of selectedTemplateNames) {
    const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
    if (!fs.existsSync(legacyJsonPath)) {
      throw new Error(`Legacy template JSON is missing: ${getRelativePath(legacyJsonPath)}`);
    }

    if (fs.existsSync(getSourceMetadataPath(templateName))) {
      throw new Error(`Template is already migrated: ${templateName}`);
    }
  }
}

async function step1_DupeStepTemplateJsonFilesForValidationBaseline(rl, selectedTemplateNames) {
  log("Step 1: Prepare validation baseline", "step");
  log("This creates a frozen pre-migration copy of the selected step-template JSON files.");
  log("The copied files are written to step-templates-orig/ at the repo root.");
  log("The copy is unpacked so we can later compare rebuilt source-first output to the original selected template state.");
  log(`Selected templates: ${selectedTemplateNames.join(", ")}`);

  if (fs.existsSync(backupRoot)) {
    log("step-templates-orig/ already exists and will be replaced.", "note");
  }

  if (!(await confirmStep(rl, "Prepare the validation baseline?"))) {
    return false;
  }

  syncLegacyTemplateAllowlist();

  fs.rmSync(backupRoot, { recursive: true, force: true });
  fs.mkdirSync(backupRoot, { recursive: true });

  for (const templateName of selectedTemplateNames) {
    const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
    const backupJsonPath = getBackupTemplateJsonPath(templateName);
    const template = readJson(legacyJsonPath);
    const unpackedSidecars = [];

    fs.copyFileSync(legacyJsonPath, backupJsonPath);

    for (const definition of scriptDefinitions) {
      if (!definition.shouldExtract(template)) {
        continue;
      }

      const extension = definition.getExtension(template);
      const sidecarPath = path.join(backupRoot, `${templateName}.${definition.legacyBaseName}${extension}`);
      const value = template.Properties[definition.propertyName];
      fs.writeFileSync(sidecarPath, value, "utf8");
      unpackedSidecars.push(path.basename(sidecarPath));
    }

    if (unpackedSidecars.length > 0) {
      log(`UNPACK ${templateName}.json -> ${unpackedSidecars.join(", ")}`, "action");
    } else {
      log(`UNPACK ${templateName}.json -> ${colorize(ansiDim, "no sidecars")}`, "action");
    }
  }

  log("Created step-templates-orig/ for selected templates", "success");
  log("Unpacked reference sidecars for selected templates", "success");
  return true;
}

async function step2_GitMoveStepTemplateJsonFilesToSrcAsMetadataJsonFiles(rl, selectedTemplateNames) {
  log("Step 2: Move JSON templates into the source tree with history", "step");
  log("Each selected step-template JSON file is moved with git history into src/step-templates/<template>/metadata.json.");
  log("metadata.json is the file that retains the existing JSON history after the split.");
  log("Logo files are migrated incrementally based on whether legacy templates still depend on them.");

  if (!(await confirmStep(rl, "Move the selected templates into the new source tree?"))) {
    return false;
  }

  ensureDirectory(sourceRoot);

  const affectedCategoryIds = new Set();

  for (const templateName of selectedTemplateNames) {
    const legacyJsonPath = getLegacyTemplateJsonPath(templateName);
    const categoryId = getTemplateCategoryId(readJson(legacyJsonPath));
    const targetDirectory = getSourceTemplateDirectory(templateName);
    const targetMetadataPath = getSourceMetadataPath(templateName);

    if (fs.existsSync(targetDirectory)) {
      throw new Error(`Target directory already exists: ${getRelativePath(targetDirectory)}`);
    }

    fs.mkdirSync(targetDirectory, { recursive: true });
    log(`MOVE ${getRelativePath(legacyJsonPath)} -> ${getRelativePath(targetMetadataPath)} ${colorize(ansiDim, "(preserve history)")}`, "action");
    runGit(["mv", getRelativePath(legacyJsonPath), getRelativePath(targetMetadataPath)]);
    affectedCategoryIds.add(categoryId);
  }

  for (const categoryId of affectedCategoryIds) {
    reconcileCategoryLogo(categoryId);
  }

  syncLegacyTemplateAllowlist();
  log("Moved selected template JSON files into src/step-templates/.../metadata.json", "success");
  return true;
}

async function step3_SplitSrcMetadataJsonFilesIntoConstituentFiles(rl, selectedTemplateNames) {
  log("Step 3: Split source templates into constituent files", "step");
  log("Inline script content is extracted from metadata.json into dedicated source files beside each selected template.");
  log("Octopus.Action.Script.ScriptBody becomes scriptbody.ps1, scriptbody.sh, or scriptbody.py based on script syntax.");
  log("metadata.json stays as the history-carrying file, and placeholders are written so the existing pack tooling can rebuild the legacy JSON.");

  if (!(await confirmStep(rl, "Split inline script content into source sidecar files?"))) {
    return false;
  }

  for (const templateName of selectedTemplateNames) {
    const metadataPath = getSourceMetadataPath(templateName);
    const template = readJson(metadataPath);
    template.Properties = template.Properties || {};
    const extractedSidecars = [];

    for (const definition of scriptDefinitions) {
      if (!definition.shouldExtract(template)) {
        continue;
      }

      const extension = definition.getExtension(template);
      const sourceSidecarPath = path.join(getSourceTemplateDirectory(templateName), `${definition.sourceBaseName}${extension}`);
      const value = template.Properties[definition.propertyName];

      fs.writeFileSync(sourceSidecarPath, value, "utf8");
      template.Properties[definition.propertyName] = `${placeholderPrefix}${path.basename(sourceSidecarPath)}`;
      extractedSidecars.push(path.basename(sourceSidecarPath));
    }

    fs.writeFileSync(metadataPath, `${JSON.stringify(template, null, 2)}\n`);

    if (extractedSidecars.length > 0) {
      log(`EXTRACT ${templateName}.json -> ${extractedSidecars.join(", ")}`, "action");
    } else {
      log(`EXTRACT ${templateName}.json -> ${colorize(ansiDim, "no sidecars")}`, "action");
    }
  }

  log("Extracted source sidecars and replaced metadata placeholders for selected templates", "success");
  return true;
}

function ensureBuildDependencies(rl) {
  return (async () => {
    const gulpExecutable = process.platform === "win32" ? path.join(repoRoot, "node_modules", ".bin", "gulp.cmd") : path.join(repoRoot, "node_modules", ".bin", "gulp");

    if (fs.existsSync(gulpExecutable)) {
      return gulpExecutable;
    }

    log("Build dependencies are missing. Step 4 needs the existing gulp-based toolchain to rebuild step-template JSON files.", "note");

    if (!(await confirmStep(rl, "Run npm ci to install the required build dependencies?"))) {
      return null;
    }

    log("Running npm ci", "action");

    try {
      execFileSync("npm", ["ci"], {
        cwd: repoRoot,
        stdio: "inherit",
      });
    } catch (error) {
      log("npm ci failed. This repository may require npm install because package-lock.json is not in sync with the current npm client.", "note");

      if (!(await confirmStep(rl, "Run npm install instead?"))) {
        throw new Error("Dependency installation failed while running npm ci.");
      }

      log("Running npm install", "action");

      try {
        execFileSync("npm", ["install"], {
          cwd: repoRoot,
          stdio: "inherit",
        });
      } catch (installError) {
        throw new Error("Dependency installation failed while running npm install.");
      }
    }

    if (!fs.existsSync(gulpExecutable)) {
      throw new Error("Dependency installation completed, but the gulp executable is still missing.");
    }

    return gulpExecutable;
  })();
}

async function step4_BuildStepTemplateJsonFilesFromSrcAndValidateAgainstBaseline(rl, selectedTemplateNames) {
  log("Step 4: Rebuild and validate generated JSON output", "step");
  log("This rebuilds step-templates/*.json from src/step-templates/ using the existing pack tooling.");
  log("The rebuilt JSON is then compared to the frozen baseline in step-templates-orig/.");
  log(`Only the selected templates are validated in this run: ${selectedTemplateNames.join(", ")}`);

  if (!(await confirmStep(rl, "Rebuild the packed JSON and validate it against the baseline?"))) {
    return false;
  }

  const gulpExecutable = await ensureBuildDependencies(rl);
  if (!gulpExecutable) {
    return false;
  }

  execFileSync(gulpExecutable, ["step-templates"], {
    cwd: repoRoot,
    env: {
      ...process.env,
      SOURCE_FIRST_TEMPLATE_FILTER: selectedTemplateNames.join(","),
    },
    stdio: "inherit",
  });

  log("", "blank");
  log("Regenerated packed step-templates/*.json from src/step-templates", "success");

  const mismatches = [];

  log(
    `Validation excludes regenerated metadata fields: ${Array.from(excludedValidationFields)
      .map((fieldName) => `'${fieldName}'`)
      .join(", ")}`,
    "note"
  );

  for (const templateName of selectedTemplateNames) {
    const originalJsonPath = getBackupTemplateJsonPath(templateName);
    const generatedJsonPath = getLegacyTemplateJsonPath(templateName);

    if (!fs.existsSync(generatedJsonPath)) {
      mismatches.push(`${templateName}.json: regenerated file is missing`);
      continue;
    }

    const original = normalizeForComparison(readJson(originalJsonPath));
    const generated = normalizeForComparison(readJson(generatedJsonPath));
    const diff = diffObjects(original, generated);

    if (diff.length > 0) {
      mismatches.push(`${templateName}.json: ${diff[0]}`);
      continue;
    }

    log(`${templateName}.json`, "pass");
  }

  if (mismatches.length > 0) {
    log("", "blank");
    log("Validation mismatches:", "error");
    for (const mismatch of mismatches) {
      log(mismatch, "fail");
    }

    throw new Error(`Validation failed for ${mismatches.length} template(s).`);
  }

  syncLegacyTemplateAllowlist();
  log("Validated regenerated step-templates/*.json against step-templates-orig/ for selected templates", "success");
  log("Rebuilt and validated selected step-templates/*.json against step-templates-orig/", "success");
  return true;
}

async function main() {
  const selectedTemplateNames = parseSelectedTemplateNames(process.argv.slice(2));
  const rl = readline.createInterface({ input: stdin, output: stdout });

  try {
    log("Source-first migration", "banner");
    log(colorize(ansiDim, `Repo root: ${repoRoot}`));
    log(colorize(ansiDim, "This script does not commit anything."));
    log(colorize(ansiDim, `Templates: ${selectedTemplateNames.join(", ")}`));

    ensureSelectedTemplatesCanMigrate(selectedTemplateNames);

    if (!(await step1_DupeStepTemplateJsonFilesForValidationBaseline(rl, selectedTemplateNames))) {
      return;
    }

    if (!(await step2_GitMoveStepTemplateJsonFilesToSrcAsMetadataJsonFiles(rl, selectedTemplateNames))) {
      return;
    }

    if (!(await step3_SplitSrcMetadataJsonFilesIntoConstituentFiles(rl, selectedTemplateNames))) {
      return;
    }

    if (!(await step4_BuildStepTemplateJsonFilesFromSrcAndValidateAgainstBaseline(rl, selectedTemplateNames))) {
      return;
    }
  } finally {
    rl.close();
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
