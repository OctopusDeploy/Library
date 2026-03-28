"use strict";

const {
  generateAllMigratedTemplates,
  generateTemplate,
  inferTemplateNameFromSourcePath,
} = require("./source-step-template-lib");

function main() {
  const [, , command = "all", value] = process.argv;

  if (command === "all") {
    generateAllMigratedTemplates();
    return;
  }

  if (command === "template") {
    if (!value) {
      throw new Error("A template name is required for the 'template' command.");
    }

    generateTemplate(value);
    return;
  }

  if (command === "changed-path") {
    if (!value) {
      throw new Error("A source path is required for the 'changed-path' command.");
    }

    const result = inferTemplateNameFromSourcePath(value);
    if (result.type === "template") {
      generateTemplate(result.templateName);
      return;
    }

    if (result.type === "logos") {
      generateAllMigratedTemplates();
      return;
    }

    return;
  }

  throw new Error(`Unsupported command '${command}'.`);
}

main();
