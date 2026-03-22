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
| Styling | **Tailwind CSS** | Rapid UI without writing CSS files |
| Charts | **Recharts** | Lightweight, React-native charting |
| Storage | **Browser localStorage + JSON import/export** | Zero backend; upgradeable to SQLite/IndexedDB later |
| Language | **TypeScript** | Catch bugs early, self-documenting data shapes |

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
├── tailwind.config.js
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
```

---

## Implementation Order

### Phase 1 — Scaffold & data layer
1. `npm create vite` with React + TypeScript template
2. Install Tailwind CSS, Recharts
3. Define types in `types.ts`
4. Build `store.ts` (context + reducer) and `storage.ts` (localStorage persistence)
5. Build `importExport.ts` (download/upload JSON)

### Phase 2 — Core UI
6. `Layout.tsx` — simple sidebar/tab nav
7. `AccountsList.tsx` — table with add/edit/delete
8. `AccountDetail.tsx` + `HoldingForm.tsx` — manage holdings
9. `ImportExport.tsx` — file upload/download buttons

### Phase 3 — Dashboard & charts
10. `calculations.ts` — totals, percentages, diversification metrics
11. `DiversificationChart.tsx` — donut/pie by asset class
12. `AccountBarChart.tsx` — horizontal bar per account
13. `TrendLineChart.tsx` — net worth over time from snapshots
14. `Dashboard.tsx` — compose charts + summary cards
15. Snapshot button — "Save Snapshot" appends current balances to snapshots array

### Phase 4 — Polish
16. Diversification alerts (concentration warnings)
17. Responsive layout for mobile
18. Sample data for first-run experience
