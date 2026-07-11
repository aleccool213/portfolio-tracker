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

Milestones are **deliberately small** — each is a single, self-contained,
**deployable** PR that a focused agent (e.g. Sonnet) can complete accurately in
one sitting. Each one lists exactly what to build, which files it touches, and
what to test.

**Rules for every milestone:**
- Keep it to the files listed. Don't refactor unrelated code.
- Add/extend tests as described; `bin/rails test` must be green.
- Keep `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, and
  `bin/importmap audit` clean (this repo's CI runs all four).
- No JavaScript build step — Hotwire (Turbo/Stimulus) over import maps only.
- The Render preview must still boot with seed data. If a milestone adds a
  model, extend `db/seeds.rb` so the dashboard has something to show.
- Match the existing warm hey.com style (reuse the CSS variables and card
  patterns already in `app/assets/stylesheets/application.css`).

---

### ✅ Milestone 1 — Deployable scaffold + seed (done)
- Rails 8 app, SQLite, Hotwire via import maps; `Account` model; warm dashboard
  listing seeded accounts; `render.yaml` + `Dockerfile`; tests green.

---

### ✅ Milestone 2 — `AccountValue` model (data only) (done)
**Goal:** a monthly-snapshot model, with no UI beyond showing the latest value.
- **Migrate:** `AccountValue` — `account:references`, `recorded_on:date`,
  `amount:decimal` (precision 12, scale 2). Add a unique index on
  `[account_id, recorded_on]`.
- **Model `AccountValue`:** `belongs_to :account`; validate presence of
  `recorded_on` and `amount`; `amount` numericality (can be negative for
  liabilities). Default scope or scope `chronological` ordered by `recorded_on`.
- **Model `Account`:** `has_many :account_values, dependent: :destroy`.
  Add `latest_value` (most recent by `recorded_on`) and
  `current_amount` (its `amount`, or `nil`).
- **Dashboard:** show each account's `current_amount` (formatted `$`) on its
  card; "—" when no value yet. Add a `number_to_currency`-based helper.
- **Seed:** give every non-liability account ~6 monthly snapshots
  (e.g. Jan–Jun of the current year), gently growing; the mortgage a shrinking
  balance. Keep idempotent (`find_or_create_by` on account + `recorded_on`).
- **Tests:** `AccountValueTest` (validations, association), `AccountTest`
  additions (`latest_value`, `current_amount`), dashboard shows a dollar amount.
- **Files:** migration, `app/models/account_value.rb`, `app/models/account.rb`,
  `app/views/dashboard/index.html.erb`, a helper, `db/seeds.rb`, fixtures + tests.

### ✅ Milestone 3 — Value-entry page (done)
**Goal:** a dedicated page to record this month's value for each account.
- **Route:** `resource :value_entry, only: [:show, :create]` (or a
  `MonthlyValuesController`). Link to it from the dashboard reminder banner.
- **Page:** one row per non-credit-card account, each with a number field
  pre-filled with the current month's value if it exists. Submitting upserts an
  `AccountValue` per account for `recorded_on = Date.current.beginning_of_month`.
- **Turbo:** submit via a normal Turbo form; on success redirect to the
  dashboard with a friendly flash ("Saved this month's values 🎉").
- **Tests:** posting values creates/updates `AccountValue` rows for the current
  month; re-posting updates rather than duplicates.
- **Files:** route, one controller, one view, a small form partial, tests.

### ✅ Milestone 4 — "+5% vs last month" badges (done)
**Goal:** show month-over-month change per account on the dashboard.
- **Helper/PORO `MonthlyChange`:** given an account, compare the current
  month's value to the previous month's; return `{ pct:, direction: }`.
  Handle missing prior month (return nil → render nothing) and zero prior
  (avoid divide-by-zero).
- **Dashboard:** render a small badge next to each value: green `▲ +5%`,
  red `▼ −3%`, muted when flat. Add `.badge`, `.badge-up`, `.badge-down` CSS.
- **Tests:** the change calc (positive, negative, missing prior, zero prior);
  a dashboard test asserting a badge renders for an account with two months.
- **Files:** a calc class under `app/models/` or `app/services/`, dashboard
  view, CSS, tests.

### Milestone 5 — Net-worth summary + real monthly reminder
**Goal:** a headline net-worth number and a reminder that knows if you're behind.
- **Calc:** total net worth = sum of current amounts, treating `liability`
  kinds as negative. Put it in a helper or a small `Portfolio` PORO.
- **Hero:** replace the "accounts tracked" count with formatted net worth and a
  net month-over-month % change.
- **Reminder logic:** show the "time for a check-in" banner **only when** the
  current month has no values for one or more asset accounts; otherwise show a
  calm "you're all caught up ✅" state.
- **Tests:** net-worth calc (assets minus liabilities); reminder shows when a
  current-month value is missing and hides when all present.
- **Files:** helper/PORO, dashboard view, tests.

### Milestone 6 — Manage accounts (CRUD)
**Goal:** add, edit, and delete accounts from the UI.
- **Resource:** `resources :accounts` (`new/create/edit/update/destroy`;
  `index` can redirect to the dashboard). `kind` is a select of `Account::KINDS`.
- **UI:** an "Add account" button on the dashboard; edit/delete on each card via
  Turbo (confirm on delete). Reuse the card style; keep forms simple.
- **Strong params, validations surfaced** in the form.
- **Tests:** create, update, destroy happy paths; invalid create re-renders with
  errors.
- **Files:** route, `AccountsController`, `new/edit/_form` views, dashboard
  edit/delete affordances, tests.

### Milestone 7 — Mortgage / liability details
**Goal:** capture the numbers a mortgage decision needs.
- **Migrate:** add nullable columns used only by `liability` accounts —
  `interest_rate:decimal`, `term_months:integer`, `original_principal:decimal`.
- **Model:** validate these are present/positive **only when**
  `kind == "liability"`; ignore otherwise. Helper `mortgage?`.
- **UI:** show rate + term on liability cards; expose the fields in the account
  form when `kind` is liability (progressive — fine to always show for now).
- **Seed:** give the mortgage a realistic rate/term/principal.
- **Tests:** conditional validations; card renders the rate.
- **Files:** migration, `app/models/account.rb`, account form + dashboard views,
  seed, tests.

### Milestone 8 — Credit-card perks (no balances)
**Goal:** a place to remember every card and why you have it.
- **Migrate:** add nullable columns for `credit_card` accounts —
  `annual_fee:decimal`, `perks:text`, `renewal_on:date`. **No balance field.**
- **Model:** these apply only to `kind == "credit_card"`; helper `credit_card?`.
- **UI:** a "Cards" section/page listing each card with its perks, annual fee,
  and renewal date. Explicitly **not** part of net worth.
- **Seed:** flesh out the Aeroplan card and add one or two more.
- **Tests:** cards render their perks; cards are excluded from net worth.
- **Files:** migration, model, a cards partial/page, seed, tests.

### Milestone 9 — Per-account trend (server-rendered)
**Goal:** a small history chart per account, no JS build.
- **Sparkline:** render an inline `<svg>` from an account's `account_values`
  (a helper that maps values to points). No charting library, no import.
- **UI:** show the sparkline on each dashboard card (or an account show page);
  empty state when fewer than two data points.
- **Tests:** the point-generation helper (scaling, ordering); an svg renders
  when there are ≥2 values.
- **Files:** a helper, a `_sparkline` partial, view wiring, tests.

### Milestone 10 — Allocation & gentle nudges
**Goal:** answer "am I diversified / too safe?" at a glance.
- **Calc:** totals by `kind` and each kind's % of assets. Flag concentration
  (any single account > 50% of assets, or cash > some threshold).
- **UI:** a simple allocation breakdown (stacked bar or labelled list) plus
  friendly nudge copy ("You're heavy in cash — consider investing some").
- **Tests:** allocation math; a nudge appears for a concentrated fixture.
- **Files:** a calc class, a view section/partial, tests.

### Milestone 11 — Canadian account suggestions
**Goal:** lightweight, Canadian-specific "what should I open?" hints.
- **Data:** a small static table of account types (TFSA/RRSP/FHSA/RESP) with
  one-line "who it's for" copy and 2026 contribution-room notes (hard-coded,
  clearly dated — not tax advice).
- **UI:** show suggestions for registered accounts the user doesn't yet have.
- **Tests:** suggestions exclude kinds the user already holds.
- **Files:** a constant/PORO, a view partial, tests.

### Milestone 12 — MCP server (read-only)
**Goal:** let an LLM answer questions over the real numbers.
- Expose read-only tools (list accounts, get values, net worth, allocation)
  via an MCP server. Design after the dashboard is complete; spec this milestone
  in more detail when we reach it.

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
