"use strict";

const fs = require("fs");
const {
  compareGeneratedToOrig,
  generateTemplate,
  getLegacyOrigPath,
  normalizeTemplateName,
} = require("./source-step-template-lib");

function main() {
  const args = process.argv.slice(2);
  const cleanup = args.includes("--cleanup");
  const templateNames = args.filter((arg) => arg !== "--cleanup");

  if (templateNames.length === 0) {
    throw new Error("At least one template name is required.");
  }

  for (const templateName of templateNames) {
    const normalizedName = normalizeTemplateName(templateName);
    generateTemplate(normalizedName);

    if (!compareGeneratedToOrig(normalizedName)) {
      throw new Error(`Packed output for '${normalizedName}' does not match '${normalizedName}.json.orig'.`);
    }

    if (cleanup) {
      fs.rmSync(getLegacyOrigPath(normalizedName), { force: true });
    }
  }
}

main();
