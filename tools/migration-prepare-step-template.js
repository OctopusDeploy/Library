"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const {
  ensureDirectory,
  getLegacyJsonPath,
  getLegacyOrigPath,
  getSourceTemplateDirectory,
  moveExtractedSidecarsIntoSource,
  normalizeTemplateName,
  repoRoot,
  runPack,
  runUnpack,
  updateMetadataWithPlaceholders,
} = require("./source-step-template-lib");

function gitMove(fromPath, toPath) {
  execFileSync("git", ["mv", fromPath, toPath], {
    cwd: repoRoot,
    stdio: "inherit",
  });
}

function prepareTemplate(templateName) {
  const normalizedName = normalizeTemplateName(templateName);
  const legacyJsonPath = getLegacyJsonPath(normalizedName);
  const legacyOrigPath = getLegacyOrigPath(normalizedName);
  const sourceDirectory = getSourceTemplateDirectory(normalizedName);
  const metadataPath = path.join(sourceDirectory, "metadata.json");

  if (!fs.existsSync(legacyJsonPath)) {
    throw new Error(`Legacy template '${normalizedName}.json' was not found.`);
  }

  ensureDirectory(sourceDirectory);

  runUnpack(normalizedName);
  runPack(normalizedName);

  if (!fs.existsSync(legacyOrigPath)) {
    fs.copyFileSync(legacyJsonPath, legacyOrigPath);
  }

  if (!fs.existsSync(metadataPath)) {
    gitMove(path.relative(repoRoot, legacyJsonPath), path.relative(repoRoot, metadataPath));
  }

  moveExtractedSidecarsIntoSource(normalizedName);
  updateMetadataWithPlaceholders(normalizedName);
}

function main() {
  const templateNames = process.argv.slice(2);
  if (templateNames.length === 0) {
    throw new Error("At least one template name is required.");
  }

  for (const templateName of templateNames) {
    prepareTemplate(templateName);
  }
}

main();
