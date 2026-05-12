import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { DiffEditor } from "@monaco-editor/react";
import { AlertIcon, FileCodeIcon, FileDiffIcon } from "@primer/octicons-react";
import { extractScripts, type ExtractedScript } from "../lib/extractScript";
import { isBinaryFilename, languageFromFilename } from "../lib/languageDetect";
import { fetchFileContent } from "../api/github";
import type { PullRequestFile } from "../api/types";

const MONACO_OPTIONS = {
  readOnly: true,
  automaticLayout: true,
  minimap: { enabled: false },
  scrollBeyondLastLine: false,
  fontSize: 13,
  renderWhitespace: "none" as const,
  renderSideBySide: true,
} as const;

const EDITOR_HEIGHT = "600px";

interface Props {
  file: PullRequestFile;
  /** Base commit SHA to fetch the "before" file content from. */
  baseRef: string;
  /** Head commit SHA to fetch the "after" file content from. */
  headRef: string;
}

interface Content {
  before: string | null;
  after: string | null;
}

export default function FilePanel({ file, baseRef, headRef }: Props) {
  const [content, setContent] = useState<Content | null>(null);
  const [loadError, setLoadError] = useState<Error | null>(null);
  const [activeTab, setActiveTab] = useState(0);

  const isBinary = isBinaryFilename(file.filename);

  useEffect(() => {
    setActiveTab(0);
    setLoadError(null);

    // Binary files: skip the fetch entirely.
    if (isBinary) {
      setContent({ before: null, after: null });
      return;
    }

    let cancelled = false;
    setContent(null);

    const previousFilename = file.previous_filename ?? file.filename;

    async function load() {
      try {
        const [before, after] = await Promise.all([
          file.status === "added"
            ? Promise.resolve<string | null>(null)
            : fetchFileContent(previousFilename, baseRef),
          file.status === "removed"
            ? Promise.resolve<string | null>(null)
            : fetchFileContent(file.filename, headRef),
        ]);
        if (!cancelled) setContent({ before, after });
      } catch (err) {
        if (!cancelled) setLoadError(err as Error);
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [file.filename, file.previous_filename, file.status, baseRef, headRef, isBinary]);

  const scripts: ExtractedScript[] =
    content && file.filename.toLowerCase().endsWith(".json")
      ? extractScripts(content.before, content.after)
      : [];

  return (
    <section className="file-panel">
      <header className="file-panel-header">
        <div className="file-panel-name">
          <FileDiffIcon size={16} />
          <span title={file.filename}>
            {file.previous_filename && file.previous_filename !== file.filename ? (
              <>
                <span className="file-renamed-from">{file.previous_filename}</span>{" "}
                <span aria-hidden>→</span> {file.filename}
              </>
            ) : (
              file.filename
            )}
          </span>
        </div>
        <span className="file-stats">
          <span className="file-stats-additions">+{file.additions}</span>
          <span className="file-stats-deletions">-{file.deletions}</span>
        </span>
      </header>

      <nav className="file-panel-tabs" role="tablist" aria-label={`Views for ${file.filename}`}>
        <TabButton
          active={activeTab === 0}
          onClick={() => setActiveTab(0)}
          icon={<FileDiffIcon size={14} />}
        >
          File diff
        </TabButton>
        {scripts.map((script, idx) => (
          <TabButton
            key={script.key}
            active={activeTab === idx + 1}
            onClick={() => setActiveTab(idx + 1)}
            icon={<FileCodeIcon size={14} />}
          >
            {script.label}
          </TabButton>
        ))}
      </nav>

      <div className="file-panel-body">
        <PanelBody
          file={file}
          isBinary={isBinary}
          content={content}
          loadError={loadError}
          activeTab={activeTab}
          scripts={scripts}
        />
      </div>
    </section>
  );
}

interface PanelBodyProps {
  file: PullRequestFile;
  isBinary: boolean;
  content: Content | null;
  loadError: Error | null;
  activeTab: number;
  scripts: ExtractedScript[];
}

function PanelBody({ file, isBinary, content, loadError, activeTab, scripts }: PanelBodyProps) {
  if (loadError) {
    return (
      <div className="file-panel-status file-panel-status-error">
        <AlertIcon size={16} />
        <span>{loadError.message}</span>
      </div>
    );
  }

  if (isBinary) {
    return (
      <div className="file-panel-status">
        Binary file ({file.status}). Preview not shown.
      </div>
    );
  }

  if (!content) {
    return <div className="file-panel-status">Loading file content…</div>;
  }

  if (activeTab === 0) {
    return (
      <DiffEditor
        // Stable key per file revision. Forces a clean unmount/remount when
        // the PR changes, avoiding @monaco-editor/react's known
        // "TextModel got disposed before DiffEditorWidget model got reset"
        // race during rapid prop updates.
        key={`${file.sha}|${file.filename}|file`}
        height={EDITOR_HEIGHT}
        original={content.before ?? ""}
        modified={content.after ?? ""}
        language={languageFromFilename(file.filename)}
        theme="vs-dark"
        options={MONACO_OPTIONS}
      />
    );
  }

  const script = scripts[activeTab - 1];
  if (!script) {
    // Defensive — shouldn't happen because activeTab resets to 0 on file change.
    return <div className="file-panel-status">Tab not available.</div>;
  }
  return (
    <DiffEditor
      key={`${file.sha}|${file.filename}|${script.key}`}
      height={EDITOR_HEIGHT}
      original={(script.before ?? "").replace(/\r\n/g, "\n")}
      modified={(script.after ?? "").replace(/\r\n/g, "\n")}
      language={script.language}
      theme="vs-dark"
      options={MONACO_OPTIONS}
    />
  );
}

interface TabButtonProps {
  active: boolean;
  onClick: () => void;
  icon: ReactNode;
  children: ReactNode;
}

function TabButton({ active, onClick, icon, children }: TabButtonProps) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      className={`file-panel-tab${active ? " file-panel-tab-active" : ""}`}
      onClick={onClick}
    >
      {icon}
      <span>{children}</span>
    </button>
  );
}
