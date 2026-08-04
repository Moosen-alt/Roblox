# Reel a Relic! [Fishing Simulator] — setup

Same engine and operator flow as the root game — **follow the root [`SETUP.md`](../../SETUP.md)
for accounts, publishing, verification, and launch strategy.** This file covers only what's
different. Open `build/game.rbxlx` in Studio and publish it as a **separate experience** under
the same group.

**Gameplay:** click a glowing buoy to cast → wait for the white flash → click during the flash
to land a treasure chest (better rods bite faster and can double-hook) → open chests at the
Treasure Chests station (odds panel included) → display relics in the Aquarium where they earn
coins **while offline** → Set Sail (rebirth) into deeper waters. 48-relic collection index,
Feeding Frenzy / Moon Tide server events, clock-synced Chest Shop.

## Products to create (paste IDs into `src/shared/Config/Monetization.luau`)

Gamepasses: Auto-Open 100 · 2x Coins 250 · 2x Luck 350 · Triple Open 450 ·
Overnight Aquarium 500 · VIP Sea Captain 1,000

Dev products: Starter Pack 200 · Coin Pouch 100 · Coin Chest 500 · Coin Vault 1,000 ·
Time Warp 200 · Instant Restock 79 · Instant Set Sail 150

Private server: 99 R$/month (set once, never reprice). Age questionnaire: answer **yes** to
paid random items (chests bought with earnable coins — odds shown, policy-gated).

## Store page

- **Name:** `Reel a Relic! [Fishing Simulator]`
- **Hook line:** `🎣 Hook glowing chests, collect 48 lost relics, and your aquarium earns WHILE YOU SLEEP! 🐠`
- Description: adapt the root game's template (features: bite-timing fishing, 48 relics,
  offline aquarium earnings, 5 waters to unlock, Feeding Frenzy events, daily streaks,
  exact odds shown on every chest).
- Thumbnails: mid-flash bite moment ("WAIT FOR IT…"), a Moonlit Leviathan Heart reveal,
  the welcome-back offline earnings popup.

## Clip ideas (adapt the root `marketing/tiktok-scripts.md` formats)

1. The bite-timing miss/catch — "I waited 4 seconds for THIS" → Moonlit reveal.
2. "My aquarium earned 12k coins while I slept."
3. Feeding Frenzy chaos — whole server rushing the buoys at 10x luck.

## Playtest checklist

- [ ] Cast → flash → click lands a chest; clicking early does nothing; missed flash recasts
- [ ] Chest opens with odds panel; third chest ever is Rare+ (pity)
- [ ] Display a relic in the Aquarium, rejoin: welcome popup reports offline coins
- [ ] Set Sail at 10,000 coins: resets run, +25% coins, Kelp Forest announced, relics kept
- [ ] Another player can't steal your claimed buoy mid-cast
