# Portfolio Tracker — Plan

A calm, playful, **self-hosted** personal-finance dashboard for a Canadian
household. It pulls all your accounts, investments, liabilities and credit-card
perks into one place so you can answer the questions that are hard to answer
when everything is scattered across Wealthsimple, your bank, and a drawer full
of credit cards:

- Am I playing it too safe (or too risky) in a given account?
- Should I contribute more to my RRSP / TFSA / FHSA this year?
- Should I pay down the mortgage faster given its rate?
- Should I divest some work stock given my overall picture?
- Which accounts should I even open? (Canadian-specific, not US advice.)

The tone is deliberately light — nobody enjoys doing personal finances, so the
UI leans into the [hey.com](https://hey.com) feeling: warm colours, rounded
cards, friendly copy, one clear thing per screen.

---

## Guiding constraints (from the product brief)

| Constraint | Decision |
|---|---|
| **Local-first** | All data stays on hardware you control. Deployable to a **Raspberry Pi 2B** via Docker. |
| **Dead-simple stack** | **Ruby on Rails + SQLite**. No separate services. |
| **No JS build step** | Frontend uses **Hotwire (Turbo + Stimulus) over import maps** only. Newest browsers only. |
| **Testable per-PR from a phone** | Every PR deploys to **Render** (see `render.yaml`) with **seeded test data**, so it can be poked from a phone as we build. |
| **Playful & simple** | hey.com-style warm UI; the dashboard shows one clear number per product. |
| **Future** | An **MCP server** (after the dashboard is done) so an LLM can answer questions and drive insights over the data. |

### Tech stack
- **Rails 8.1**, Ruby 3.3
- **SQLite** (primary + Solid Queue/Cache/Cable databases)
- **Hotwire**: Turbo + Stimulus via `importmap-rails` (zero bundling)
- **Propshaft** asset pipeline, plain CSS
- **Puma** (Thruster in the Pi/Kamal path)
- **Minitest** for tests
- Deploy: **Docker** everywhere — **Kamal** → Raspberry Pi (persistent SQLite),
  **Render** → throwaway per-PR test deploys (ephemeral SQLite, re-seeded each deploy)

---

## Domain model (target)

Built up incrementally across the milestones below.

- **Account** — one product you hold. Fields: `name` ("Managed TFSA"),
  `institution` ("Wealthsimple"), `kind` (`tfsa`, `rrsp`, `resp`, `fhsa`,
  `non_registered`, `crypto`, `cash`, `liability`, `credit_card`),
  plus a `managed`/`self_directed` style flag later.
- **AccountValue** — a monthly snapshot of an account's worth:
  `account_id`, `recorded_on` (defaults to the 1st), `amount`. This is the
  spine of every "+5% vs last month" number and every trend line.
- **Liability details** (for `kind: liability`, e.g. a mortgage): `interest_rate`,
  `term_months`, `original_principal`, optionally amortization.
- **CreditCard details** (for `kind: credit_card`): perks/notes only —
  **no balances tracked** (annual fee, rewards, benefits, renewal date).

Credit cards are intentionally value-less: the point is to remember what you
have and why, not to reconcile statements.

---

## Dashboard behaviour (target)

- Super simple: each **product** shows its **current value** and a **% change**
  (e.g. `+5%`), **defaulting to a comparison with last month's snapshot**.
- A **net-worth** total (assets minus liabilities).
- On the **1st of each month**, the user is nudged to **enter this month's
  account values** on a dedicated **value-entry page**.
- Later: risk/allocation views and rebalancing nudges
  ("you're too conservative in your managed TFSA — consider VFV"),
  mortgage-vs-invest and divestment prompts.

---

## Deploy targets

- **Raspberry Pi 2B (real, persistent):** `Dockerfile` + Kamal
  (`config/deploy.yml`). SQLite lives on a persistent volume under `storage/`.
- **Render (throwaway test, per-PR):** `render.yaml` blueprint, Docker runtime,
  auto-deploys on push. SQLite is ephemeral and **re-seeded on every deploy**,
  so each PR shows a clean, predictable dataset you can test from your phone.

---

## Milestones

Each milestone is a self-contained, **deployable** PR. Run `bin/rails test`
before opening each PR; the Render preview must boot with seed data.

### ✅ Milestone 1 — Deployable scaffold + seed (this PR)
- Rails 8 app, SQLite, Hotwire via import maps (no JS build).
- `Account` model (`name`, `institution`, `kind`) with validations.
- Warm hey.com-style dashboard listing seeded accounts, each with an emoji,
  institution, and kind tag; a monthly check-in reminder banner.
- Idempotent seed with a realistic Canadian Wealthsimple-shaped dataset.
- `render.yaml` (Render test deploy) + stock `Dockerfile` (Pi/Kamal).
- Model + controller tests green.

### Milestone 2 — Account values & the "+5% vs last month" dashboard
- `AccountValue` model (monthly snapshots) + association.
- Dedicated **value-entry page** (Turbo-driven) to record this month's numbers.
- Dashboard shows **current value per product** and **% change vs last month**,
  plus a **net-worth** total (assets − liabilities).
- Monthly reminder becomes real (highlights when the current month has no
  values yet).
- Seed extended with several months of snapshots so trends are visible.

### Milestone 3 — Liabilities (mortgage) & credit-card perks
- Liability details for mortgages: interest rate, term, principal.
- Credit-card records: perks/fees/benefits only, **no balances**.
- Net worth correctly subtracts liabilities.
- Simple "manage accounts" CRUD (add/edit/delete) via Turbo.

### Milestone 4 — Trends, allocation & risk
- Per-account and total trend views over time (server-rendered charts, no JS build).
- Asset allocation / concentration view; gentle rebalancing nudges.
- Canadian-flavoured account-opening suggestions (TFSA/RRSP/FHSA room hints).

### Milestone 5 — MCP server
- Expose the data (read-only first) via an MCP server so an LLM can answer
  "should I pay more into my mortgage?"-style questions over real numbers.

---

## Running locally

```bash
bin/setup            # install gems, prepare + seed the dev DB
bin/rails server     # http://localhost:3000
bin/rails test       # run the suite
```

## Deploying

- **Render:** connect the repo; Render reads `render.yaml` and auto-deploys each
  push. Fresh, re-seeded SQLite every deploy.
- **Raspberry Pi:** configure `config/deploy.yml` and run `bin/kamal setup`.
