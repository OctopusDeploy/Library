/**
 * Map filename extensions to Monaco language ids. Used both for the main
 * file-diff tab (when the file is JSON/MD/YML/etc.) and for extracted
 * custom-script files (which embed their syntax in their key suffix).
 */
const EXTENSION_TO_LANGUAGE: Record<string, string> = {
  json: "json",
  ts: "typescript",
  tsx: "typescript",
  js: "javascript",
  jsx: "javascript",
  md: "markdown",
  yml: "yaml",
  yaml: "yaml",
  ps1: "powershell",
  sh: "shell",
  bash: "shell",
  py: "python",
  cs: "csharp",
  csx: "csharp",
  fs: "fsharp",
  fsx: "fsharp",
  tf: "hcl",
  hcl: "hcl",
  xml: "xml",
  html: "html",
  css: "css",
  scss: "scss",
  rb: "ruby",
  go: "go",
  java: "java",
  rs: "rust",
  toml: "ini",
  ini: "ini",
  txt: "plaintext",
};

const BINARY_EXTENSIONS = new Set([
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "ico",
  "webp",
  "pdf",
  "zip",
  "tar",
  "gz",
  "exe",
  "dll",
  "so",
  "dylib",
]);

function getExtension(filename: string): string {
  const dot = filename.lastIndexOf(".");
  if (dot < 0) return "";
  return filename.slice(dot + 1).toLowerCase();
}

export function languageFromFilename(filename: string): string {
  return EXTENSION_TO_LANGUAGE[getExtension(filename)] ?? "plaintext";
}

export function languageFromExtension(ext: string): string {
  return EXTENSION_TO_LANGUAGE[ext.toLowerCase()] ?? "plaintext";
}

export function isBinaryFilename(filename: string): boolean {
  return BINARY_EXTENSIONS.has(getExtension(filename));
}
