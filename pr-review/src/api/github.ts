import {
  GitHubApiError,
  type PullRequestDetail,
  type PullRequestFile,
  type PullRequestSummary,
  type RateLimitInfo,
} from "./types";

const OWNER = "OctopusDeploy";
const REPO = "Library";
const API_BASE = "https://api.github.com";
const RAW_BASE = "https://raw.githubusercontent.com";

let latestRateLimit: RateLimitInfo | null = null;

export function getLatestRateLimit(): RateLimitInfo | null {
  return latestRateLimit;
}

function readRateLimit(response: Response): RateLimitInfo | null {
  const limit = response.headers.get("x-ratelimit-limit");
  const remaining = response.headers.get("x-ratelimit-remaining");
  const reset = response.headers.get("x-ratelimit-reset");
  if (!limit || !remaining || !reset) return null;
  return {
    limit: Number(limit),
    remaining: Number(remaining),
    resetAt: new Date(Number(reset) * 1000),
  };
}

async function ghFetch(
  path: string,
  accept: string = "application/vnd.github+json",
): Promise<Response> {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      Accept: accept,
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });
  const rl = readRateLimit(response);
  if (rl) latestRateLimit = rl;
  if (!response.ok) {
    let message = `GitHub API ${response.status} ${response.statusText}`;
    try {
      const body = (await response.clone().json()) as { message?: string };
      if (body?.message) message = body.message;
    } catch {
      /* response body wasn't JSON; keep the status text */
    }
    throw new GitHubApiError(message, response.status, rl);
  }
  return response;
}

export async function listOpenPullRequests(): Promise<PullRequestSummary[]> {
  const response = await ghFetch(
    `/repos/${OWNER}/${REPO}/pulls?state=open&per_page=100&sort=created&direction=desc`,
  );
  return (await response.json()) as PullRequestSummary[];
}

export async function getPullRequest(number: number): Promise<PullRequestDetail> {
  const response = await ghFetch(`/repos/${OWNER}/${REPO}/pulls/${number}`);
  return (await response.json()) as PullRequestDetail;
}

export async function listPullRequestFiles(number: number): Promise<PullRequestFile[]> {
  // GitHub allows up to 3000 files per PR across paginated pages of 100.
  // Step-template PRs are nearly always single-file, but paginate defensively.
  const all: PullRequestFile[] = [];
  for (let page = 1; page <= 30; page++) {
    const response = await ghFetch(
      `/repos/${OWNER}/${REPO}/pulls/${number}/files?per_page=100&page=${page}`,
    );
    const batch = (await response.json()) as PullRequestFile[];
    all.push(...batch);
    if (batch.length < 100) break;
  }
  return all;
}

/**
 * Fetch the raw contents of a file at a given commit SHA via
 * raw.githubusercontent.com. This is a static CDN endpoint that
 *   - does NOT count against the api.github.com rate limit, and
 *   - allows cross-origin reads on public repos,
 * so we can fetch before/after pairs cheaply for side-by-side diffs.
 *
 * Path must be URI-encoded segment-by-segment to handle filenames with
 * spaces or non-ASCII chars (which do appear in step-template/logos/).
 */
export async function fetchFileContent(path: string, ref: string): Promise<string> {
  const encodedPath = path
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  const url = `${RAW_BASE}/${OWNER}/${REPO}/${ref}/${encodedPath}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not fetch ${path} at ${ref.slice(0, 7)}: HTTP ${response.status}`);
  }
  return response.text();
}

export const repoInfo = { owner: OWNER, repo: REPO };
