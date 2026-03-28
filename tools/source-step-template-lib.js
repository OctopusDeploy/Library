"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const legacyRoot = path.join(repoRoot, "step-templates");
const sourceRoot = path.join(repoRoot, "src", "step-templates");

const placeholderPrefix = "__SOURCE_FILE__:";

const scriptDefinitions = [
  {
    sourceBaseName: "scriptbody",
    sourceExtensions: [".ps1", ".sh", ".py"],
    legacySuffixes: [".ScriptBody.ps1", ".ScriptBody.sh", ".ScriptBody.py"],
    propertyName: "Octopus.Action.Script.ScriptBody",
  },
  {
    sourceBaseName: "predeploy",
    sourceExtensions: [".ps1"],
    legacySuffixes: [".PreDeploy.ps1"],
    propertyName: "Octopus.Action.CustomScripts.PreDeploy.ps1",
  },
  {
    sourceBaseName: "deploy",
    sourceExtensions: [".ps1"],
    legacySuffixes: [".Deploy.ps1"],
    propertyName: "Octopus.Action.CustomScripts.Deploy.ps1",
  },
  {
    sourceBaseName: "postdeploy",
    sourceExtensions: [".ps1"],
    legacySuffixes: [".PostDeploy.ps1"],
    propertyName: "Octopus.Action.CustomScripts.PostDeploy.ps1",
  },
];

function isDirectory(dirPath) {
  return fs.existsSync(dirPath) && fs.statSync(dirPath).isDirectory();
}

function ensureDirectory(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function normalizeTemplateName(templateName) {
  return templateName.replace(/\.json$/i, "");
}

function getSourceTemplateDirectory(templateName) {
  return path.join(sourceRoot, normalizeTemplateName(templateName));
}

function getMetadataPath(templateName) {
  return path.join(getSourceTemplateDirectory(templateName), "metadata.json");
}

function getLegacyJsonPath(templateName) {
  return path.join(legacyRoot, `${normalizeTemplateName(templateName)}.json`);
}

function getLegacyOrigPath(templateName) {
  return path.join(legacyRoot, `${normalizeTemplateName(templateName)}.json.orig`);
}

function getPowerShellCommand() {
  return process.env.PWSH_PATH || "pwsh";
}

function runPowerShellScript(scriptPath, args = []) {
  execFileSync(getPowerShellCommand(), ["-NoProfile", "-File", scriptPath, ...args], {
    cwd: repoRoot,
    stdio: "inherit",
  });
}

function runPack(templateName) {
  runPowerShellScript(path.join(repoRoot, "tools", "_pack.ps1"), ["-SearchPattern", normalizeTemplateName(templateName)]);
}

function runUnpack(templateName) {
  runPowerShellScript(path.join(repoRoot, "tools", "_unpack.ps1"), ["-SearchPattern", normalizeTemplateName(templateName), "-Force"]);
}

function listMigratedTemplates() {
  if (!isDirectory(sourceRoot)) {
    return [];
  }

  return fs
    .readdirSync(sourceRoot)
    .filter((entry) => !["logos", "tests"].includes(entry))
    .filter((entry) => isDirectory(path.join(sourceRoot, entry)))
    .filter((entry) => fs.existsSync(path.join(sourceRoot, entry, "metadata.json")))
    .sort();
}

function listLegacyTemplates() {
  if (!isDirectory(legacyRoot)) {
    return [];
  }

  return fs
    .readdirSync(legacyRoot)
    .filter((entry) => entry.endsWith(".json"))
    .map((entry) => entry.replace(/\.json$/i, ""))
    .sort();
}

function readJson(jsonPath) {
  return JSON.parse(fs.readFileSync(jsonPath, "utf8"));
}

function writeJson(jsonPath, value) {
  fs.writeFileSync(jsonPath, `${JSON.stringify(value, null, 2)}\n`);
}

function setPlaceholderValue(fileName) {
  return `${placeholderPrefix}${fileName}`;
}

function getScriptSourceFileName(templateDirectory, definition) {
  for (const extension of definition.sourceExtensions) {
    const fileName = `${definition.sourceBaseName}${extension}`;
    if (fs.existsSync(path.join(templateDirectory, fileName))) {
      return fileName;
    }
  }

  return null;
}

function getLegacySidecarFileName(templateName, sourceFileName, definition) {
  const extension = path.extname(sourceFileName);
  if (definition.sourceBaseName === "scriptbody") {
    return `${normalizeTemplateName(templateName)}.ScriptBody${extension}`;
  }

  const suffix = definition.legacySuffixes.find((candidate) => candidate.endsWith(extension));
  if (!suffix) {
    throw new Error(`Unsupported sidecar extension '${extension}' for ${sourceFileName}`);
  }

  return `${normalizeTemplateName(templateName)}${suffix}`;
}

function cleanGeneratedSidecars(templateName) {
  for (const definition of scriptDefinitions) {
    for (const suffix of definition.legacySuffixes) {
      const sidecarPath = path.join(legacyRoot, `${normalizeTemplateName(templateName)}${suffix}`);
      if (fs.existsSync(sidecarPath)) {
        fs.rmSync(sidecarPath, { force: true });
      }
    }
  }
}

function materializeLegacyTemplate(templateName) {
  const normalizedName = normalizeTemplateName(templateName);
  const templateDirectory = getSourceTemplateDirectory(normalizedName);
  const metadataPath = getMetadataPath(normalizedName);

  if (!fs.existsSync(metadataPath)) {
    return false;
  }

  ensureDirectory(legacyRoot);
  fs.copyFileSync(metadataPath, getLegacyJsonPath(normalizedName));

  for (const definition of scriptDefinitions) {
    const sourceFileName = getScriptSourceFileName(templateDirectory, definition);
    if (!sourceFileName) {
      continue;
    }

    const sourcePath = path.join(templateDirectory, sourceFileName);
    const destinationPath = path.join(legacyRoot, getLegacySidecarFileName(normalizedName, sourceFileName, definition));
    fs.copyFileSync(sourcePath, destinationPath);
  }

  return true;
}

function generateTemplate(templateName) {
  const normalizedName = normalizeTemplateName(templateName);
  const generated = materializeLegacyTemplate(normalizedName);
  if (!generated) {
    return false;
  }

  try {
    runPack(normalizedName);
  } finally {
    cleanGeneratedSidecars(normalizedName);
  }

  return true;
}

function generateAllMigratedTemplates() {
  for (const templateName of listMigratedTemplates()) {
    generateTemplate(templateName);
  }
}

function inferTemplateNameFromSourcePath(changedPath) {
  const absolutePath = path.resolve(changedPath);
  const relativePath = path.relative(sourceRoot, absolutePath);

  if (relativePath.startsWith("..")) {
    return { type: "outside" };
  }

  const parts = relativePath.split(path.sep).filter(Boolean);
  if (parts.length === 0) {
    return { type: "all" };
  }

  const [firstSegment, secondSegment] = parts;
  if (firstSegment === "logos") {
    return { type: "logos" };
  }

  if (firstSegment === "tests") {
    return { type: "tests", testFile: secondSegment || null };
  }

  return { type: "template", templateName: firstSegment };
}

function updateMetadataWithPlaceholders(templateName) {
  const metadataPath = getMetadataPath(templateName);
  const templateDirectory = getSourceTemplateDirectory(templateName);
  const metadata = readJson(metadataPath);
  metadata.Properties = metadata.Properties || {};

  for (const definition of scriptDefinitions) {
    const sourceFileName = getScriptSourceFileName(templateDirectory, definition);
    if (!sourceFileName) {
      continue;
    }

    metadata.Properties[definition.propertyName] = setPlaceholderValue(sourceFileName);
  }

  writeJson(metadataPath, metadata);
}

function moveExtractedSidecarsIntoSource(templateName) {
  const templateDirectory = getSourceTemplateDirectory(templateName);
  ensureDirectory(templateDirectory);

  for (const definition of scriptDefinitions) {
    for (const suffix of definition.legacySuffixes) {
      const legacyPath = path.join(legacyRoot, `${normalizeTemplateName(templateName)}${suffix}`);
      if (!fs.existsSync(legacyPath)) {
        continue;
      }

      const extension = path.extname(legacyPath);
      const destinationPath = path.join(templateDirectory, `${definition.sourceBaseName}${extension}`);
      fs.renameSync(legacyPath, destinationPath);
    }
  }
}

function compareGeneratedToOrig(templateName) {
  const generatedPath = getLegacyJsonPath(templateName);
  const originalPath = getLegacyOrigPath(templateName);
  const generatedBuffer = fs.readFileSync(generatedPath);
  const originalBuffer = fs.readFileSync(originalPath);
  return generatedBuffer.equals(originalBuffer);
}

module.exports = {
  cleanGeneratedSidecars,
  compareGeneratedToOrig,
  ensureDirectory,
  generateAllMigratedTemplates,
  generateTemplate,
  getLegacyJsonPath,
  getLegacyOrigPath,
  getMetadataPath,
  getSourceTemplateDirectory,
  inferTemplateNameFromSourcePath,
  legacyRoot,
  listLegacyTemplates,
  listMigratedTemplates,
  moveExtractedSidecarsIntoSource,
  normalizeTemplateName,
  placeholderPrefix,
  readJson,
  repoRoot,
  runUnpack,
  scriptDefinitions,
  setPlaceholderValue,
  sourceRoot,
  updateMetadataWithPlaceholders,
  writeJson,
};
