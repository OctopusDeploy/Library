import { GitHubApiError } from "../api/types";

interface Props {
  error: Error;
}

export default function ErrorState({ error }: Props) {
  const isRateLimit = error instanceof GitHubApiError && error.isRateLimit;
  const rl = error instanceof GitHubApiError ? error.rateLimit : null;

  return (
    <div className="error-state">
      <h2>{isRateLimit ? "GitHub API rate limit reached" : "Something went wrong"}</h2>
      <p className="error-state-message">{error.message}</p>
      {isRateLimit && (
        <>
          <p>
            Unauthenticated requests to the GitHub API are limited to 60 per hour per IP address.
            Browsing a few PRs in succession can exhaust that quickly.
          </p>
          {rl && (
            <p>
              <strong>Resets at {rl.resetAt.toLocaleTimeString()}.</strong>
            </p>
          )}
        </>
      )}
    </div>
  );
}
