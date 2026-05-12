import { HashRouter, Link, Route, Routes } from "react-router-dom";
import { MarkGithubIcon } from "@primer/octicons-react";
import PullRequestList from "./routes/PullRequestList";
import PullRequestDetail from "./routes/PullRequestDetail";
import { repoInfo } from "./api/github";

export default function App() {
  return (
    <HashRouter>
      <header className="app-header">
        <div className="app-header-inner">
          <Link to="/" className="app-brand">
            <img
              src={`${import.meta.env.BASE_URL}hyponome.png`}
              alt=""
              className="app-brand-logo"
              width={32}
              height={32}
            />
            <span className="app-brand-text">
              <span className="app-brand-name">Hyponome</span>
              <span className="app-brand-tagline">Octopus Library PR review</span>
            </span>
          </Link>
          <a
            href={`https://github.com/${repoInfo.owner}/${repoInfo.repo}`}
            target="_blank"
            rel="noreferrer"
            className="app-header-repo"
          >
            <MarkGithubIcon size={16} />
            <span>
              {repoInfo.owner}/{repoInfo.repo}
            </span>
          </a>
        </div>
      </header>
      <main className="app-main">
        <Routes>
          <Route path="/" element={<PullRequestList />} />
          <Route path="/pulls/:number" element={<PullRequestDetail />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
    </HashRouter>
  );
}

function NotFound() {
  return (
    <div className="empty-state">
      <h2>Not found</h2>
      <p>
        Nothing lives at this URL. <Link to="/">Back to pull requests</Link>.
      </p>
    </div>
  );
}
