import { languageFromExtension } from "./languageDetect";

/**
 * Step-template JSON files embed scripts as JSON-escaped strings inside
 * properties under the top-level `Properties` object. Diffing the raw JSON
 * is unreadable — the entire script change shows up as one giant `-` line
 * and one giant `+` line. `extractScripts` reads the parsed before/after
 * step templates and pulls out every embedded script so each one can be
 * shown in its own syntax-highlighted side-by-side diff.
 *
 * Handles:
 *   - `Octopus.Action.Script.ScriptBody`              (the inline script)
 *   - `Octopus.Action.Terraform.Template`             (HCL)
 *   - `Octopus.Action.Terraform.VariableValues`       (HCL)
 *   - `Octopus.Action.CustomScripts.{phase}.{ext}`    (pre/deploy/post custom scripts)
 *
 * This is a refactor of the Hyponome PullRequest.cshtml logic to work on
 * parsed JSON instead of patch text, which is dramatically simpler and
 * also lets us surface multiple scripts from one file at once.
 */

const SCRIPT_BODY_KEY = "Octopus.Action.Script.ScriptBody";
const SCRIPT_SYNTAX_KEY = "Octopus.Action.Script.Syntax";
const TERRAFORM_TEMPLATE_KEY = "Octopus.Action.Terraform.Template";
const TERRAFORM_VARS_KEY = "Octopus.Action.Terraform.VariableValues";
const CUSTOM_SCRIPTS_PREFIX = "Octopus.Action.CustomScripts.";

export interface ExtractedScript {
  /** Unique key for React (the Octopus property name). */
  key: string;
  /** Human-readable tab label. */
  label: string;
  /** Original script content, or null if newly added. */
  before: string | null;
  /** New script content, or null if removed. */
  after: string | null;
  /** Monaco language id. */
  language: string;
}

interface StepTemplate {
  Properties?: Record<string, unknown>;
}

export function extractScripts(
  beforeJson: string | null,
  afterJson: string | null,
): ExtractedScript[] {
  const before = safeParse<StepTemplate>(beforeJson);
  const after = safeParse<StepTemplate>(afterJson);
  if (!before?.Properties && !after?.Properties) return [];

  const results: ExtractedScript[] = [];

  pushIfPresent(results, before, after, SCRIPT_BODY_KEY, "Script", () =>
    detectMainScriptLanguage(before, after),
  );
  pushIfPresent(results, before, after, TERRAFORM_TEMPLATE_KEY, "Terraform template", () => "hcl");
  pushIfPresent(results, before, after, TERRAFORM_VARS_KEY, "Terraform variables", () => "hcl");

  // Custom scripts are keyed by phase + extension, e.g.
  //   Octopus.Action.CustomScripts.PreDeploy.ps1
  //   Octopus.Action.CustomScripts.Deploy.sh
  //   Octopus.Action.CustomScripts.PostDeploy.csx
  const customKeys = new Set<string>();
  for (const obj of [before, after]) {
    if (!obj?.Properties) continue;
    for (const key of Object.keys(obj.Properties)) {
      if (key.startsWith(CUSTOM_SCRIPTS_PREFIX)) customKeys.add(key);
    }
  }
  for (const key of [...customKeys].sort()) {
    const suffix = key.slice(CUSTOM_SCRIPTS_PREFIX.length); // e.g. "PreDeploy.ps1"
    const ext = suffix.split(".").pop() ?? "";
    pushIfPresent(results, before, after, key, `Custom: ${suffix}`, () =>
      languageFromExtension(ext),
    );
  }

  return results;
}

function pushIfPresent(
  out: ExtractedScript[],
  before: StepTemplate | null,
  after: StepTemplate | null,
  key: string,
  label: string,
  language: () => string,
): void {
  const beforeVal = readString(before?.Properties?.[key]);
  const afterVal = readString(after?.Properties?.[key]);
  if (beforeVal === null && afterVal === null) return;
  // Don't surface a tab for a script that exists but didn't change in this PR.
  if (beforeVal !== null && afterVal !== null && beforeVal === afterVal) return;
  out.push({ key, label, before: beforeVal, after: afterVal, language: language() });
}

function readString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function safeParse<T>(text: string | null): T | null {
  if (!text) return null;
  try {
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}

function detectMainScriptLanguage(
  before: StepTemplate | null,
  after: StepTemplate | null,
): string {
  // Prefer the NEW syntax declaration if present (handles PRs that change syntax).
  const syntax =
    readString(after?.Properties?.[SCRIPT_SYNTAX_KEY]) ??
    readString(before?.Properties?.[SCRIPT_SYNTAX_KEY]) ??
    "PowerShell";
  switch (syntax.toLowerCase()) {
    case "bash":
    case "sh":
      return "shell";
    case "powershell":
      return "powershell";
    case "python":
      return "python";
    case "csharp":
      return "csharp";
    case "fsharp":
      return "fsharp";
    case "terraform":
      return "hcl";
    default:
      return syntax.toLowerCase();
  }
}
