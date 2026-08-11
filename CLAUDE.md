# Norelo website

Static site, deployed to Vercel from GitHub. A push to `main` publishes it live.

## Hard rules, do not break these

- **Single self-contained `index.html` files only.** No frameworks, no build tools, no npm,
  no bundlers. Plain HTML, CSS and vanilla JS. The only external dependency allowed is the
  Supabase client already loaded in the horaire app.
- **Never use em dashes anywhere.** Not in UI text, code, comments, or commit messages.
  Use commas or periods. Check with a grep before finishing.
- **Everything is bilingual FR and EN.** The `T` object plus `data-i` attributes in the apps,
  and `LAND` plus the render functions on the landing page. Anything you add needs both
  languages, in sync. Default language is French.
- **Keep the existing visual design and behavior.** Make changes surgical. Do not restyle
  and do not remove features.
- Copyright year is 2026. Response time shown to visitors is 24h.

## What each file is

| Path | What it is |
| --- | --- |
| `index.html` | Marketing site. |
| `gestion-demo/index.html` | Public interactive demo of the schedule manager. Uses a **mock** Supabase client (`makeMock()`, an in-memory `DB` object). There is no real backend here. Also holds the marketing landing hero shown before login. |
| `horaire/index.html` | **Production** schedule app. Real Supabase backend. |
| `horaire/sql/` | Copy-paste SQL migrations. Excluded from the deploy by `.vercelignore`. |
| `party/index.html` | Party game. Bump the footer version badge on every change. |
| `legal/index.html`, `previews/`, `inspiration/`, `prospects/` | Other pages. |

## horaire, the production app

Real Supabase: auth, Row Level Security, tables `profiles`, `shifts`, `time_off`,
`paid_weeks`, `backups`, `audit_log`. An edge function `quick-api`. Triggers `guard_ot`,
`guard_ot_status`, `sync_ot_status`, `guard_timeoff`. SQL helpers `is_manager()` and
`qc_today()`.

**Schema changes are applied by hand by the owner in the Supabase SQL Editor.** So every
database change ships as a separate copy-paste `.sql` file in `horaire/sql/`, numbered, with
the run order stated. Never assume you can run a migration yourself. The `quick-api` edge
function lives in Supabase and is not in this repo, so you cannot edit it. Prefer an RLS
policy over a new edge function action.

Bump `APP_VERSION` in `horaire/index.html` on each release. It shows in the footer and is how
the owner confirms a deploy landed.

## Payroll and overtime model, both apps

- Worked hours = shift length minus a 30 minute lunch, for non-managers, when lunch applies.
- Regular = `min(worked, 8)`. Overtime = hours beyond 8.
- Overtime is paid a flat **16 $/h** and only when approved.
- Overtime carries `ot_status`: `pending`, `approved` or `denied`. `ot_approved` stays the
  only flag payroll reads, so approved is paid and both pending and denied are unpaid.
  Editing a day's hours resets it to `pending`.
- Days off are excluded from all totals.
- The Approbations tab has sub-tabs, each with its own pending count badge.

**Do not change the payroll math or the RLS security model without asking the owner first.**

## Before you finish

- Syntax-check the inline JS of every file you edited. Extract the `<script>` block and run
  it through `new vm.Script(...)` in node.
- Grep for em dashes, confirm zero.
- Confirm the FR and EN dictionaries have identical key sets, and that no key is referenced
  in code but missing from the dictionaries.
- Give the owner manual test steps for anything user-facing.

## Git

The owner owns git. Do not commit or push unless asked, because a push to `main` deploys
straight to production.
