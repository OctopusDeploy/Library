"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline/promises");
const { stdin, stdout } = require("process");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const legacyRoot = path.join(repoRoot, "step-templates");
const backupRoot = path.join(repoRoot, "step-templates-orig");
const sourceRoot = path.join(repoRoot, "src", "step-templates");
const placeholderPrefix = "__SOURCE_FILE__:";
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

function listTemplateJsonFiles(rootPath) {
  return fs
    .readdirSync(rootPath)
    .filter((entry) => entry.endsWith(".json"))
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

async function step1_PrepareValidationBaseline(rl) {
  log("Step 1: Prepare validation baseline", "step");
  log("This creates a frozen pre-migration copy of the current step-template JSON files.");
  log("The copied files are written to step-templates-orig/ at the repo root.");
  log("The copy is unpacked so we can later compare the rebuilt source-first output to the original repo state.");
  log("step-templates-orig/ is git-ignored so these temporary baseline files cannot be accidentally committed.");

  if (fs.existsSync(backupRoot)) {
    log("step-templates-orig/ already exists and will be replaced.", "note");
  }

  if (!(await confirmStep(rl, "Prepare the validation baseline?"))) {
    return false;
  }

  if (fs.existsSync(backupRoot)) {
    fs.rmSync(backupRoot, { recursive: true, force: true });
  }

  fs.cpSync(legacyRoot, backupRoot, { recursive: true });

  for (const fileName of listTemplateJsonFiles(backupRoot)) {
    const templateName = fileName.replace(/\.json$/i, "");
    const template = JSON.parse(fs.readFileSync(path.join(backupRoot, fileName), "utf8"));
    const unpackedSidecars = [];

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
      log(`UNPACK ${fileName} -> ${unpackedSidecars.join(", ")}`, "action");
      continue;
    }

    log(`UNPACK ${fileName} -> ${colorize(ansiDim, "no sidecars")}`, "action");
  }

  log("Created step-templates-orig/", "success");
  log("Unpacked reference sidecars in step-templates-orig/", "success");
  return true;
}

async function step2_MoveJsonTemplatesIntoSourceTree(rl) {
  log("Step 2: Move JSON templates into the source tree with history", "step");
  log("Each step-template JSON file is moved with git history into src/step-templates/<template>/metadata.json.");
  log("We are choosing metadata.json as the file that will retain the existing JSON history after the split.");
  log("Shared logos/ and tests/ assets also move into src/step-templates/.");

  if (!(await confirmStep(rl, "Move the existing templates into the new source tree?"))) {
    return false;
  }

  fs.mkdirSync(sourceRoot, { recursive: true });

  for (const fileName of listTemplateJsonFiles(legacyRoot)) {
    const templateName = fileName.replace(/\.json$/i, "");
    const targetDirectory = path.join(sourceRoot, templateName);

    if (fs.existsSync(targetDirectory)) {
      throw new Error(`Target directory already exists: ${path.relative(repoRoot, targetDirectory)}`);
    }
  }

  for (const sharedDirectoryName of ["logos", "tests"]) {
    const targetPath = path.join(sourceRoot, sharedDirectoryName);
    if (fs.existsSync(targetPath)) {
      throw new Error(`Target path already exists: ${path.relative(repoRoot, targetPath)}`);
    }
  }

  for (const fileName of listTemplateJsonFiles(legacyRoot)) {
    const templateName = fileName.replace(/\.json$/i, "");
    const sourceJsonPath = path.join("step-templates", fileName);
    const targetDirectory = path.join(sourceRoot, templateName);
    const targetMetadataPath = path.join(targetDirectory, "metadata.json");

    fs.mkdirSync(targetDirectory, { recursive: true });
    log(`MOVE ${sourceJsonPath} -> ${path.relative(repoRoot, targetMetadataPath)} ${colorize(ansiDim, "(preserve history)")}`, "action");
    runGit(["mv", sourceJsonPath, path.relative(repoRoot, targetMetadataPath)]);
  }

  for (const sharedDirectoryName of ["logos", "tests"]) {
    const sourcePath = path.join("step-templates", sharedDirectoryName);
    const targetPath = path.join("src", "step-templates", sharedDirectoryName);
    log(`MOVE ${sourcePath} -> ${targetPath} ${colorize(ansiDim, "(preserve history)")}`, "action");
    runGit(["mv", sourcePath, targetPath]);
  }

  log("Moved template JSON files into src/step-templates/.../metadata.json", "success");
  log("Moved step-templates/logos and step-templates/tests into src/step-templates/", "success");
  return true;
}

async function step3_SplitSourceTemplatesIntoConstituentFiles(rl) {
  log("Step 3: Split source templates into constituent files", "step");
  log("Inline script content is extracted from metadata.json into dedicated source files beside each template.");
  log("Octopus.Action.Script.ScriptBody becomes scriptbody.ps1, scriptbody.sh, or scriptbody.py based on script syntax.");
  log("Non-empty custom script fields become predeploy.ps1, deploy.ps1, and postdeploy.ps1 when those fields are present.");
  log("metadata.json stays as the history-carrying file, and placeholders are written so the existing pack tooling can rebuild the legacy JSON.");

  if (!(await confirmStep(rl, "Split inline script content into source sidecar files?"))) {
    return false;
  }

  for (const fileName of listTemplateJsonFiles(backupRoot)) {
    const templateName = fileName.replace(/\.json$/i, "");
    const metadataPath = path.join(sourceRoot, templateName, "metadata.json");
    const template = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
    template.Properties = template.Properties || {};
    const extractedSidecars = [];

    for (const definition of scriptDefinitions) {
      if (!definition.shouldExtract(template)) {
        continue;
      }

      const extension = definition.getExtension(template);
      const sourceSidecarPath = path.join(sourceRoot, templateName, `${definition.sourceBaseName}${extension}`);
      const value = template.Properties[definition.propertyName];

      fs.writeFileSync(sourceSidecarPath, value, "utf8");
      template.Properties[definition.propertyName] = `${placeholderPrefix}${path.basename(sourceSidecarPath)}`;
      extractedSidecars.push(path.basename(sourceSidecarPath));
    }

    fs.writeFileSync(metadataPath, `${JSON.stringify(template, null, 2)}\n`);

    if (extractedSidecars.length > 0) {
      log(`EXTRACT ${fileName} -> ${extractedSidecars.join(", ")}`, "action");
      continue;
    }

    log(`EXTRACT ${fileName} -> ${colorize(ansiDim, "no sidecars")}`, "action");
  }

  log("Extracted source sidecars and replaced metadata placeholders", "success");
  return true;
}

async function step4_RebuildAndValidateGeneratedJson(rl) {
  log("Step 4: Rebuild and validate generated JSON output", "step");
  log("This rebuilds step-templates/*.json from src/step-templates/ using the existing pack tooling.");
  log("The rebuilt JSON is then compared to the frozen baseline in step-templates-orig/.");
  log("A passing result shows the source-first tree can reproduce the original packed JSON apart from excluded regenerated metadata fields.");

  if (!(await confirmStep(rl, "Rebuild the packed JSON and validate it against the baseline?"))) {
    return false;
  }

  const gulpExecutable =
    process.platform === "win32" ? path.join(repoRoot, "node_modules", ".bin", "gulp.cmd") : path.join(repoRoot, "node_modules", ".bin", "gulp");

  execFileSync(gulpExecutable, ["step-templates"], {
    cwd: repoRoot,
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

  for (const fileName of listTemplateJsonFiles(backupRoot)) {
    const originalJsonPath = path.join(backupRoot, fileName);
    const generatedJsonPath = path.join(legacyRoot, fileName);

    if (!fs.existsSync(generatedJsonPath)) {
      mismatches.push(`${fileName}: regenerated file is missing`);
      continue;
    }

    const original = normalizeForComparison(JSON.parse(fs.readFileSync(originalJsonPath, "utf8")));
    const generated = normalizeForComparison(JSON.parse(fs.readFileSync(generatedJsonPath, "utf8")));
    const diff = diffObjects(original, generated);

    if (diff.length > 0) {
      mismatches.push(`${fileName}: ${diff[0]}`);
      continue;
    }

    log(fileName, "pass");
  }

  if (mismatches.length > 0) {
    log("", "blank");
    log("Validation mismatches:", "error");
    for (const mismatch of mismatches) {
      log(mismatch, "fail");
    }

    throw new Error(`Validation failed for ${mismatches.length} template(s).`);
  }

  log("Validated regenerated step-templates/*.json against step-templates-orig/", "success");
  log("Rebuilt and validated regenerated step-templates/*.json against step-templates-orig/", "success");
  return true;
}

async function main() {
  const rl = readline.createInterface({ input: stdin, output: stdout });

  try {
    log("Source-first migration", "banner");
    log(colorize(ansiDim, `Repo root: ${repoRoot}`));
    log(colorize(ansiDim, "This script does not commit anything."));

    if (!(await step1_PrepareValidationBaseline(rl))) { return; }

    if (!(await step2_MoveJsonTemplatesIntoSourceTree(rl))) { return; }

    if (!(await step3_SplitSourceTemplatesIntoConstituentFiles(rl))) { return; }

    if (!(await step4_RebuildAndValidateGeneratedJson(rl))) { return; }
  } finally {
    rl.close();
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
