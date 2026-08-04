# Easy Obby: +1 Jump — setup

Same operator flow as the root game — **follow the root [`SETUP.md`](../../SETUP.md) for
accounts, publishing, verification, and launch strategy.** This file covers only what's
different. Open `build/game.rbxlx` in Studio and publish it as a **separate experience** under
the same group.

**Gameplay:** a 100-stage extremely easy obby where every stage pad adds **+1 Jump Power** —
and walkspeed scales with it — until you're leaping 10+ stages in a single bound (leapt-over
stages still pay out). Reach the Finish to Rebirth: jump resets, you bank a permanent +25%
jump-gain & coin multiplier, and every new server generates a fresh tower layout. Trails are
the coin sink; offline "Jump Charge" coins accrue while away. **Zero paid RNG** — no odds
panel or loot-box compliance surface at all.

## Products to create (paste IDs into `src/shared/Config/Monetization.luau`)

Gamepasses: Speed Coil 49 · 2x Coins 149 · 2x Jump Gain 249 · VIP 499 · Mega Start 999

Dev products: Skip Stage 25 · Skip 10 Stages 149 · +50 Jump Boost 75 · Instant Rebirth 199 ·
Coin Pouch 100 · Coin Chest 500

Private server: 99 R$/month (set once, never reprice). Age questionnaire: **no** paid random
items in this game. Skip-stage products are the documented obby revenue workhorse — the HUD
keeps Skip Stage one tap away.

## Store page

- **Name:** `Easy Obby: +1 Jump`
- **Hook line:** `⬆️ Every stage = +1 JUMP POWER. Get so strong you leap the whole tower! 🏆`
- Description: features — 100 easy stages, +1 jump per stage, mega leaps that skip whole
  sections, rebirth multipliers, 10 trails to unlock, daily streak rewards, a fresh tower
  layout every server.
- Thumbnails: a maxed player mid-leap over ~15 stages ("I SKIPPED THE WHOLE TOWER"), the
  +1 popup moment, a rainbow-trail rebirth flex.

## Clip ideas (adapt the root `marketing/tiktok-scripts.md` formats)

1. Split screen: stage 1 hop vs stage 95 mega-leap — "same game, 20 minutes later."
2. "MEGA LEAP! +14 stages" toast on screen mid-flight.
3. Speedrun: Finish → Rebirth → back to Finish, timer overlay.

## Playtest checklist

- [ ] First pad reached in <10 seconds; +1 Jump and coins pop on every pad
- [ ] Leaping over pads grants all skipped stages (MEGA LEAP toast)
- [ ] Falling respawns you at your checkpoint in ~2s
- [ ] Finish pad → Rebirth banks the multiplier and teleports to start
- [ ] Buy + equip a trail; it survives respawn; VIP rainbow gated correctly
- [ ] Teleport screen: VIP jumps to cleared stages; non-VIP gets the pass prompt
