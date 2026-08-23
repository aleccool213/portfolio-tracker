# Domain products instead of a god `Account`

A design for concentrating household-finance behaviour in typed product classes, so mortgages, credit cards, and valued investments stop leaking `kind ==` checks into controllers and calc POROs.

This is a **follow-on architecture**, not a rewrite of the open stack. Land remaining feature PRs (and restack CSV) first; then add a dedicated domain-types PR on top. Do **not** implement wrappers, schema, or controller refactors in the same change as landing this note.

---

## Open PR stack (when this was written)

```
master (M7 mortgage details, merged)
  └─ #13 M8 credit-card perks
       └─ #14 M9 sparklines
            └─ #15 M10 allocation + nudges
                 └─ #16 M11 Canadian suggestions

#22 M12 CSV import  — parallel, currently based on older master
```

The tip of the feature stack is the right picture of the domain: one `accounts` table, a `kind` string that mixes tax wrappers with product types, and behaviour scattered across `Account`, `Portfolio`, `Allocation`, `AccountSuggestion`, `ValueEntriesController`, `DashboardController`, `PortfolioCsvImport`, and the dashboard/form views.

---

## Diagnosis

`Account.kind` is doing two unrelated jobs:

| Axis | Values | What it actually is |
|---|---|---|
| **Product type** | `liability`, `credit_card`, (implicit) everything else | What *kind of thing* the household holds |
| **Tax sleeve / wrapper** | `tfsa`, `rrsp`, `resp`, `fhsa`, `non_registered`, `crypto`, `cash` | How a *valued asset* is parked |

Because those axes share one field, every new rule becomes `if account.kind == ...` at the call site:

- `Portfolio` excludes credit cards, then special-cases liabilities as `-amount.abs`
- `Allocation` excludes credit cards *and* liabilities, then groups remaining rows by `kind`
- `ValueEntriesController` repeats `where.not(kind: "credit_card")`
- `DashboardController` splits `@cards` / `@value_accounts` by `credit_card?`
- `PortfolioCsvImport` refuses balances when `kind == "credit_card"`
- `Account` validations are `if: :mortgage?`, and `mortgage?` is just `kind == "liability"`
- The account form always shows mortgage fields *and* (on the stack) credit-card fields
- Seeds store mortgage snapshots negative; `Portfolio` also abs-then-negates — two places own the sign convention

`Portfolio` / `Allocation` are already the right shape (small POROs). The missing seam is **the product**, not another calculator.

A terminology clash to settle: credit cards are easy to think of as “variants of a liability.” In this app they are **not**. `PLAN.md` and M8 treat them as perk records with **no balance and no net-worth effect**. Mortgages *are* liabilities (valued, they reduce net worth). Keep that split; otherwise every net-worth and value-entry rule gets a special case.

---

## Domain language

Use these terms going forward (candidate `CONTEXT.md` entries, no implementation):

**Product**:
Something the household holds and the dashboard can show. Identity is name + institution.
_Avoid_: Account as the universal noun for cards and mortgages (keep `Account` as the ActiveRecord table for now).

**Valued product**:
A product with monthly `AccountValue` snapshots. Assets and liabilities are valued; credit cards are not.

**Asset**:
A valued product that *increases* net worth (TFSA, RRSP, cash, crypto, non-registered). Its `kind` is a tax sleeve / asset class, not a product type.

**Liability**:
A valued product that *decreases* net worth. Sign is owned here: contribution is always `-amount.abs`.

**Mortgage**:
A liability with rate, term, and original principal. The current app has only this subtype; `kind == "liability"` should not stay forever aliased to “is a mortgage.”

**Credit card**:
A product that stores perks, annual fee, and renewal. Not valued, not in net worth, not in allocation, not in monthly check-in.
_Avoid_: calling it a liability in this codebase.

**Trackable**:
“Gets a row on the value-entry page / counts for `needs_check_in?`.” Equivalent to *valued product*.

---

## Recommended approach: wrap the row, don’t STI it yet

Keep the `accounts` table and ActiveRecord `Account` as **persistence**. Introduce a small product hierarchy that **wraps** an `Account` and owns behaviour.

```
Account (AR: name, institution, kind, extra columns, has_many values)
    │
    ▼
Products.wrap(account)
    ├── Products::Asset        # tfsa/rrsp/cash/…  (kind = sleeve)
    ├── Products::Liability    # signed net-worth, monthly values
    │     └── Products::Mortgage
    └── Products::CreditCard   # perks only
```

Rails already puts calc POROs in `app/models/` (`Portfolio`, `Allocation`, `MonthlyChange`). Keep the new types there so Zeitwerk stays boring:

```
app/models/products.rb              # wrap() factory
app/models/products/base.rb
app/models/products/asset.rb
app/models/products/liability.rb
app/models/products/mortgage.rb
app/models/products/credit_card.rb
```

### The interface (small, on purpose)

Every product answers the same questions. Callers should not know `kind`.

```ruby
# identity (delegated to the record)
id, name, institution, to_param, kind_label

# roles
trackable?                  # monthly values?
asset?                      # in allocation?
net_worth_contribution      # 0 / +amount / -amount.abs

# valued products
current_amount              # nil for cards
amount_on(date)

# persistence escape hatch (narrow)
record                      # the Account row, for forms/IDs
```

Factory — **the only `case kind` in the app**:

```ruby
module Products
  def self.wrap(account)
    case account.kind
    when "credit_card" then CreditCard.new(account)
    when "liability"   then Mortgage.new(account)
    else                    Asset.new(account)
    end
  end

  def self.wrap_all(accounts) = Array(accounts).map { wrap(it) }
end
```

That is the seam. One adapter today (the AR row). Do **not** introduce repositories, ports, or `app/domain/`.

### What moves behind the interface

| Today (scattered) | After (local) |
|---|---|
| `kind != "credit_card"` in Portfolio, ValueEntries, CSV, Dashboard | `product.trackable?` |
| `kind == "liability" ? -amount.abs : amount` in Portfolio | `product.net_worth_contribution` |
| `kind == "credit_card" \|\| kind == "liability"` in Allocation | `product.asset?` |
| `mortgage?` validations on `Account` | `Products::Mortgage` validations (via AR `validates if:` that delegate, or a custom validator the Mortgage class owns) |
| Liability columns on the shared form | Mortgage form partial; CreditCard form partial |
| `DashboardController` splits collections | `products.partition(&:trackable?)` / `select { not trackable? }` |

`Portfolio` becomes deep and kind-blind:

```ruby
def net_worth
  @products.sum(&:net_worth_contribution)
end

def needs_check_in?
  month = Date.current.beginning_of_month
  @products.select(&:trackable?).any? { |p| p.amount_on(month).nil? }
end
```

Adding “should I pay down this mortgage faster?” later is a method on `Products::Mortgage`, not another `if account.kind` in the dashboard. Adding a HELOC is `Products::Heloc < Liability` and one line in `wrap` — `Portfolio` does not change.

### Persistence: stay on one table for this step

Do **not** split tables or enable STI in the first domain PR. M8 already added nullable credit-card columns on `accounts`; M7 did the same for mortgages. A schema split while those PRs are open is churn for no behaviour.

Keep `Account::KINDS` as the persisted discriminator until the wrappers are the only consumers. Then a later PR can rename:

- `kind` on assets → remains `kind` (sleeve)
- `kind: liability | credit_card` → `product_type` (or STI `type`) if you outgrow the factory

---

## Alternatives (and why not first)

### 1. Rails STI (`Asset < Account`, `Mortgage < Account`, `CreditCard < Account`)

Works, and Rails will auto-instantiate subclasses. Rejected as the *first* move because:

- The table is already a wide nullable row; STI does not fix that
- Asset “subtypes” (TFSA vs cash) should **not** be subclasses — they share behaviour and differ by sleeve
- You would still need a factory-like `wrap` for things that are not rows (CSV, seeds)
- STI `type` plus existing `kind` is two discriminators

Reconsider STI only if you want `Account.find` to return the subclass with no factory. That is convenience, not depth.

### 2. Delegated types / extra detail tables

```
accounts (id, name, institution, product_type, product_id)
mortgage_details (interest_rate, term_months, original_principal)
credit_card_details (annual_fee, perks, renewal_on)
```

This is the right schema **once** variant columns keep growing (amortization, offset, insurance; card family, first-year-fee-waived). It is the wrong next PR: it restacks M8, the form, seeds, and fixtures for a household app with three extra columns.

### 3. Fully separate AR models (`Mortgage`, `CreditCard`, `Investment`)

Most honest to the domain, worst for the current UI (one CRUD resource, one CSV, one dashboard list). `Portfolio` would compose three queries. Do this only if products stop sharing even identity fields.

### 4. Concerns on `Account` (`Trackable`, `Mortgageable`)

Looks tidy, still one god object. Every caller still talks to `Account` and the next feature still opens that file. Concerns do not create a seam.

### 5. Service objects per use case (`ComputeNetWorth`, `CheckInReminder`)

You already have the right aggregators (`Portfolio`, `Allocation`). More services would **strip** behaviour out of products and leave anemic rows. Don’t.

---

## How the existing objects change

**`Account` (AR)** — shrink toward persistence: associations, presence/inclusion, `latest_value` / `current_amount` (or those move onto valued products). Drop `mortgage?` as a public API; keep a private discriminator for `Products.wrap` if needed.

**`Portfolio`** — takes products (or wraps on init). Knows household totals, not kinds.

**`Allocation`** — `products.select(&:asset?)`. Slices still group assets by sleeve (`kind`).

**`AccountSuggestion`** — stays a catalog over **sleeves the household does not hold**. It should ask assets for `kind`, not iterate credit cards.

**`MonthlyChange`** — stays a pure function of two amounts. Products can expose `monthly_change` as a convenience.

**`ValueEntriesController`** — `Products.wrap_all(Account.all).select(&:trackable?)`. Upsert logic can later move to `ValuedProduct#record_amount(month, amount)` so CSV and the form share it.

**`AccountsController`** — still finds `Account` rows. Strong params stay wide for one form in the first PR; split params/partials in the forms PR.

**`PortfolioCsvImport`** — after wrap: `next unless product.trackable?` instead of a credit-card string check. Creating rows still goes through `Account.create!`.

**Views** — dashboard cards: `if product.is_a?(Products::Mortgage)` or, better, `render product.card_partial`. Prefer asking the product for display bits (`rate_line`, `annual_fee_line`) over type checks in ERB.

---

## Phased PRs (after the current stack)

Do not sneak this into remaining feature milestones. Those PRs should stay on-milestone.

### PR D1 — Product wrappers, no schema change

- Add `Products::*` + `wrap`
- Point `Portfolio`, `Allocation`, dashboard split, value-entry scope, and (after restack) CSV at the interface
- Move kind-specific tests onto product tests; Portfolio tests assert “cards don’t affect net worth” via a wrapped credit-card fixture, not `kind ==`
- `bin/rails test` + the four CI checks

Success test: `rg 'kind ==' app/` is only `Products.wrap` (and maybe seeds).

### PR D2 — Forms follow types

- Separate partials: asset / mortgage / credit card
- Kind select first (or “what are you adding?”), then the matching fields
- Validations conceptually owned by the product class (still AR-backed)

### PR D3 — Optional schema, only if columns keep growing

- Delegated type or `has_one :mortgage_detail` / `credit_card_detail`
- `kind` on assets remains the sleeve
- `mortgage?` no longer means `kind == "liability"` — a future HELOC can share `Liability` without fake mortgage validations

### Docs

- Short `CONTEXT.md` glossary (terms above)
- Skip an ADR unless you later choose delegated types or split tables (that decision is hard to reverse; wrappers are not)

---

## Constraints to keep

- Stay in Rails: POROs in `app/models`, no JS build, no new gem for a “domain framework”
- No repositories / dry-rb entities / full hexagonal layout — this app is SQLite + Hotwire on a Pi
- Render seeds stay idempotent; if D3 splits tables, extend `db/seeds.rb`
- Don’t block or rewrite the open stack to do this

---

## Suggested next step

Merge/restack remaining feature PRs as planned. Then implement **PR D1 only**: wrappers + make `Portfolio` / `Allocation` / value entry / dashboard kind-blind. That is the leverage: every later mortgage-vs-invest or card-renewal feature has a class to live in.
