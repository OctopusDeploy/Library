import type { PullRequestDetail } from "../api/types";
import TimeAgo from "./TimeAgo";

interface Props {
  pr: PullRequestDetail;
}

export default function PullRequestHeader({ pr }: Props) {
  return (
    <header className="pr-header">
      <div className="pr-header-titlebar">
        <h1 className="pr-header-title">
          <span>{pr.title}</span>
          <span className="pr-header-number">#{pr.number}</span>
        </h1>
        <a
          href={pr.html_url}
          target="_blank"
          rel="noreferrer"
          className="btn btn-small"
        >
          Open on GitHub
        </a>
      </div>
      <div className="pr-header-meta">
        <a href={pr.user.html_url} target="_blank" rel="noreferrer" className="pr-header-author">
          {pr.user.login}
        </a>{" "}
        wants to merge{" "}
        <code className="pr-ref">{pr.head.label}</code> into{" "}
        <code className="pr-ref">{pr.base.label}</code>
        <span className="pr-header-dot">·</span>
        opened <TimeAgo isoDate={pr.created_at} />
        {pr.draft && <span className="pr-tag pr-tag-draft">Draft</span>}
      </div>
    </header>
  );
}
