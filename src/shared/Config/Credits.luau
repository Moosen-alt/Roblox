--!strict
-- ATTRIBUTION for third-party assets.
--
-- This is a licence condition, not a courtesy. Creative Commons Attribution
-- (CC-BY) permits commercial use — including a monetised Roblox game — on the
-- single condition that the creator is credited. Ship the asset without the
-- credit and the licence does not cover the use, which makes it an ordinary
-- copyright problem rather than a paperwork one.
--
-- Where it has to be: "reasonable to the medium". A credits screen reachable
-- from the store is the normal answer for a game and is what this does. It does
-- not need to be on the front page — it does need to exist, be findable, and
-- name the creator and the licence.
--
-- ADDING ONE: add a row here when you add a third-party asset, in the same
-- commit. tests/check-credits.py fails the build if an entry is missing a
-- creator or a licence, because a half-filled credit is worth nothing.

local Credits = {}

export type Entry = {
	Work: string, -- what it is, in the player's words
	Creator: string, -- exactly as the creator writes their name
	License: string, -- e.g. "CC BY 4.0"
	Source: string?, -- where it came from, if there is a public page
}

Credits.Entries = {
	{
		Work = "Blue Agate Geode model",
		Creator = "ArcticGreenhouse",
		License = "CC BY 4.0",
		Source = "sketchfab.com/3d-models/blue-agate-geode-011affc99c7c47aab13dad7793e48363",
	},
} :: { Entry }

-- Everything not listed here is original to this project: every crystal, fish,
-- relic and prop is either built from primitives in code or modelled for it.
Credits.Footer = "Everything else in this game was made for it."

return Credits
