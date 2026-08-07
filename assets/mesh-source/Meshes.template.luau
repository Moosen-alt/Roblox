-- Reel a Relic mesh template
-- Keep rows commented until you have a real Roblox MeshId.
-- check-models.py intentionally rejects Mesh = 0.
-- Included OBJ files are centered, Y-up, and fish face +X.
-- Start with Scale = 1.0 and no Rotation.

local Meshes = {}

Meshes.Fish = {
    -- ["Anchovy"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Anchovy.obj
    -- ["Mackerel"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Mackerel.obj
    -- ["Sea Bass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Sea_Bass.obj
    -- ["Flounder"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Flounder.obj
    -- ["Red Snapper"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Red_Snapper.obj
    -- ["Seahorse"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Seahorse.obj
    -- ["Sailfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Sailfish.obj
    -- ["Kelp Bass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Kelp_Bass.obj
    -- ["Garibaldi"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Garibaldi.obj
    -- ["Sheephead"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Sheephead.obj
    -- ["Moray Eel"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Moray_Eel.obj
    -- ["Leopard Shark"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Leopard_Shark.obj
    -- ["Giant Sea Bass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Giant_Sea_Bass.obj
    -- ["Clownfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Clownfish.obj
    -- ["Parrotfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Parrotfish.obj
    -- ["Blue Tang"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Blue_Tang.obj
    -- ["Lionfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Lionfish.obj
    -- ["Reef Shark"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Reef_Shark.obj
    -- ["Manta Ray"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Manta_Ray.obj
    -- ["Hammerhead"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Hammerhead.obj
    -- ["Lanternfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Lanternfish.obj
    -- ["Hatchetfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Hatchetfish.obj
    -- ["Viperfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Viperfish.obj
    -- ["Gulper Eel"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Gulper_Eel.obj
    -- ["Anglerfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Anglerfish.obj
    -- ["Barreleye"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Barreleye.obj
    -- ["Oarfish"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Oarfish.obj
    -- ["Giant Isopod"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Giant_Isopod.obj
    -- ["Dumbo Octopus"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Dumbo_Octopus.obj
    -- ["Frilled Shark"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Frilled_Shark.obj
    -- ["Goblin Shark"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Goblin_Shark.obj
    -- ["Colossal Squid"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Colossal_Squid.obj
    -- ["Megalodon"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/fish/Megalodon.obj
}

Meshes.Relic = {
    -- ["Rusty Anchor"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Rusty_Anchor.obj
    -- ["Message in a Bottle"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Message_in_a_Bottle.obj
    -- ["Conch Shell"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Conch_Shell.obj
    -- ["Silver Doubloon"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Silver_Doubloon.obj
    -- ["Hurricane Lamp"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Hurricane_Lamp.obj
    -- ["Spanish Emerald"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Spanish_Emerald.obj
    -- ["Galleon Bell"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Galleon_Bell.obj
    -- ["Cannery Token"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Cannery_Token.obj
    -- ["Ship's Compass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Ships_Compass.obj
    -- ["Abalone Shell"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Abalone_Shell.obj
    -- ["Diver's Helmet"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Divers_Helmet.obj
    -- ["Glass Float"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Glass_Float.obj
    -- ["Captain's Spyglass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Captains_Spyglass.obj
    -- ["Shell Lei"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Shell_Lei.obj
    -- ["Whale Tooth Pendant"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Whale_Tooth_Pendant.obj
    -- ["Tiki Idol"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Tiki_Idol.obj
    -- ["Pirate Cutlass"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Pirate_Cutlass.obj
    -- ["Coral Crown"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Coral_Crown.obj
    -- ["Sonar Beacon"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Sonar_Beacon.obj
    -- ["Submersible Porthole"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Submersible_Porthole.obj
    -- ["Black Box"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Black_Box.obj
    -- ["Golden Astrolabe"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Golden_Astrolabe.obj
    -- ["Mermaid's Mirror"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Mermaids_Mirror.obj
    -- ["Oni Mask"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Oni_Mask.obj
    -- ["Temple Bell"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Temple_Bell.obj
    -- ["Sunken Crown"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Sunken_Crown.obj
    -- ["Tide Jewel"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Tide_Jewel.obj
    -- ["Poseidon's Trident"] = { Mesh = 0, Scale = 1.0 }, -- reel-a-relic/relics/Poseidons_Trident.obj
}

return Meshes
