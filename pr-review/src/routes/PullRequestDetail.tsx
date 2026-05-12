import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeftIcon } from "@primer/octicons-react";
import { getPullRequest, listPullRequestFiles } from "../api/github";
import type { PullRequestDetail as Pull, PullRequestFile } from "../api/types";
import ErrorState from "../components/ErrorState";
import PullRequestHeader from "../components/PullRequestHeader";
import FilePanel from "../components/FilePanel";

export default function PullRequestDetail() {
  const { number } = useParams<{ number: string }>();
  const num = Number(number);
  const [pull, setPull] = useState<Pull | null>(null);
  const [files, setFiles] = useState<PullRequestFile[] | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!Number.isFinite(num) || num <= 0) {
      setError(new Error(`Invalid pull request number: ${number}`));
      return;
    }
    let cancelled = false;
    setPull(null);
    setFiles(null);
    setError(null);

    async function load() {
      try {
        const [prData, fileData] = await Promise.all([
          getPullRequest(num),
          listPullRequestFiles(num),
        ]);
        if (!cancelled) {
          setPull(prData);
          setFiles(fileData);
        }
      } catch (err) {
        if (!cancelled) setError(err as Error);
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [num, number]);

  if (error) return <ErrorState error={error} />;
  if (!pull || !files) return <div className="loading">Loading pull request…</div>;

  return (
    <article className="pr-detail">
      <Link to="/" className="back-link">
        <ArrowLeftIcon size={14} /> Back to pull requests
      </Link>
      <PullRequestHeader pr={pull} />
      <section className="pr-files">
        <h2 className="pr-files-heading">
          Files changed <span className="pr-badge">{pull.changed_files}</span>
        </h2>
        {files.length === 0 ? (
          <div className="empty-state">No file changes reported.</div>
        ) : (
          files.map((f) => (
            <FilePanel
              key={f.sha + f.filename}
              file={f}
              baseRef={pull.base.sha}
              headRef={pull.head.sha}
            />
          ))
        )}
      </section>
    </article>
  );
}
