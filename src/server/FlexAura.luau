--!strict
-- Your rarest pull, floating over your head, for everyone in the server to see.
--
-- Coins are a private number. This is the public one — the reason to keep
-- cracking after the shop is bought out, and the reason a new player walking
-- past someone's Celestial Diamond believes the drop table is real.
--
-- The server only publishes four attributes on the Player; every client builds
-- and spins the actual crystal itself (see the client FlexAura), so a lobby
-- full of showing-off costs no bandwidth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crystals = require(Shared.Config.Crystals)

local FlexAura = {}

-- Saves store the rarest find as one display string ("Celestial Diamond").
-- Split it back apart rather than migrating every existing profile.
function FlexAura.SplitName(name: string): (string, string)
	for _, mutation in Crystals.MutationNames do
		if mutation ~= "Normal" and string.sub(name, 1, #mutation + 1) == mutation .. " " then
			return string.sub(name, #mutation + 2), mutation
		end
	end
	return name, "Normal"
end

function FlexAura.Set(player: Player, baseName: string, mutationName: string, value: number)
	local def = Crystals.GetBase(baseName)
	if not def then
		return
	end
	local color = def.Color
	local mutation = Crystals.GetMutation(mutationName)
	if mutation and mutation.Color then
		color = def.Color:Lerp(mutation.Color, 0.45)
	end
	player:SetAttribute("FlexBase", baseName)
	player:SetAttribute("FlexMut", mutationName)
	player:SetAttribute("FlexTier", def.Tier)
	player:SetAttribute("FlexColor", color)
	player:SetAttribute("FlexValue", value)
end

-- Called once the profile is loaded, so returning players walk in wearing the
-- best thing they have ever found.
function FlexAura.Apply(player: Player, data: any)
	local name = data.Stats and data.Stats.RarestName
	if typeof(name) ~= "string" or name == "" then
		return
	end
	local base, mutation = FlexAura.SplitName(name)
	FlexAura.Set(player, base, mutation, data.Stats.RarestValue or 0)
end

return FlexAura
