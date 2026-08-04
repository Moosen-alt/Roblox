# Launch Runbook — first week per game, ads playbook, and what runs itself

Use this identically for each game as it deploys (Crack a Geode now, Reel a Relic ~1 week
later, Easy Obby ~1 week after that — staggered so clips don't compete).

## Day 0 — launch checklist (once per game)

- [ ] Published under the group; auto-publish secrets added (`*_UNIVERSE_ID`, `*_PLACE_ID`)
- [ ] Passes + dev products created, IDs in `Config/Monetization.luau`
- [ ] Private server enabled at 99 R$/month (never reprice)
- [ ] Maturity questionnaire completed (PRI = Yes for the collectible games, No for the obby)
- [ ] Real icon + thumbnails uploaded (never the baseplate default)
- [ ] Description pasted from `marketing/store-page.md`
- [ ] Game set to Public
- [ ] One fresh-save playtest: first-minute flow works, objectives banner shows, purchases prompt

## Days 1–7 — soft launch (NO ADS)

Daily, ~10 minutes:
- Post 1 clip (TikTok + YouTube Shorts + Reels, same video) from `marketing/tiktok-scripts.md`.
  The reveal/mega-leap moment is the clip. Reply to every comment in the first hour.
- Glance at Analytics: **first-play bounce** (Engagement) and, from day 2, **D1 retention**.
  Under ~50 new players/day, treat numbers as noise — look for trends, not verdicts.

Do NOT: buy ads, announce in dev forums, or change balance mid-week (let a clean cohort
accumulate). Exception: fix anything actually broken immediately — pushes go live automatically.

## Week 2+ — the iteration loop

1. Send the D1 number + Onboarding funnel screenshot to Claude.
2. Biggest funnel drop-off gets a `Balance.luau` tweak → auto-deploys.
3. One small "update" per week (a new crystal/relic row = 6 collectibles) — re-triggers the
   discovery algorithm's explore phase.
4. Clips: 3–5/week for whichever game is in its launch window.

## Ads playbook — ONLY once a game shows D1 ≥ 30%

Where: create.roblox.com → **Advertise** (Ads Manager) → Create Campaign.

Settings for the first test:
- Objective: **Awareness/Plays** (cheaper per play than Engagement objective)
- Format: **Sponsored Experience** (your game tile in Home/search — uses your icon, so the
  icon must be good before spending)
- Budget: **$50 total over 7 days** (~$7/day) — this is a test, not a push
- Bidding: **auto-bid** (targets roughly $0.02–0.05 per play)
- Targeting: all devices (the games are mobile-first), all genders, ages 9–17, top revenue
  countries (US/CA/UK/EU) or leave broad

Reading the test after 7 days:
- CPP ≤ $0.05 and D1 of the bigger cohort holding ≥ 30% → scale gradually: $100–150 the next
  week, funded from revenue once it exists. Ads seed the algorithm's retrieval stage; the
  algorithm then does the real distribution.
- CPP > $0.06, or retention sagging → stop. More traffic can't fix retention; back to the
  iteration loop. (Attribution reporting lags up to 30 days — judge by CPP + retention trend,
  not by reported ad revenue.)
- Never advertise a game that hasn't passed the D1 gate. Ranking excludes ad-acquired users'
  behavior, so ads cannot buy the algorithm's favor — only organic retention earns it.

## Can you set it and forget it?

**What runs itself (by design):** the games (systemic content, no update treadmill), offline
progression, clock-synced shops, events, streak calendar, the CI pipeline (any change Claude
pushes validates, rebuilds, and publishes live automatically), and — once configured — the
ad campaigns within their budget caps.

**The honest minimum that can't be automated (~30 min/week total):**
1. Weekly Analytics glance per live game: D1, funnel, revenue. Screenshot → Claude → tweak.
2. The week-6 kill-or-double-down call per `PORTFOLIO.md` (a decision, not a task).
3. Cashing out: DevEx when earned Robux crosses 30,000 (~$114).

**The growth lever that only works if a human does it:** clips. Every 2025–26 breakout was
carried by short-form video. Zero clips = relying purely on search + algorithm luck; the games
will still tick along, but the fat-tail outcomes basically all route through one clip landing.
If you truly want set-and-forget, accept the slower search-only curve — the portfolio was
built to survive that — and batch-record 10 clips in one hour on launch day, scheduling them
through the week instead of daily effort.
