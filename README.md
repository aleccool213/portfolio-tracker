# Portfolio Tracker

A calm, playful, self-hosted personal-finance dashboard for a Canadian
household — all your Wealthsimple accounts, other investments, liabilities, and
credit-card perks in one warm, hey.com-style place.

- **Stack:** Ruby on Rails 8 + SQLite, Hotwire (Turbo/Stimulus) over import maps
  — no JavaScript build step.
- **Local-first:** runs on hardware you control; deployable to a Raspberry Pi 2B
  via Docker/Kamal.
- **Testable per PR:** every push auto-deploys to Render with seeded sample data
  (see `render.yaml`), so changes can be poked from a phone as they're built.

See [`PLAN.md`](PLAN.md) for the full product vision and milestone roadmap.

## Getting started

```bash
bin/setup            # install gems, create + seed the development database
bin/rails server     # http://localhost:3000
bin/rails test       # run the test suite
```

The dashboard loads seeded sample data (a typical Wealthsimple-shaped set of
Canadian accounts) so there's always something to look at.

## Deploying

- **Render (throwaway test deploys):** connect the repo — Render reads
  `render.yaml`, builds the Dockerfile, and auto-deploys on every push. SQLite is
  ephemeral and re-seeded on each deploy, giving a clean test dataset per PR.
- **Raspberry Pi (persistent):** use the `Dockerfile` with Kamal
  (`config/deploy.yml`); SQLite persists on a volume under `storage/`.
