# PR Review

A browser-only PR review tool for [OctopusDeploy/Library](https://github.com/OctopusDeploy/Library).
Successor to [Hyponome](https://github.com/hnrkndrssn/hyponome): same feature set, no server,
deployed as a static site to GitHub Pages.

Live at <https://octopusdeploy.github.io/Library/pr-review/>.

## What it does

- Lists open pull requests on `OctopusDeploy/Library`.
- For each changed file, shows the **before/after side-by-side** in Monaco's
  `DiffEditor`. The before/after contents are fetched directly from
  `raw.githubusercontent.com` (a static CDN that does not count against the
  GitHub API rate limit), not reconstructed from the unified-diff patch.
- For step-template JSONs, surfaces one **tab per embedded script** that
  changed in the PR, each with its own side-by-side syntax-highlighted diff.
  Supported properties:
  - `Octopus.Action.Script.ScriptBody` (syntax from `Octopus.Action.Script.Syntax`)
  - `Octopus.Action.Terraform.Template`
  - `Octopus.Action.Terraform.VariableValues`
  - `Octopus.Action.CustomScripts.{PreDeploy,Deploy,PostDeploy}.{ps1,sh,csx,fsx,…}` —
    language inferred from the extension.

  Scripts that exist in both before and after but didn't actually change in
  this PR don't get a tab (no point looking at an unchanged diff).

## How it differs from Hyponome

| | Hyponome | PR Review |
|---|---|---|
| Runtime | ASP.NET Core (server) | Static SPA (browser only) |
| GitHub access | Octokit, server-side PAT | `fetch` to `api.github.com`, unauthenticated |
| Hosting | Docker container | GitHub Pages |
| Diff viewer | Ace + ace-diff | Monaco `DiffEditor` |
| UI | Bootstrap 3 + jQuery | React 18 + plain CSS |

## Authentication

None. The site uses the GitHub REST API unauthenticated, which is rate-limited to
**60 requests per hour per IP address**. Each PR detail view consumes roughly 3
requests (PR + files + occasionally the raw diff for files with omitted patches),
so casual browsing of ~15 PRs per hour fits comfortably.

When the limit is hit, the site renders an explanatory error state with the
reset time. There is no PAT prompt and no token storage — keeping the deployment
truly static and avoiding any browser-stored secrets.

## Local development

```sh
cd pr-review
npm install
npm run dev
```

Opens at `http://localhost:5173/Library/pr-review/`. Hot reload works as
expected via Vite.

Useful scripts:

| Script | Purpose |
|---|---|
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | Type-check, then build a production bundle into `dist/` |
| `npm run typecheck` | TS only, no emit |
| `npm run preview` | Serve the production build locally |

## Deployment

Pushes to `master`/`main` that touch `pr-review/**` or the workflow file run
`.github/workflows/pr-review-deploy.yml`, which builds the site and publishes
it to GitHub Pages.

**One-time setup** (only needed the first time):

1. In repo *Settings → Pages*, set **Source** to **GitHub Actions**.
2. Run the workflow once (push or *Run workflow* in the Actions tab).

The site lands at `https://octopusdeploy.github.io/Library/pr-review/`. If
you change the deployment path, also update `base` in `vite.config.ts` and
the `_site/pr-review` path in the workflow.

## Code layout

```
src/
├── main.tsx                    Entry — mounts <App/>.
├── App.tsx                     HashRouter + header + footer.
├── styles.css                  All app styling (CSS custom properties, dark mode).
├── routes/
│   ├── PullRequestList.tsx     Open PRs list.
│   └── PullRequestDetail.tsx   PR header + file panels.
├── api/
│   ├── github.ts               fetch-based client. Lists PRs/files via api.github.com,
│   │                           reads file contents from raw.githubusercontent.com.
│   └── types.ts                Hand-trimmed shapes for the endpoints we use.
├── lib/
│   ├── extractScript.ts        Pull every changed Octopus script out of a step-template
│   │                           JSON (ScriptBody, Terraform, custom scripts).
│   └── languageDetect.ts       Filename → Monaco language id; binary detection.
└── components/
    ├── PullRequestHeader.tsx   Title / branches / author.
    ├── FilePanel.tsx           Tabbed per-file panel (File diff + one tab per script).
    ├── ErrorState.tsx          Generic + rate-limit-aware error rendering.
    └── TimeAgo.tsx             Relative timestamps.
```

The repo target (`OctopusDeploy/Library`) is hardcoded in `src/api/github.ts`.
A fork that wants to point this at a different repo edits one constant.

## Why hash routing?

GitHub Pages is static hosting — any deep link like `/pulls/123` would 404 on
refresh. `HashRouter` keeps the route entirely in the URL fragment
(`#/pulls/123`), which the server never sees. Two-route SPA, internal tool,
zero extra deployment complexity.

## Known harmless console warning

Navigating from one PR to another sometimes logs:

> `Uncaught Error: TextModel got disposed before DiffEditorWidget model got reset`

This is a known race inside `@monaco-editor/react` where Monaco's lazy CDN
load completes after React has already unmounted the previous `DiffEditor`.
It's thrown asynchronously during teardown, doesn't affect any rendered UI,
and can be ignored. Each `DiffEditor` already gets a stable `key` per
`file.sha`/`file.filename` to force a clean remount, which suppresses the
worst of it; the remaining warning is upstream.

