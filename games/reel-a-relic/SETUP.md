# Reel a Relic! [Fishing Simulator] — setup

Same engine and operator flow as the root game — **follow the root [`SETUP.md`](../../SETUP.md)
for accounts, publishing, verification, and launch strategy.** This file covers only what's
different. Open `build/game.rbxlx` in Studio and publish it as a **separate experience** under
the same group.

**Gameplay:** click a glowing buoy to cast → wait for the white flash → click during the flash
to land your catch (better rods bite faster and can double-hook).

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

**Auto-Cast** is the headline convenience pass — hold the button on a buoy and the rod casts
and strikes for you. It is a *hold*, not an auto-clicker: you still aim at a buoy and you still
have to be there. It does not fish faster than a person can either — the bite delay, the 1.2 s
strike window and one-angler-per-buoy are all unchanged, and it sends the exact same server
event a click does. What it removes is the clicking, not the waiting.

Rods and boats are hand-authored for their first sixteen and ten tiers and then keep generating
forever, so the upgrade button never greys out with nothing behind it.

Dev products: Starter Pack 200 · Coin Pouch 100 · Coin Chest 500 · Coin Vault 1,000 ·
Time Warp 200 · Instant Restock 79 · Instant Set Sail 150

Private server: 99 R$/month (set once, never reprice). Age questionnaire: answer **yes** to
paid random items (chests bought with earnable coins — odds shown, policy-gated).

## Store page

- **Name:** `Reel a Relic! [Fishing Simulator]`
- **Hook line:** `🎣 Catch 20 species across 5 oceans — and your aquarium earns WHILE YOU SLEEP! 🐠`
- Description: adapt the root game's template (features: bite-timing fishing, a species index
  with per-fish weight records, five areas to unlock, offline aquarium earnings, Feeding Frenzy
  events, daily streaks, exact odds shown on every chest).
- Thumbnails: mid-flash bite moment ("WAIT FOR IT…"), a Moonlit Leviathan reveal, the
  welcome-back offline earnings popup.

## Clip ideas (adapt the root `marketing/tiktok-scripts.md` formats)

1. The bite-timing miss/catch — "I waited 4 seconds for THIS" → Moonlit reveal.
2. "My aquarium earned 12k coins while I slept."
3. Sailing into the Abyss for the first time — the water goes black and the Leviathan bites.
4. Feeding Frenzy chaos — whole server rushing the buoys at 10x luck.

## Playtest checklist

- [ ] Cast → flash → click lands a catch; clicking early does nothing; missed flash recasts
- [ ] Both outcomes appear: a fish lands straight in the hold, a chest goes to the station
- [ ] Chest opens with the odds panel and is always Rare+; third open ever is Rare+ (pity)
- [ ] Hold counter shows fish + chests together, and fills up (boat capacity gates both)
- [ ] Catch the same species twice: the heavier one fires "HEAVIEST … YET" and updates the Index
- [ ] Dock Master lists all five areas with prices; buying area 2 teleports you and the
      Sunny Shallows species stop biting
- [ ] Set Sail: resets run, +25% coins, and **area unlocks are still there afterwards**
- [ ] Another player can't steal your claimed buoy mid-cast
- [ ] Comp yourself `AutoCast` via `Monetization.CompUserIds`: the badge appears, holding the
      button on a buoy casts and strikes without further clicks, and releasing stops it
- [ ] Buy the last authored rod, then buy again: a generated tier appears with a real name,
      more damage and a higher price — the button never dead-ends
