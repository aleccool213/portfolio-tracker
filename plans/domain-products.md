# Post-merge architecture: domain products

Wait until **PR #22 (CSV import) is on `master`**, then do **one architecture PR**. Do not sneak this into #22, and do not split tables yet.

M8–M11 are already merged. After CSV lands, every real caller of `Account.kind` exists: dashboard, value entry, CRUD form, allocation, suggestions, and import. That is the moment a wrapper hierarchy pays off — one PR can make all of them kind-blind, and later mortgage-vs-invest / MCP work has a class to live in.

---

## Why this, not STI / extra tables / more services

`Account.kind` is doing two unrelated jobs:

| Axis | Values | What it actually is |
|---|---|---|
| **Product type** | `liability`, `credit_card`, (implicit) everything else | What *kind of thing* the household holds |
| **Tax sleeve / wrapper** | `tfsa`, `rrsp`, `resp`, `fhsa`, `non_registered`, `crypto`, `cash` | How a *valued asset* is parked |

Call sites after the feature stack (plus CSV):

- `Portfolio` excludes credit cards, then special-cases liabilities as `-amount.abs`
- `Allocation` excludes credit cards *and* liabilities
- `ValueEntriesController` repeats `where.not(kind: "credit_card")`
- `DashboardController` splits `@cards` / `@value_accounts` by `credit_card?`
- `PortfolioCsvImport` refuses balances on credit cards and requires mortgage columns for new liabilities
- `Account` validations are `if: :mortgage?`, and `mortgage?` is `kind == "liability"`
- The account form always shows mortgage fields *and* credit-card fields
- Seeds store mortgage snapshots negative; `Portfolio` also abs-then-negates

`Portfolio` / `Allocation` / `PortfolioCsvImport` are already the right shape (small POROs). The missing seam is **the product**.

Credit cards are **not** liabilities in this app. They are perk records with no balance and no net-worth effect. Mortgages *are* liabilities. Keep that split.

---

## Domain language

**Product** — something the household holds. Identity is name + institution.
_Avoid_: using “account” for cards and mortgages in new code (`Account` stays the AR table).

**Valued product** — has monthly `AccountValue` snapshots. Assets and liabilities are valued; credit cards are not.

**Asset** — valued product that increases net worth. Its `kind` is a tax sleeve / asset class, not a product type.

**Liability** — valued product that decreases net worth. Sign lives here: always `-amount.abs`.

**Mortgage** — a liability with rate, term, original principal. Do not keep `kind == "liability"` forever aliased to “is a mortgage.”

**Credit card** — perks, annual fee, renewal. Not valued, not in net worth, allocation, or monthly check-in.

**Trackable** — appears on value entry and counts for `needs_check_in?`. Same as valued product.

---

## The refactor (one PR on `master` after #22)

Keep the `accounts` table. Wrap each row in a product object that owns behaviour. No STI, no delegated types, no `app/domain/`, no repositories.

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

Files (Zeitwerk, next to existing POROs):

```
app/models/products.rb
app/models/products/base.rb
app/models/products/asset.rb
app/models/products/liability.rb
app/models/products/mortgage.rb
app/models/products/credit_card.rb
```

### Interface (the only thing callers learn)

```ruby
# identity (delegated)
id, name, institution, to_param, kind_label

# roles
trackable?                  # monthly values?
asset?                      # in allocation?
net_worth_contribution      # 0 / +amount / -amount.abs

# valued products
current_amount              # nil for cards
amount_on(date)
record_amount(month, amount)  # shared by value entry + CSV

# persistence escape hatch (narrow)
record
```

Factory — **the only `case kind` left in `app/`**:

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

### Rewire every merged caller

| Caller | After |
|---|---|
| `Portfolio` | `products.sum(&:net_worth_contribution)`; `needs_check_in?` over `trackable?` |
| `Allocation` | `products.select(&:asset?)`; slices still group by sleeve (`kind`) |
| `AccountSuggestion` | look at **asset** sleeves only, ignore cards/liabilities |
| `DashboardController` | wrap once; `partition(&:trackable?)` for the two card lists |
| `ValueEntriesController` | trackable products; `product.record_amount(...)` |
| `PortfolioCsvImport` | `next unless product.trackable?` for value rows; mortgage attrs applied on `Products::Mortgage` |
| Dashboard view | ask the product for rate line / fee line / sparkline eligibility instead of `account.mortgage?` |
| Account form | identity fields + kind, then a partial per product type (`_asset_fields`, `_mortgage_fields`, `_credit_card_fields`). Stimulus on `kind` to show the matching group is enough — already on import maps |

`Portfolio` after:

```ruby
def net_worth
  @products.sum(&:net_worth_contribution)
end

def needs_check_in?
  month = Date.current.beginning_of_month
  @products.select(&:trackable?).any? { |p| p.amount_on(month).nil? }
end
```

`Account` shrinks toward persistence (associations, presence/inclusion, maybe `latest_value`). Drop `mortgage?` / `credit_card?` as the public API.

### Tests

- New `test/models/products/*_test.rb` for roles and sign convention
- `Portfolio` / `Allocation` tests stop asserting on `kind ==`; they use fixtures of each product type
- Value entry + CSV still cover “cards never get a balance”
- Success check: `rg 'kind ==' app/` is only `Products.wrap` (seeds may still set `kind:`)

### Out of this PR

- Schema split / delegated types / STI
- HELOC, mortgage-vs-invest, MCP
- Renaming the `accounts` table

Those wait until a second product subtype or a third detail column forces them.

---

## Later, only if needed

**Delegated types** (`mortgage_details`, `credit_card_details`) when variant columns keep growing (amortization, offset; card family, first-year-fee-waived). Wrong as the first move — M7/M8 already put nullable columns on `accounts`.

**STI** if you want `Account.find` to return a subclass with no factory. Convenience, not depth. Do not STI TFSA vs cash; those are sleeves on `Asset`.

**Separate AR models** only if products stop sharing identity fields. Worst fit for one dashboard, one CSV, one CRUD resource.

**Concerns on `Account`** (`Trackable`, `Mortgageable`) look tidy and still leave a god object. Skip.

**More service objects** (`ComputeNetWorth`) would strip behaviour out of products. `Portfolio` already is the household aggregator.

---

## Constraints

- POROs in `app/models`, Hotwire / import maps only, no new gems
- Render seeds stay idempotent
- `bin/rails test` plus rubocop / brakeman / bundler-audit / importmap audit

---

## Suggested next step

1. Merge #22.
2. Open one PR: **Introduce `Products` wrappers and stop spreading `kind` checks.**
3. After that, mortgage-vs-invest belongs on `Products::Mortgage`, not in the dashboard controller.
