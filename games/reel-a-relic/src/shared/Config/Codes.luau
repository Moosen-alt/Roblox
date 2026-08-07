--!strict
-- REDEEM CODES.
--
-- Codes are a marketing instrument first and a reward second. Roblox players
-- actively search `"<game name> codes"`, which means:
--
--   * free discovery — a codes page or video that ranks brings players who were
--     never going to find the game through Roblox search,
--   * a reason to follow the group and the socials, because that is where codes
--     get announced,
--   * a lever to spike concurrent players on demand: dropping a code is the
--     cheapest way to pull lapsed players back on an update day, and concurrent
--     players is what the front page actually sorts on.
--
-- EDITING THIS FILE IS THE WHOLE WORKFLOW. Add a row, push, and CI republishes
-- the place — no Studio, no code changes anywhere else. That is deliberate: a
-- live-ops tool nobody can operate without a developer is not a live-ops tool.
--
-- Rules that keep this honest and safe:
--   * Codes give coins and chests. Never gamepasses, never anything a player
--     paid Robux for — that devalues a real purchase somebody made.
--   * `Coins` is a MULTIPLIER, not an amount. Rewards scale with the deepest
--     water the player has unlocked, so one code is worth having on day 1 and
--     still worth having on day 30. A flat number can only ever be right once.
--   * One redemption per player, enforced on the server. The client's job is to
--     type a string into a box.
--   * Expiries are optional and honest: a code with `Expires` set stops working
--     at that moment, and the panel says so rather than pretending it was wrong.

local Codes = {}

export type CodeDef = {
	Code: string, -- matched case-insensitively, whitespace trimmed
	Coins: number?, -- multiplier on the scaled base (see Balance.CodeRewardBase)
	Chests: number?, -- treasure chests straight into the hold
	Note: string, -- shown on success; say what they got and why
	Expires: number?, -- os.time() cutoff; nil = runs forever
}

-- Launch set. Keep a couple of evergreen ones so a player who finds an old
-- video still gets something — a dead code is a bad first impression.
Codes.List = {
	{ Code = "REELGOOD", Coins = 3, Chests = 3, Note = "Welcome aboard, captain!" },
	{ Code = "FIRSTCAST", Coins = 2, Chests = 2, Note = "Thanks for playing on day one!" },
	{ Code = "KELPFOREST", Coins = 2.5, Chests = 2, Note = "The otters say hello." },
	{ Code = "ABYSS", Coins = 4, Chests = 4, Note = "Something is down there." },
	{ Code = "TIDEJEWEL", Coins = 3.5, Chests = 3, Note = "A gift from the dragon's palace." },
	{ Code = "LIKEANDFAV", Coins = 2, Chests = 1, Note = "Thanks for the like — it genuinely helps!" },
} :: { CodeDef }

-- Canonical form: upper case, no surrounding whitespace. Applied to both the
-- table above and whatever the player typed, so "  reelgood " matches.
function Codes.Normalise(input: string): string
	return (input:gsub("^%s+", ""):gsub("%s+$", "")):upper()
end

function Codes.Find(input: string): CodeDef?
	local wanted = Codes.Normalise(input)
	for _, def in Codes.List do
		if Codes.Normalise(def.Code) == wanted then
			return def
		end
	end
	return nil
end

return Codes
