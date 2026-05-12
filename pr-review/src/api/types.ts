// Hand-trimmed shapes for the GitHub REST endpoints we touch.
// Keeping these local avoids pulling @octokit/openapi-types (~megabytes of type defs)
// just to call three endpoints.

export interface GitHubUser {
  login: string;
  html_url: string;
  avatar_url: string;
}

export interface GitHubLabel {
  id: number;
  name: string;
  color: string;
  description: string | null;
}

export interface PullRequestRef {
  label: string;
  ref: string;
  sha: string;
}

export interface PullRequestSummary {
  number: number;
  title: string;
  html_url: string;
  user: GitHubUser;
  labels: GitHubLabel[];
  created_at: string;
  draft: boolean;
  state: string;
}

export interface PullRequestDetail {
  number: number;
  title: string;
  body: string | null;
  html_url: string;
  user: GitHubUser;
  base: PullRequestRef;
  head: PullRequestRef;
  changed_files: number;
  state: string;
  draft: boolean;
  created_at: string;
}

export interface PullRequestFile {
  sha: string;
  filename: string;
  status: "added" | "removed" | "modified" | "renamed" | "copied" | "changed" | "unchanged";
  additions: number;
  deletions: number;
  changes: number;
  patch?: string;
  previous_filename?: string;
  blob_url: string;
  raw_url: string;
}

export interface RateLimitInfo {
  limit: number;
  remaining: number;
  resetAt: Date;
}

export class GitHubApiError extends Error {
  readonly status: number;
  readonly isRateLimit: boolean;
  readonly rateLimit: RateLimitInfo | null;

  constructor(message: string, status: number, rateLimit: RateLimitInfo | null) {
    super(message);
    this.name = "GitHubApiError";
    this.status = status;
    this.rateLimit = rateLimit;
    this.isRateLimit = status === 403 && rateLimit?.remaining === 0;
  }
}
