# Reel a Relic! [Fishing Simulator] — setup

Same engine and operator flow as the root game — **follow the root [`SETUP.md`](../../SETUP.md)
for accounts, publishing, verification, and launch strategy.** This file covers only what's
different. Open `build/game.rbxlx` in Studio and publish it as a **separate experience** under
the same group.

**Gameplay:** click a buoy to cast → the lamp flashes when a fish is on → **hold to reel it in**,
keeping the darting fish inside your bracket until the meter fills.

The reel-in is the game. It replaced a 1.2-second reaction window that threw the whole catch away
on a miss — a fighting-game rule, wrong for eight-year-olds on phones. **You cannot lose a fish
here.** The meter drains when you're off the fish but the reel always lands it; how well you
tracked decides how many come up (up to +2). That's the rule the whole game runs on: an input
always produces something, and skill produces more.

It's one input, so it plays the same with a finger and a mouse. Deeper areas fight harder — but
the bracket can always outrun the fish, because unfair reads as broken.

Roughly seven catches in eight are a **fish**, which goes straight into your hold: species ×
aura × **weight in pounds**, with a per-species personal best that never stops being beatable.
The rest are **treasure chests**, carried back to the Chest station and opened there with the
full reveal and the odds panel. Every chest is a guaranteed Rare-or-better, which is what earns
it the ceremony — you are never gambling on whether the walk back was worth it.

Sell fish for coins or display them in the **Aquarium**, where they earn **while you're offline**.

**Progression is areas, not rebirths.** There are five stretches of water — Sunny Shallows, Kelp
Forest, Twilight Reef, Midnight Trench, The Abyss — each physically separate, each with its own
species list, bought **once with coins** from the **Dock Master** at the home port. Species
*turn over* between areas rather than accumulating, so sailing somewhere new means a genuinely
different set of fish, not a longer list. **Set Sail (rebirth) never takes an area back**; it
resets the run and grants the permanent +25% coin multiplier, and that separation is what makes
saving three million coins for the Abyss feel safe rather than risky.

Also: Feeding Frenzy / Moon Tide server events, clock-synced Chest Shop, daily streaks.

## Products to create (paste IDs into `src/shared/Config/Monetization.luau`)

Gamepasses: Auto-Cast 450 · Auto-Open 100 · 2x Coins 250 · 2x Luck 350 · Triple Open 450 ·
Overnight Aquarium 500 · VIP Sea Captain 1,000

**Auto-Cast** is the headline convenience pass: the rod casts and re-casts itself while you hold,
and reels for you when you aren't steering. Two deliberate limits keep it honest —

- **It reels at an ordinary standard** (0.62 quality), well under what an attentive player
  manages. It buys away the work, never the reward for doing it well.
- **The moment you touch the screen mid-reel you take the wheel back**, and the result counts as
  yours. Selling a player an autopilot for the best mechanic in the game would hand them *less*
  game than the free version. The pass removes the repetitive part — casting, and re-casting, and
  re-casting — not the fun part.

Rods and boats are hand-authored for their first sixteen and ten tiers and then keep generating
forever, so the upgrade button never greys out with nothing behind it.

Dev products: Starter Pack 200 · Coin Pouch 100 · Coin Chest 500 · Coin Vault 1,000 ·
Time Warp 200 · Instant Restock 79 · Instant Set Sail 150

Private server: 99 R$/month (set once, never reprice). Age questionnaire: answer **yes** to
paid random items (chests bought with earnable coins — odds shown, policy-gated).

## Store page

- **Name:** `Reel a Relic! [Fishing Simulator]`
- **Hook line:** `🎣 FIGHT every fish in! 21 species, 5 oceans — and your aquarium earns coins WHILE YOU SLEEP! 🐠`

  Three hooks in one line, in the order they matter. **The fight** is the differentiator — a
  fishing game where you reel is a different product from one where you click. **The number** is
  the collection promise: an unfinished set is why people come back tomorrow. **While you sleep**
  is the idle promise, which is what makes a lapsed player reopen the app a week later.

- Description: adapt the root game's template. Lead with the reel-in fight, then: 21 species ×
  6 auras, per-fish **weight records** that never finish, five oceans to unlock with coins,
  offline aquarium earnings, Feeding Frenzy events, daily streaks, exact odds shown on every chest.
- Thumbnails: **the reel bar mid-fight** with the meter nearly full ("DON'T LOSE IT!"), a Moonlit
  Leviathan reveal, the welcome-back offline earnings popup. The bar is the best thumbnail the
  game has — it shows a verb, and a stranger scrolling knows instantly what they'd be doing.

## Clip ideas (adapt the root `marketing/tiktok-scripts.md` formats)

1. A near-miss reel — the meter draining to almost nothing, then filling → PERFECT REEL! → Moonlit
   reveal. Tension and payoff in eight seconds, which is the whole format.
2. "My aquarium earned 12k coins while I slept."
3. Sailing into the Abyss for the first time — the water goes black and the Leviathan bites.
4. Feeding Frenzy chaos — whole server rushing the buoys at 10x luck.
5. Rod tier 1 vs tier 16 side by side: same ten seconds, one fish against a boatful.

## Playtest checklist

- [ ] Click a buoy → rod swings, bobber arcs out and lands with a splash
- [ ] Click BEFORE the bite → the bobber twitches and the bite is pushed back (not ignored)
- [ ] Lamp flashes → the reel bar appears; **hold raises the bracket, releasing drops it**
- [ ] Deliberately track badly: the meter drains, times out at 10s, and **you still get the fish**
- [ ] Track well: "PERFECT REEL!" and visibly more fish than a scrappy one
- [ ] Walk backwards mid-reel — the fight is NOT cancelled
- [ ] Both outcomes appear: a fish lands straight in the hold, a chest goes to the station
- [ ] Chest opens with the odds panel and is always Rare+; third open ever is Rare+ (pity)
- [ ] Hold counter shows fish + chests together, and fills up (boat capacity gates both)
- [ ] Catch the same species twice: the heavier one fires "HEAVIEST … YET" and updates the Index
- [ ] Socket fish in the Aquarium: they appear swimming in the tank, and it gets busier each time
- [ ] Dock Master lists all five areas with prices; buying area 2 teleports you and the
      Sunny Shallows species stop biting
- [ ] Set Sail: resets run, +25% coins, and **area unlocks are still there afterwards**
- [ ] Another player can't steal your claimed buoy mid-cast
- [ ] Comp yourself `AutoCast` via `Monetization.CompUserIds`: it casts and reels hands-free —
      then touch the screen mid-reel and confirm **you take control back**
- [ ] Buy the last authored rod, then buy again: a generated tier appears with a real name,
      better numbers and a higher price — the button never dead-ends
