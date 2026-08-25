# Trends page: value over time, monthly and yearly

Three PRs, in order. Each one ships something you can look at on a Render
preview; none of them touches fixtures.

The dashboard only shows a *snapshot*: today's net worth, one month-over-month
badge, and an 80×28px sparkline per card that is `aria-hidden` — decoration, not
information. Meanwhile `account_values` has been accumulating one row per
account per month since M4. The whole history is already in SQLite and nothing
reads it back.

`/trends` reads it back: a line chart of value over time, a bar chart of the
increase/decrease per period, summary tiles, and a breakdown table. Net worth is
the default view; chips filter to a single asset account.

---

## Shape of the data, and what "yearly" means here

`account_values.recorded_on` is **always the 1st of a month** — the grain is
monthly and nothing finer exists. `amount` is a **stock** (a balance at a
moment), not a flow, so summing or averaging twelve of them is meaningless.

So both time frames plot **monthly points**, and the toggle is a window, not a
rollup:

| Range | Window | Delta between points |
|---|---|---|
| `monthly` (default) | every month on record, capped at 36 | month over month |
| `yearly` | the trailing 12 months | month over month |

"Yearly" is a zoom level. The alternative — one point per calendar year, taken
from each year's last snapshot — was considered and rejected: with a household
that has been tracking for under two years it draws a two-point chart, and the
year label lies about which month it came from.

Two more decisions worth stating up front:

- **Total means net worth**, mortgage included, so the headline here matches the
  dashboard hero. Paying down the mortgage moves the line up, which is the
  behaviour you want from a growth chart.
- **The per-account chips list assets only** — they exclude credit cards *and*
  liabilities, the same set as `Allocation#asset_accounts`. The mortgage feeds
  the total but is not individually drillable. A footnote says so rather than
  leaving it to be discovered.

---

## Where the numbers come from

`Portfolio#total_as_of(date)` is already, exactly, "signed net worth at month
N". It owns the liability sign flip (`kind == "liability" ? -amount.abs : amount`),
the credit-card exclusion, and the loaded-aware lookup that keeps it N+1-safe
under `includes(:account_values)`. It is merely `private`.

`Trend` composes a `Portfolio` and calls it once per month. It never touches the
sign convention, and that holds for the single-account view too:
`Portfolio.new([ account ]).total_as_of(month)` returns that one account's
correctly-signed amount.

The only change to `Portfolio` is moving `def total_as_of` above the `private`
keyword. Visibility only — `test/models/portfolio_test.rb` stays byte-identical.

**Do not move `signed_amount` / `amount_on` onto `Account`.**
[`domain-products.md`](domain-products.md) claims both names for
`Products::Base` (`amount_on(date)`, `net_worth_contribution`), so `Account` is
the wrong final home and that PR would delete them again. `Trend`'s entire
coupling to the sign convention is one `total_as_of` call, which the products
refactor rewires in a single line — add a `Trend` row to that plan's
"rewire every caller" table when it lands.

---

## Milestone 1 — the page, and the monthly total line

One range, one view, no filters. Ships a working `/trends`.

**New**

| File | Holds |
|---|---|
| `app/models/trend.rb` | `Point = Data.define(:month, :label, :tick, :amount, :delta, :change)`; `points` / `amounts` / `any?` / `chartable?` / `flat?` |
| `app/controllers/trends_controller.rb` | `show` only |
| `app/helpers/chart_helper.rb` | `trend_line_points`, `trend_area_points`, `chart_value_y` |
| `app/helpers/trends_helper.rb` | `signed_amount_label`, `delta_class`, `trend_subject` |
| `app/views/trends/show.html.erb` | `.wrap` → `.masthead` → sections → `.footnote`, the dashboard shell |
| `app/views/trends/_line_chart.html.erb` | `<svg viewBox="0 0 640 180" role="img" aria-label=…>` |
| `app/views/trends/_breakdown.html.erb` | `<table class="trend-table">` |
| `app/assets/stylesheets/components/trends.css` | all new styling, tokens only |
| `test/models/trend_test.rb`, `test/helpers/chart_helper_test.rb`, `test/controllers/trends_controller_test.rb` | see below |

**Modified**

- `config/routes.rb` — `resource :trends, only: [ :show ]`. Singular, mirroring
  `resource :value_entry`: there is one trends screen, not a collection.
- `app/models/portfolio.rb` — the `total_as_of` visibility move described above.
- `app/views/layouts/application.html.erb` — add `"components/trends"` to the
  `stylesheet_link_tag` list. It enumerates every sheet; there is no `@import`,
  and `application.css` was deleted in the stylesheet split — do not recreate it.
- `app/views/dashboard/index.html.erb` + `components/hero.css` — a `.hero-link`
  under the net-worth badge: "See how it's trending →".
- `db/seeds.rb` — `(0..35)` months instead of `(0..5)`, and re-tune
  `STARTING_AMOUNTS`, which now describes the value **36 months ago** rather
  than 6: Managed TFSA `27_000`, Self-directed TFSA `12_000`, RRSP `39_000`,
  Crypto `2_100`, Everyday chequing `3_800`, Home mortgage `-350_000`. Still
  idempotent — `find_or_create_by!(account:, recorded_on:)` only ever adds rows.

**The core of `Trend`**

```ruby
@accounts  = Array(accounts).reject { |a| a.kind == "credit_card" }
@portfolio = Portfolio.new(@accounts)

# Only months that actually have a snapshot — no gap filling, so a skipped
# month never renders as a phantom dip to zero.
def recorded_months
  @accounts.flat_map { |a| a.account_values.map(&:recorded_on) }.uniq.sort
end

def points
  # amount: @portfolio.total_as_of(month); delta and change vs. the prior point
end
```

The credit-card reject duplicates `Portfolio`'s filter so the PORO is safe
standalone — the same defensive posture `Allocation` takes.

**One quirk to design around.** `sparkline_points` forces `span = 1.0` for a
perfectly flat series, so every `y` lands on the *bottom* edge. Invisible at
28px, obviously wrong at 180px. Do **not** fix it there —
`sparkline_helper_test.rb` asserts that behaviour and the dashboard cards depend
on it. `_line_chart` branches on `trend.flat?` and draws a centred `<line>`
instead.

**Tests.** An account with no values → `points == []`. Chronological signed
points from fixtures (May 2026 → `42_000`, June → `-274_500`). First point's
`delta` and `change` are nil. A liability stored with a *positive* amount still
contributes negatively. Credit cards excluded even when passed in directly.
`trend_line_points` returns `[]` below two amounts. `chart_value_y(0, …)` is nil
for an all-negative series and inside the box when the series straddles zero.
`GET /trends` is 200 with `svg.trend-line[role=img]` and a caption'd table.

---

## Milestone 2 — increase/decrease bars, and the range toggle

The other half of the ask, plus the two time frames.

**New**

- `app/views/trends/_delta_chart.html.erb` — `viewBox="0 0 640 120"`,
  `role="img"`, a dashed `<line class="delta-baseline">`, and one
  `<rect class="delta-bar delta-bar-up|down|flat">` per period. Each rect wraps a
  `<title>` reading `"June 2026: +$4,200"` — a native hover tooltip, the same
  trick `_allocation` uses with `title=`, and still no JavaScript.
- `app/views/trends/_summary.html.erb` — `.trend-stats` grid of four tiles:
  **Now** (`formatted_amount` + `change_badge`, reusing `.badge-up` /
  `.badge-down` from `cards.css`), **Change over N months**, **Best month**,
  **Worst month**. With a single point, one tile plus "One month recorded so far".
- `app/views/trends/_filters.html.erb` — the range chip group for now (accounts
  arrive in M3). Plain `link_to`s, so URLs stay shareable, the back button works,
  and Turbo Drive handles the swap.
- `test/helpers/trends_helper_test.rb`.

**Extended**

- `ChartHelper` — `Bar = Data.define(:x, :y, :width, :height, :direction)`,
  `delta_bars(deltas, …)`, `delta_baseline_y(deltas, …)`. The math:
  `up = [ deltas.max, 0 ].max`, `down = [ deltas.min, 0 ].min.abs`,
  `span = up + down` (→ `1.0` when zero), `baseline_y = pad + (up / span * inner_h)`.
  A bar's height is `delta.abs / span * inner_h`; positives get
  `y = baseline_y - h`, negatives `y = baseline_y`. Exactly-zero deltas get a 2px
  `:flat` stub so they still read on the baseline. Keep the span helper `private`
  in the module so it does not leak into the view context as a callable helper.
- `Trend` — `RANGES = %w[monthly yearly].freeze`,
  `MONTHS_SHOWN = { "monthly" => 36, "yearly" => 12 }.freeze`,
  `Trend.range_for(value)` (whitelist; anything unknown → `"monthly"`), `deltas`,
  `truncated?`, and `Summary = Data.define(:first, :last, :delta, :change, :best, :worst)`.
  **Deltas are computed across the full series, then the window is trimmed**, so
  the leftmost visible bar is a real change rather than a nil.
- `TrendsController` — `@range = Trend.range_for(params[:range])`.
- `TrendsHelper` — `trend_range_note`, `trend_line_label`, `trend_delta_label`,
  `trend_filter_path(range:, account:)`. The aria-label builders live in the
  helper, not inline in ERB, so they are testable and the partials stay readable.
- `db/seeds.rb` — a fixed drift cycle, so the delta chart is not 36 identical
  green bars. A flat 1.5%/month compounded makes *every* delta positive, which
  fails to demo the feature. No `rand` — seeds must stay reproducible so
  re-seeding is a genuine no-op:

  ```ruby
  MONTHLY_DRIFT = [ 0.021, 0.014, -0.008, 0.019, 0.006, -0.015,
                    0.024, 0.011, -0.004, 0.017, 0.009, 0.013 ].freeze
  ```

  Compound with `MONTHLY_DRIFT[(i + offset) % 12]`, where `offset` is the
  account's index in `STARTING_AMOUNTS` so accounts do not move in lockstep, and
  roughly triple the drift for `crypto` so one series is visibly volatile. The
  mortgage keeps its linear `start + (i * 900)` as a clean monotonic
  counterexample — $31,500 paid down across the window.

**Tests.** Bar count equals delta count and x increases left to right. A
positive bar's bottom edge sits on the baseline; a negative bar's top edge does.
`delta_bars([])` and `delta_bars([0, 0, 0])` return `[]`. `delta_baseline_y` is
at the bottom when every delta is positive, the top when every one is negative,
strictly between when mixed. `yearly` returns at most 12 points ending on the
newest month; `monthly` caps at 36 given 40 months of data; trimming preserves
deltas, so `points.first.delta` is **not** nil; both ranges agree below 12
months. `summary` is nil below two points and otherwise spans the *visible*
window. `range_for` rejects `nil`, `""`, `"YEARLY"` and `"'; DROP TABLE"`.

---

## Milestone 3 — the per-account filter

**Modified**

- `TrendsController` — `@filterable = @accounts.reject(&:mortgage?)`, and:

  ```ruby
  # Match against the already-loaded list. An unknown, non-numeric, or
  # non-filterable id selects nothing and we fall back to the total view —
  # no find, no 404, no dynamic SQL.
  def selected_account
    id = params[:account_id]
    return nil if id.blank?

    @filterable.detect { |account| account.id == id.to_i }
  end
  ```

  Silent fallback beats a 404 here: a bookmark that outlived its account should
  still show something useful.

  | Input | Result |
  |---|---|
  | absent | total (net worth) view |
  | a valid asset id | that account |
  | unknown, non-numeric, mortgage, or credit-card id | 200, total view |

- `_filters.html.erb` — a second chip group: "All accounts" plus one chip per
  filterable account, each preserving the current `range`. `class_names` is
  built into Rails; the active chip carries `aria-current="page"`.
- `show.html.erb` — the subject in the masthead subtitle, the `.empty` state for
  an account with no snapshots, and the footnote about the mortgage.
- `app/views/dashboard/index.html.erb` — a `Trend` link in each account card's
  `.card-actions`, before "Edit". This is what makes the filter discoverable.
  Neither dashboard edit breaks an existing assertion: `.reminder a, count: 0`
  is scoped to `.reminder`, and the Edit/Delete assertions match by `href`.
- `PLAN.md` — add this as Milestone 12; renumber the MCP server to 13.

**Tests.** The subject is named in the subtitle and the June row reads `$43,500`
rather than `-$274,500`. `?account_id=999999`, `abc`, a credit-card id and the
mortgage id all return 200 on the total view. The mortgage is absent from the
chips while `managed_tfsa` is present. Chips preserve the other param
(`assert_select "a[href=?]", trends_path(range: "yearly", account_id: …)`). An
account with no values renders `.empty` and zero `svg`. A single-value account
renders no `polyline`, one table row, and "—" in the Δ cells. Two new
`dashboard_controller_test` assertions cover the hero and card links.

---

## Notes that apply to all three

**Styling.** One new `components/trends.css`, every value drawn from
`tokens.css`, so dark mode needs no extra rules. `.chip` / `.chip-on`
(`--accent` + `--accent-ink`), `.trend-chart` (`--card` / `--radius` /
`--shadow`), `.trend-line { color: var(--violet) }` matching `.sparkline`,
`.delta-bar-up|down|flat` → `--green` / `--red` / `--line`, `.trend-table` with
`tabular-nums` and `border-bottom: 1px solid var(--line)`. Geometry lives in SVG
attributes, so unlike `_allocation` there are **no inline `style=` attributes**
anywhere in the new code. The 640-wide viewBoxes sit in a 720px `.wrap`, so
`width: 100%; height: auto` scales about 1:1 under the default
`preserveAspectRatio` — do not set `preserveAspectRatio="none"`, it distorts
stroke width.

**Accessibility.** `role="img"` + `aria-label` on both charts, mirroring
`.alloc-bar`. Deliberately **not** `aria-hidden`: that is right for the tiny card
sparkline, where the number sits beside it, and wrong here, where the chart is
the content. The breakdown table is the text alternative and runs **oldest →
newest, matching the charts** — an alternative that reads in a different order
than the graphic it replaces is a defect, which outweighs "newest first is more
convenient". The summary tiles already put the latest number above the fold.

**Gap semantics.** A month counts an unrecorded account as **$0** — identical to
what the dashboard hero already does. Honest for "the account did not exist
yet", slightly pessimistic for "I skipped a month". Carry-forward is a
reasonable follow-up, but it should change `Portfolio` too rather than letting
this page disagree with the dashboard. The footnote states the rule.

**Do not add or edit fixtures.** Every obvious addition breaks an existing test:
2025 rows on `managed_tfsa` break `account_value_test`'s chronological
assertion; values on `rrsp` break the dashboard's em-dash test, `account_test`'s
nil `current_amount`, and `allocation_test`'s single slice; a new account
fixture breaks the hard-coded `-274,500` in `portfolio_test` and
`dashboard_controller_test`. Build multi-month data **inline per test**, using
the `AccountValue.delete_all` + create pattern already in
`test/models/portfolio_test.rb#seed_month_values`.

**No system test.** The page is links and server-rendered SVG, and
`test/application_system_test_case.rb` does not exist in this repo — scaffolding
it is beyond these milestones. `test/system/.keep` must survive regardless
(AGENTS.md §1).

**No Stimulus.** Chips are `link_to`s, which buys shareable URLs, a working back
button and Turbo Drive morphs for free. The honest counter-argument is that a
household with fifteen accounts gets a horizontal scroll strip; the zero-JS
upgrade for that is a `form_with method: :get` around a `<select name="account_id">`
plus a visible "Show" button. Still no build step, still no system-test
scaffolding.

**Risk flags.** `rubocop-rails-omakase` disables `Metrics/*` and
`Style/Documentation`, so the cops that actually trip are
`Style/StringLiterals` (double quotes), `Layout/SpaceInsideArrayLiteralBrackets`
(`[ :show ]`, `[ deltas.max, 0 ].max`; `%w[…]` and `%i[…]` are exempt) and
`Style/MutableConstant` (`.freeze` on `RANGES`, `MONTHS_SHOWN`,
`MONTHLY_DRIFT`). Use regular `def`s — endless methods appear in
`domain-products.md` but in no shipped file. Brakeman has no new surface by
construction: no `Account.find`, no interpolated `where`, no `permit`, no `raw`
or `html_safe`, no `redirect_to params[…]`; remember AGENTS.md §9, where an
outdated Brakeman exits 5 with zero findings. `includes(:account_values)` in the
controller is load-bearing — `Trend` reads the association in memory, so without
it this is an N+1. `total_as_of` is O(accounts) per month, so a 36-point trend
is O(36 × accounts) in-memory comparisons and no extra queries.

---

## Verifying a milestone

```bash
bin/rails db:prepare && bin/rails db:seed
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

Then look at it (AGENTS.md, "Taking a screenshot"):

```bash
bin/rails server -p 3005 -b 127.0.0.1 &   # wait for /up to return 200
node script/screenshot.js http://127.0.0.1:3005/trends tmp/trends.png 420 1400
node script/screenshot.js "http://127.0.0.1:3005/trends?range=yearly" tmp/trends-yearly.png 420 1400
```

- `/trends` shows net worth rising across 36 months, mixed green/red delta bars,
  four stat tiles, and a 36-row table.
- `?range=yearly` narrows to 12 points; axis labels and table shrink to match.
- Clicking an account chip keeps the range; clicking a range chip keeps the account.
- `?account_id=999999`, `?account_id=abc` and the mortgage's id all render the
  total view with a 200.
- Add an account via `/accounts/new` (no snapshots yet) and filter to it — the
  `.empty` state renders instead of the charts.
- Toggle OS dark mode: cards, chips and chart strokes all stay legible.
- The dashboard hero and each account card link through to the right filtered URL.
