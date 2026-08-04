# The Portfolio — three games, one goal

Three complete games live in this repo, each targeting a **different discovery lane**:

| Game | Folder | Search lane | Paid RNG surface |
|------|--------|-------------|------------------|
| Crack a Geode! [Mining Simulator] | `/` (root) | "mining simulator" — collection idle | Odds panel + policy gating (built in) |
| Reel a Relic! [Fishing Simulator] | `games/reel-a-relic/` | "fishing simulator" — hot lane in 2026 | Same engine, same compliance |
| Easy Obby: +1 Jump | `games/easy-obby/` | "easy obby" — the evergreen archetype (1.3B+ visits) | **None** — zero loot-box surface |

## The honest math (read this before dreaming about $5k)

**Revenue does not stack linearly.** ~85% of monetizing Roblox devs earn under $100/month —
each game is an independent lottery ticket against that base rate, and five mediocre games earn
5 × $50, not $5,000. What a portfolio actually buys you:

1. **Three independent shots** at the D1 ≥ 30% retention threshold that unlocks algorithmic
   distribution — in three different niches, so one saturated lane doesn't sink all three.
2. **Cheap tickets.** The engine (data, monetization, streaks, leaderboards, compliance, UI) is
   shared, so games #2 and #3 cost a fraction of game #1.
3. **A real decision rule** instead of hope (below).

The realistic $5k+/month path is **one** game reaching the top ~3–5% tier ($2,500–5,000+) plus
modest income from the others — driven by doubling down on the winner, not by shipping more losers.

## The decision rule (calendar this)

- **Weeks 0–2:** launch in order — Crack a Geode first, Reel a Relic ~1 week later, Easy Obby
  ~1 week after that (staggered so your TikTok clips don't compete with each other).
- **Weeks 2–6:** each game gets identical light support: 3–5 clips/week for its launch window,
  weekly config-row update, watch Analytics (D1 retention, sub-60s bounce, funnel drop-off).
- **Week 6 checkpoint — kill or double down:**
  - Any game with **D1 ≥ 30%** and a healthy funnel → it gets the ad budget ($50–150 CPP tests),
    the weekly update slot, and all future clip production.
  - Any game with D1 < 20% after honest iteration on its biggest funnel drop-off → **stop
    updating it.** Leave it published (it still earns trickle + Creator Rewards), spend zero
    further hours on it.
  - In between → one more iteration cycle, then re-decide.
- **Maintenance budget:** ~3–6 h/week total across the portfolio during launch season, tapering
  to 1–2 h/week focused on the winner. If everything misses, the correct move is a *new* lane
  with the reused engine — not more effort on proven losers.

## Operational notes

- Each game is fully self-contained (own `default.project.json`, `src/`, `build/game.rbxlx`,
  `SETUP.md`) and publishes as its own Roblox experience under the same group.
- Publish all three under **one group** so revenue pools toward the DevEx minimum (30,000 R$)
  faster and every game cross-promotes the group's 2x-daily-reward bonus.
- CI validates and rebuilds all three place files on every push.
- Per-game revenue expectations, product tables, and store copy live in each game's SETUP.md.
