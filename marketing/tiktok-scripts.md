# TikTok / YouTube Shorts — launch scripts

Short-form video is the channel that built every 2025–26 Roblox breakout, and it retains players
at ~$0.05–0.18 each versus $0.80–2.50 for paid ads. The engineered clip moment in this game is
the **crack reveal** — every script below is a variation on it.

**Cadence:** 1 clip/day for launch week, then 3–5/week for a month. Post the same clip to TikTok,
YouTube Shorts, and Instagram Reels (reformatting is free reach).

**Recording workflow (10 min/clip):** Studio → Play → Device emulator OFF, camera zoomed close →
screen-record (OBS or Win+G / QuickTime) → crop to 9:16 portrait → captions in the app, trending
low-fi/satisfying audio, volume low. First frame must already be interesting — viewers decide in
under a second.

**Account setup:** handle like `@crackageode`, bio = one line + the game link (drives the 35%
Audience Expansion revenue share — use your share link, not the plain URL).

---

### 1. "One in five hundred" (launch day)
- **Hook overlay (0–1s):** `this is a 0.2% chance…`
- **Shots:** hand hovers Crack button (1s) → slow-mo reveal burst (2s) → Celestial card with NEW!
  badge (2s) → odds panel zoom showing 0.2% (1s).
- **Caption:** `the odds panel said 0.2% and I hit it on camera 😭 #roblox #robloxsimulator #satisfying #mining`
- **Why:** rare-pull reaction clips are the proven format (Steal a Brainrot grew on exactly this).

### 2. "It earns while I sleep"
- **Hook:** `I closed the game for 8 hours…`
- **Shots:** bedtime phone-down shot or clock timelapse (1s) → login → welcome popup
  `+12,400 coins while you were away` (2s) → Collect All button press, coin counter spins up (2s).
- **Caption:** `offline earnings just hit different 💤💰 #roblox #idlegame #passiveincome`
- **Why:** the offline hook is the game's #1 retention feature — advertise the habit, not the game.

### 3. "POV: the Meteor Shower hits"
- **Hook:** `when the whole server gets 10x luck`
- **Shots:** event banner slams in (1s) → frantic mining (2s) → three fast reveals back-to-back,
  last one Epic+ (3s).
- **Caption:** `everyone STOPS when the meteor shower starts 🌠 #roblox #robloxfyp #gamingshorts`

### 4. "Satisfying cracks" (pure loop)
- **Hook:** none — just the reveal.
- **Shots:** 5 reveals cut end-to-end, rarity colors escalating, final one Celestial. Loop-friendly:
  last frame matches first.
- **Caption:** `which one was your favorite? 💎 #satisfying #asmr #roblox`
- **Why:** zero-effort watch, highest loop rate; the algorithm loves rewatches.

### 5. "I made this game" (devlog angle)
- **Hook:** `I'm a solo dev and I just launched my first Roblox game`
- **Shots:** quick cuts: code/Studio (1s) → mine wall (1s) → reveal (2s) → collection index filling
  (1s) → "it's out now" title card (1s).
- **Caption:** `built this solo — go break my leaderboard 🙏 #robloxdev #indiedev #devlog`
- **Why:** solo-dev launch stories reliably outperform; people root for you and comment.

### 6. "Before / after Recrystallize"
- **Hook:** `day 1 me vs day 7 me`
- **Shots:** rusty pick, 3 taps per geode (2s) → cut: Layer 3, laser pick shredding the wall,
  auto-crack toasts streaming (3s).
- **Caption:** `the rebirth grind is REAL #roblox #progression #simulator`

### 7. "Rate my collection"
- **Hook:** `36/48 crystals… the last 12 are cursed`
- **Shots:** slow scroll of the collection index, discovered cells glowing, camera lingers on the
  "?" cells (4s).
- **Caption:** `what am I missing? drop your rarest below 👇 #roblox #collection #completionist`
- **Why:** comment bait — replies drive distribution, and answers = free market research.

### 8. "Day 30 streak"
- **Hook:** `I logged in 30 days in a row for this`
- **Shots:** streak popup `Day 30 — MILESTONE!` (2s) → reward lands, coin counter jumps (2s) →
  buy the Coin Vault-priced upgrade you were saving for (2s).
- **Caption:** `worth it? #roblox #dailystreak #grind`

### 9. "The whole server stops"
- **Hook:** `someone just hit a Mythic and the server LIT UP`
- **Shots:** normal mining (1s) → the rare-find banner slams across the top with another player's
  name (1s) → whip the camera to the pillar of light across the cave (2s) → their character
  standing under it with the crystal spinning over their head (2s).
- **Caption:** `you can see it from anywhere on the map 😳 #roblox #robloxfyp #luck`
- **Why:** this is the strongest possible proof the rare stuff is really in the game — a stranger
  got it, not you. Social proof beats any claim you make about your own odds.

### 10. "Was the rebirth worth it"
- **Hook:** `deleting 6 hours of progress on camera`
- **Shots:** finger over Recrystallize, coins at max (1s) → the ritual: rings, white-out,
  `+150% COINS — PERMANENTLY` card (3s) → straight back to the wall, coins climbing far faster
  than before (2s).
- **Caption:** `hurts for 10 seconds, pays forever #roblox #prestige #simulator`

---

## Staging these for camera

You do not have to wait days for a Day 30 streak or get lucky on camera. There is a switch:

**Studio → open the place → ReplicatedStorage → Shared → Config → Balance → set `FilmMode = true`
→ press Play → film → close WITHOUT saving.**

It only works inside Studio and ships as `false`, so there is no way for it to reach the live
game even if you forget to undo it. What you get the moment you press Play:

| You get | Covers clips |
|---|---|
| 5,000,000 coins, top pickaxe, max backpack and racks, 6 rebirths | 6, 10 |
| Collection at 36/48, with the last 12 genuinely missing | 7 |
| Day 30 streak popup on join | 8 |
| 8 hours of offline earnings waiting to collect | 2 |
| A server event every ~12 seconds instead of every ~6 minutes | 3 |
| Deepest layer, so Epic/Legendary pulls come fast | 1, 4, 9 |

All three games have the same switch. Reel a Relic gives you the maxed rod and Feeding Frenzy;
Easy Obby gives you capped jump power for the mega-leap shot plus every trail.

### The one line you cannot stage

Film mode hands you an endgame save. It does **not** make a 0.2% pull into a 60% pull — you are
still rolling the real table, just from the best layer with the best luck, so rares come in
minutes instead of hours.

That matters for clip 1. `the odds panel said 0.2% and I hit it on camera` is only true if it
actually happened on that take. If you get impatient and boost the drop rates by hand in
`Crystals.luau`, the odds panel on screen will show the boosted number and the caption becomes a
lie your own footage disproves. Two safe fixes:

- **Keep filming.** From the deepest layer with an event running, a Celestial-tier pull is minutes
  away, and then the caption is simply true.
- **Or reword to describe the item, not your luck:** `this is the rarest crystal in the game — 0.2%`
  over any footage of it is honest no matter how you got there.

Same rule for clip 8: `I logged in 30 days in a row` is a claim about you. `Day 30 pays 5,000 coins
and a free Charged Geode` is a claim about the game — stage that one freely.

---

**Read the numbers, not the vibes:** a clip "works" when profile taps → game visits move (check
Analytics acquisition sources). Double down on whichever format converts; kill the rest. Reply to
every comment in hour one — early engagement decides distribution on both platforms.
