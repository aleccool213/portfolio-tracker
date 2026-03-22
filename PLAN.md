# Portfolio Tracker — MVP Plan

## Goal
A single-page browser app that answers two questions:
1. **Is my money diversified enough?** (asset allocation across accounts & asset types)
2. **How are my accounts performing over time?** (per-account returns, trends)

All data stays local. No backend, no third-party services.

---

## Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| UI | **React 19 + Vite** | Fast dev, tiny bundle, no server needed |
| Styling | **Tailwind CSS v4** | Rapid UI without writing CSS files |
| Charts | **Recharts** | Lightweight, React-native charting |
| Storage | **Browser localStorage + JSON import/export** | Zero backend; upgradeable to SQLite/IndexedDB later |
| Language | **TypeScript** | Catch bugs early, self-documenting data shapes |
| Testing | **Vitest + React Testing Library** | Vite-native, fast, same config |
| Routing | **React Router v7 (hash router)** | Works from file:// and static hosting |

Single `index.html` deployable — open the file or serve with `npx serve dist`.

---

## Data Model (JSON schema)

```jsonc
{
  "version": 1,
  "accounts": [
    {
      "id": "uuid",
      "name": "Fidelity 401k",
      "type": "retirement",       // retirement | brokerage | savings | crypto | other
      "institution": "Fidelity",
      "holdings": [
        {
          "id": "uuid",
          "name": "VTI",
          "assetClass": "us_stock", // us_stock | intl_stock | bond | real_estate | cash | crypto | other
          "value": 25000,
          "costBasis": 20000       // optional, for gain/loss calc
        }
      ]
    }
  ],
  "snapshots": [
    {
      "date": "2025-01-31",        // monthly or manual snapshot
      "balances": {
        "<account-id>": 52000      // total balance per account at that point
      }
    }
  ]
}
```

Key points:
- `accounts[].holdings` = current state (editable)
- `snapshots[]` = historical record (append-only, used for time-series charts)
- Users take a "snapshot" whenever they update balances (button: "Save Snapshot")

---

## Pages / Views

### 1. Dashboard (home)
- **Total net worth** number
- **Diversification donut chart** — by asset class (us_stock, bond, etc.)
- **Account breakdown bar chart** — value per account
- **Trend line chart** — total net worth over time (from snapshots)
- Alerts if any single asset class > 40% or any single account > 50% of total

### 2. Accounts List
- Table of all accounts with name, institution, type, total value, % of portfolio
- Click → Account Detail

### 3. Account Detail
- Holdings table (name, asset class, value, cost basis, gain/loss)
- Add / edit / delete holdings
- Per-account performance line chart (from snapshots)

### 4. Import / Export
- **Export**: download portfolio JSON file
- **Import**: upload JSON file, validate, replace or merge
- Auto-save to localStorage on every change

---

## File Structure

```
portfolio-tracker/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── src/
│   ├── main.tsx                  # entry point
│   ├── App.tsx                   # router + layout
│   ├── types.ts                  # Portfolio, Account, Holding, Snapshot types
│   ├── store.ts                  # state management (React context + useReducer)
│   ├── utils/
│   │   ├── storage.ts            # localStorage read/write
│   │   ├── importExport.ts       # JSON file import/export + validation
│   │   └── calculations.ts       # totals, diversification %, gains
│   ├── components/
│   │   ├── Layout.tsx            # nav + shell
│   │   ├── Dashboard.tsx
│   │   ├── AccountsList.tsx
│   │   ├── AccountDetail.tsx
│   │   ├── HoldingForm.tsx       # add/edit holding modal
│   │   ├── ImportExport.tsx
│   │   └── charts/
│   │       ├── DiversificationChart.tsx
│   │       ├── AccountBarChart.tsx
│   │       └── TrendLineChart.tsx
│   └── __tests__/
│       ├── calculations.test.ts
│       ├── store.test.tsx
│       ├── importExport.test.ts
│       ├── AccountsList.test.tsx
│       ├── AccountDetail.test.tsx
│       └── Dashboard.test.tsx
```

---

## Milestones

Each milestone is a self-contained unit of work. Complete all tasks in order within a milestone before moving on. Run `npm run build` and `npx vitest run` at the end of every milestone to verify nothing is broken.

---

### Milestone 1: Project Scaffold & Type Definitions

**What this accomplishes:** A working Vite dev server with all dependencies installed, TypeScript types defined, and test infrastructure ready. No UI yet — just the foundation everything else builds on.

#### Tasks

**1.1 — Scaffold Vite project**
- Run `npm create vite@latest . -- --template react-ts` in the repo root (use `.` since the directory already exists)
- Verify `npm run dev` starts without errors
- Verify `npm run build` succeeds

**1.2 — Install dependencies**
- Run: `npm install react-router-dom recharts`
- Run: `npm install -D tailwindcss @tailwindcss/vite vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom`
- Add Tailwind vite plugin to `vite.config.ts`:
  ```ts
  import tailwindcss from "@tailwindcss/vite";
  // add tailwindcss() to plugins array
  ```
- Replace the contents of `src/index.css` with just `@import "tailwindcss";`
- Add to `vite.config.ts` a `test` block:
  ```ts
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test-setup.ts',
  }
  ```
- Create `src/test-setup.ts`:
  ```ts
  import '@testing-library/jest-dom';
  ```
- Add `"test": "vitest run"` to `package.json` scripts
- Verify `npm test` runs (0 tests is fine)
- Verify `npm run build` still succeeds

**1.3 — Define types in `src/types.ts`**
- Create the file with these exported types:
  ```ts
  export type AccountType = 'retirement' | 'brokerage' | 'savings' | 'crypto' | 'other';
  export type AssetClass = 'us_stock' | 'intl_stock' | 'bond' | 'real_estate' | 'cash' | 'crypto' | 'other';

  export interface Holding {
    id: string;
    name: string;
    assetClass: AssetClass;
    value: number;
    costBasis?: number;
  }

  export interface Account {
    id: string;
    name: string;
    type: AccountType;
    institution: string;
    holdings: Holding[];
  }

  export interface Snapshot {
    date: string;           // ISO date string YYYY-MM-DD
    balances: Record<string, number>;  // account id → total balance
  }

  export interface Portfolio {
    version: number;
    accounts: Account[];
    snapshots: Snapshot[];
  }
  ```
- This file has no logic, just types — no tests needed

**1.4 — Create sample data fixture**
- Create `src/sampleData.ts` that exports a `Portfolio` object with:
  - 3 accounts (e.g., "Fidelity 401k" retirement, "Schwab Brokerage" brokerage, "Savings Account" savings)
  - 2-4 holdings per account spanning different asset classes
  - 6 monthly snapshots (2024-07 through 2024-12) with slightly growing balances
- This will be used for first-run experience and for tests

#### Tests for Milestone 1
- No unit tests yet — validation is: `npm run build` succeeds, `npm test` runs without error, `npm run dev` starts the dev server

#### Checkpoint
- `npm run dev` → browser shows default Vite React page
- `npm run build` → succeeds
- `npm test` → runs (0 tests OK)
- `src/types.ts` and `src/sampleData.ts` exist and compile

---

### Milestone 2: State Management & localStorage Persistence

**What this accomplishes:** The entire data layer — context/reducer for state, localStorage for persistence, JSON import/export. After this milestone, data can flow through the app and survive page refreshes, even though there's no real UI yet.

#### Tasks

**2.1 — Build `src/utils/storage.ts`**
- `savePortfolio(portfolio: Portfolio): void` — serializes to JSON, writes to `localStorage` under key `"portfolio-tracker-data"`
- `loadPortfolio(): Portfolio | null` — reads from `localStorage`, parses JSON, returns null if missing or invalid
- Use a try/catch around JSON.parse; return null on any error

**2.2 — Build `src/store.ts`**
- Create a React context + `useReducer` pattern
- Define action types:
  ```ts
  type Action =
    | { type: 'SET_PORTFOLIO'; payload: Portfolio }
    | { type: 'ADD_ACCOUNT'; payload: Account }
    | { type: 'UPDATE_ACCOUNT'; payload: Account }
    | { type: 'DELETE_ACCOUNT'; payload: string }           // account id
    | { type: 'ADD_HOLDING'; payload: { accountId: string; holding: Holding } }
    | { type: 'UPDATE_HOLDING'; payload: { accountId: string; holding: Holding } }
    | { type: 'DELETE_HOLDING'; payload: { accountId: string; holdingId: string } }
    | { type: 'TAKE_SNAPSHOT' }
  ```
- The reducer handles each action immutably
- `TAKE_SNAPSHOT`: computes each account's total (sum of holding values), appends a new `Snapshot` with today's date and those balances
- `PortfolioProvider` component:
  - On mount: call `loadPortfolio()`. If null, use sample data from `sampleData.ts`
  - After every dispatch (use a `useEffect` on the state): call `savePortfolio(state)`
  - Provides `{ state, dispatch }` via context
- Export a `usePortfolio()` hook that calls `useContext` and throws if used outside provider

**2.3 — Build `src/utils/importExport.ts`**
- `exportPortfolio(portfolio: Portfolio): void`
  - Creates a JSON blob, triggers a download as `portfolio-YYYY-MM-DD.json`
  - Use `URL.createObjectURL` + a temporary `<a>` element
- `validatePortfolio(data: unknown): Portfolio`
  - Checks: `data` is an object, has `version` === 1, has `accounts` array, each account has `id`, `name`, `type`, `institution`, `holdings` array, each holding has `id`, `name`, `assetClass`, `value` (number)
  - Checks `snapshots` is an array (may be empty)
  - Throws descriptive error strings if invalid
  - Returns the typed `Portfolio` if valid
- `importPortfolio(file: File): Promise<Portfolio>`
  - Reads the file as text with `FileReader`, parses JSON, calls `validatePortfolio`, returns result
  - Throws on read error or validation failure

#### Tests for Milestone 2

**`src/__tests__/store.test.tsx`**
- Test `ADD_ACCOUNT`: dispatch adds an account, state.accounts length increases
- Test `DELETE_ACCOUNT`: dispatch removes the correct account by id
- Test `ADD_HOLDING`: adds a holding to the correct account
- Test `UPDATE_HOLDING`: replaces the holding with matching id
- Test `DELETE_HOLDING`: removes the holding from the correct account
- Test `TAKE_SNAPSHOT`: creates a snapshot with correct date and computed balances
- Test `SET_PORTFOLIO`: replaces entire state
- For each test, render a test component inside `<PortfolioProvider>` that uses `usePortfolio()`, triggers dispatch via button clicks, and asserts on rendered output

**`src/__tests__/importExport.test.ts`**
- Test `validatePortfolio` with valid data → returns Portfolio
- Test `validatePortfolio` with missing `accounts` → throws
- Test `validatePortfolio` with invalid account (missing `name`) → throws
- Test `validatePortfolio` with holding missing `value` → throws
- Test `validatePortfolio` with non-object input → throws

#### Checkpoint
- `npm test` → all tests pass
- `npm run build` → succeeds

---

### Milestone 3: Layout, Routing & Accounts CRUD

**What this accomplishes:** The app now has a navigable UI with sidebar/tabs, an accounts list page where you can add/edit/delete accounts, and an account detail page where you can manage holdings. This is the core workflow — the user can manage their 10 accounts.

#### Tasks

**3.1 — Set up routing in `src/App.tsx`**
- Wrap app in `HashRouter` (from `react-router-dom`) so it works from file://
- Wrap in `PortfolioProvider`
- Define routes:
  - `/` → Dashboard (placeholder `<div>Dashboard coming soon</div>` for now)
  - `/accounts` → AccountsList
  - `/accounts/:id` → AccountDetail
  - `/import-export` → ImportExport (placeholder for now)
- Delete all default Vite boilerplate (`App.css`, logo SVGs, counter code, etc.)

**3.2 — Build `src/components/Layout.tsx`**
- A wrapper component used by all routes
- Left sidebar (or top nav on mobile) with links: Dashboard, Accounts, Import/Export
- Use Tailwind classes: `bg-gray-50` page bg, `bg-white` sidebar, `border-r`, etc.
- Highlight the active link using `useLocation()` from react-router
- Main content area takes children via `<Outlet />`

**3.3 — Build `src/components/AccountsList.tsx`**
- Reads accounts from `usePortfolio()`
- Displays a table with columns: Name, Institution, Type, Total Value, % of Portfolio
- Total Value = sum of `account.holdings[].value`
- % of Portfolio = account total / grand total of all accounts × 100
- "Add Account" button opens inline form (or simple modal) with fields: name, institution, type (dropdown of AccountType values). On submit: dispatch `ADD_ACCOUNT` with a generated UUID (use `crypto.randomUUID()`) and empty holdings array.
- Each row has an "Edit" button (inline edit of name/institution/type, dispatch `UPDATE_ACCOUNT`) and a "Delete" button (confirm dialog, dispatch `DELETE_ACCOUNT`)
- Each row's account name is a `<Link>` to `/accounts/:id`

**3.4 — Build `src/components/AccountDetail.tsx`**
- Gets `:id` from `useParams()`, finds the account in state
- Shows account name, institution, type at the top
- Holdings table with columns: Name, Asset Class, Value, Cost Basis, Gain/Loss (value - costBasis, or "—" if no cost basis), % of Account
- "Add Holding" button opens `HoldingForm`
- Each holding row has Edit and Delete buttons

**3.5 — Build `src/components/HoldingForm.tsx`**
- A form (inline or modal) for adding/editing a holding
- Fields: name (text), assetClass (dropdown of AssetClass values), value (number input), costBasis (optional number input)
- On submit: dispatch `ADD_HOLDING` or `UPDATE_HOLDING` depending on whether we're editing
- On cancel: close form
- Props: `accountId: string`, `holding?: Holding` (if editing), `onClose: () => void`

#### Tests for Milestone 3

**`src/__tests__/AccountsList.test.tsx`**
- Render AccountsList inside PortfolioProvider (with sample data) and MemoryRouter
- Assert all sample accounts are displayed in the table
- Assert total values are computed correctly
- Assert % of portfolio values are shown
- Click "Add Account" → fill form → submit → new account appears in table
- Click "Delete" on an account → confirm → account disappears

**`src/__tests__/AccountDetail.test.tsx`**
- Render AccountDetail with a route param matching a sample account
- Assert holdings are displayed
- Assert gain/loss is computed as value - costBasis
- Click "Add Holding" → fill form → submit → new holding appears
- Click "Delete" on a holding → holding disappears

#### Checkpoint
- `npm test` → all tests pass
- `npm run dev` → can navigate between pages, add/edit/delete accounts and holdings
- `npm run build` → succeeds

---

### Milestone 4: Calculations & Dashboard Charts

**What this accomplishes:** The dashboard — the main screen that answers "is my money diversified?" and "how are accounts tracking over time?" with charts and summary numbers. This is the core value of the app.

#### Tasks

**4.1 — Build `src/utils/calculations.ts`**
- `calcNetWorth(accounts: Account[]): number` — sum of all holdings across all accounts
- `calcAccountTotal(account: Account): number` — sum of account's holdings values
- `calcAssetAllocation(accounts: Account[]): Record<AssetClass, number>` — sum values by asset class across all accounts. Only include asset classes that have non-zero values.
- `calcAccountAllocation(accounts: Account[]): { name: string; value: number }[]` — array of { account name, total value } for bar chart
- `calcDiversificationAlerts(accounts: Account[]): string[]` — returns warning strings:
  - If any single asset class > 40% of net worth: `"${assetClass} is ${pct}% of your portfolio (over 40% threshold)"`
  - If any single account > 50% of net worth: `"${accountName} is ${pct}% of your portfolio (over 50% threshold)"`
- `calcSnapshotTimeSeries(snapshots: Snapshot[]): { date: string; total: number }[]` — for each snapshot, sum all account balances to get total, return sorted by date
- `calcAccountTimeSeries(snapshots: Snapshot[], accountId: string): { date: string; value: number }[]` — extract one account's balance across snapshots, sorted by date

**4.2 — Build `src/components/charts/DiversificationChart.tsx`**
- Pie/donut chart using Recharts `<PieChart>` + `<Pie>`
- Data from `calcAssetAllocation()`
- Color-coded by asset class (define a constant color map, e.g. us_stock=blue, bond=green, etc.)
- Legend showing asset class name and percentage
- Props: `accounts: Account[]`

**4.3 — Build `src/components/charts/AccountBarChart.tsx`**
- Horizontal bar chart using Recharts `<BarChart>` with `layout="vertical"`
- Data from `calcAccountAllocation()`
- Shows account name and dollar value
- Props: `accounts: Account[]`

**4.4 — Build `src/components/charts/TrendLineChart.tsx`**
- Line chart using Recharts `<LineChart>` + `<Line>`
- Data from `calcSnapshotTimeSeries()` or `calcAccountTimeSeries()` depending on props
- X-axis: date, Y-axis: dollar value
- Props: `data: { date: string; value: number }[]`, `label?: string`

**4.5 — Build `src/components/Dashboard.tsx`**
- Top: large net worth number formatted as currency (`$XXX,XXX`)
- Below: diversification alerts as yellow/orange warning banners (if any)
- Three charts in a grid:
  - DiversificationChart (full width or half)
  - AccountBarChart (half width)
  - TrendLineChart with total net worth over time (full width)
- "Save Snapshot" button: dispatches `TAKE_SNAPSHOT`, shows brief success message
- If no snapshots exist, show message "Take your first snapshot to start tracking performance over time"

**4.6 — Add per-account trend chart to AccountDetail**
- Below the holdings table in AccountDetail, add a `TrendLineChart` using `calcAccountTimeSeries()` for that account
- If no snapshots, show "No snapshots yet" message

#### Tests for Milestone 4

**`src/__tests__/calculations.test.ts`**
- Test `calcNetWorth` with sample data → returns correct sum
- Test `calcNetWorth` with empty accounts → returns 0
- Test `calcAccountTotal` → correct sum of holdings
- Test `calcAssetAllocation` → correct grouping (e.g., two VTI holdings across accounts both counted as us_stock)
- Test `calcDiversificationAlerts` with a portfolio where one asset class is 60% → returns alert string
- Test `calcDiversificationAlerts` with balanced portfolio → returns empty array
- Test `calcDiversificationAlerts` with one account > 50% → returns alert
- Test `calcSnapshotTimeSeries` → correct totals, sorted by date
- Test `calcAccountTimeSeries` → correct extraction for one account

**`src/__tests__/Dashboard.test.tsx`**
- Render Dashboard with sample data
- Assert net worth number is displayed and formatted
- Assert "Save Snapshot" button exists
- Click "Save Snapshot" → snapshot count in state increases by 1
- If diversification alerts would fire on sample data, assert they are shown
- Assert chart components are rendered (check for SVG elements or recharts container divs)

#### Checkpoint
- `npm test` → all tests pass
- `npm run dev` → Dashboard shows charts with sample data, snapshot button works
- `npm run build` → succeeds

---

### Milestone 5: Import/Export & Polish

**What this accomplishes:** Users can export their data as a JSON file and import it back. First-run experience loads sample data. Concentration warnings are prominent. The app is complete and usable.

#### Tasks

**5.1 — Build `src/components/ImportExport.tsx`**
- "Export" section: button that calls `exportPortfolio(state)` — downloads the JSON file
- "Import" section: file input (`accept=".json"`), on file select calls `importPortfolio(file)`, on success dispatches `SET_PORTFOLIO` with the result
- Show error message if import fails (validation error displayed to user)
- Show success message after import with account count: "Imported X accounts successfully"
- Add a warning: "Importing will replace all current data. Export first if you want a backup."

**5.2 — First-run experience**
- In `PortfolioProvider`: if `loadPortfolio()` returns null (first visit), load sample data and show a dismissible banner on Dashboard: "You're viewing sample data. Add your own accounts or import a JSON file to get started."
- Store a `"portfolio-tracker-sample-dismissed"` flag in localStorage when dismissed

**5.3 — Currency formatting utility**
- Create a small helper `formatCurrency(value: number): string` in `src/utils/calculations.ts`
- Uses `Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })`
- Apply it everywhere dollar amounts are displayed (Dashboard net worth, account totals, holding values, gain/loss)

**5.4 — Responsive layout polish**
- Sidebar collapses to top nav bar on small screens (`md:` breakpoint)
- Dashboard chart grid stacks vertically on mobile
- Tables become scrollable horizontally on small screens (`overflow-x-auto`)

**5.5 — Delete old Vite boilerplate**
- Remove any remaining unused files: `src/assets/react.svg`, `public/vite.svg`, etc.
- Clean up `index.html` title to "Portfolio Tracker"

#### Tests for Milestone 5

Update **`src/__tests__/importExport.test.ts`** (add to existing):
- Test `exportPortfolio` — mock `URL.createObjectURL` and `document.createElement`, assert the blob content matches the portfolio JSON
- Test `importPortfolio` with a valid JSON file → returns Portfolio
- Test `importPortfolio` with invalid JSON → throws
- Test `formatCurrency(1234.5)` → `"$1,234.50"`
- Test `formatCurrency(0)` → `"$0.00"`

#### Checkpoint
- `npm test` → all tests pass
- `npm run dev` → full app works end to end: navigate, CRUD accounts/holdings, view charts, export JSON, import JSON back, snapshot tracking
- `npm run build` → succeeds, `dist/` folder is deployable
- Open `dist/index.html` directly in browser → app loads and works (hash routing)
