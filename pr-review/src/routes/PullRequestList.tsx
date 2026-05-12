import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { GitPullRequestIcon } from "@primer/octicons-react";
import { listOpenPullRequests } from "../api/github";
import type { PullRequestSummary } from "../api/types";
import ErrorState from "../components/ErrorState";
import TimeAgo from "../components/TimeAgo";

export default function PullRequestList() {
  const [pulls, setPulls] = useState<PullRequestSummary[] | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;
    setPulls(null);
    setError(null);
    listOpenPullRequests()
      .then((data) => {
        if (!cancelled) setPulls(data);
      })
      .catch((err: Error) => {
        if (!cancelled) setError(err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (error) return <ErrorState error={error} />;
  if (!pulls) return <div className="loading">Loading pull requests…</div>;
  if (pulls.length === 0) return <div className="empty-state">No open pull requests.</div>;

  return (
    <section className="pr-list">
      <h1 className="pr-list-heading">
        Open pull requests <span className="pr-badge">{pulls.length}</span>
      </h1>
      <ul className="pr-list-rows">
        {pulls.map((pr) => (
          <li key={pr.number} className="pr-row">
            <div className="pr-row-icon" aria-hidden>
              <GitPullRequestIcon size={20} />
            </div>
            <div className="pr-row-body">
              <h2 className="pr-row-title">
                <Link to={`/pulls/${pr.number}`}>{pr.title}</Link>
                {pr.draft && <span className="pr-tag pr-tag-draft">Draft</span>}
                {pr.labels.map((label) => (
                  <span
                    key={label.id}
                    className="pr-tag"
                    style={{
                      backgroundColor: `#${label.color}`,
                      color: labelTextColor(label.color),
                    }}
                    title={label.description ?? undefined}
                  >
                    {label.name}
                  </span>
                ))}
              </h2>
              <div className="pr-row-meta">
                #{pr.number} opened <TimeAgo isoDate={pr.created_at} /> by{" "}
                <a href={pr.user.html_url} target="_blank" rel="noreferrer">
                  {pr.user.login}
                </a>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

function labelTextColor(hex: string): string {
  if (hex.length !== 6) return "#1f2328";
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  // Perceptual luminance — pick dark text on light labels, light text on dark.
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.6 ? "#1f2328" : "#ffffff";
}
