--!strict
-- Shared/Heist/Scenario: golden-frame staging (docs/GOLDEN_FRAMES.md "Capture", PLAN_STEAM_PLUS
-- §3.3 and §8.1 R3 step 3). In Studio, set the Workspace attribute EH_Scenario before Play:
--   G1        L1 "Back Room", you at the street spawn (the gameplay camera is the shot)
--   G2        L5 Clone Party with 7 clones from the level's solution recordings, so run 1 is
--             you + 7 = "8 OF ME"; the camera is the wide pull-back (every copy in the central 32 %)
--   G3        the garage, a 3/4 shot of the first van bay
--   TYPE      G1 plus the type specimen overlay (decision D8)
--   INTRO     the story intro (Heist/Cinematic) over the garage, whatever the profile says
--   CLONE_AB  G2; EH_Variant = "B" strips the clone templates' textures and clothing (the
--             hologram arm of the recognisability A/B), "A" (default) keeps them
-- Pure (no engine calls), so tests/unit/HeistScenario.spec.luau checks the gate. Every caller
-- passes RunService:IsStudio() as `isStudio`: a live server never stages (the same spec scans
-- the sources for that).

local Scenario = {}

Scenario.ATTRIBUTE = "EH_Scenario"
Scenario.VARIANT_ATTRIBUTE = "EH_Variant"
Scenario.TAPES = 7 -- G2: clones seeded from the solution, + you = 8 OF ME

export type Spec = {
	level: string?, -- LevelSpec id to start (nil = stay in the garage)
	tapes: number?, -- solution recordings seeded into your deck before run 1
	shot: string, -- the camera: "G1" (gameplay), "G2" (pull-back), "G3" (garage bay), "INTRO" (the cinematic)
	specimen: boolean?, -- the type specimen overlay
	variant: boolean?, -- reads EH_Variant (A / B)
}

Scenario.SPECS = table.freeze({
	G1 = table.freeze({ level = "cs1_back_room", shot = "G1" }),
	G2 = table.freeze({ level = "cs5_clone_party", tapes = Scenario.TAPES, shot = "G2" }),
	G3 = table.freeze({ shot = "G3" }),
	TYPE = table.freeze({ level = "cs1_back_room", shot = "G1", specimen = true }),
	CLONE_AB = table.freeze({ level = "cs5_clone_party", tapes = Scenario.TAPES, shot = "G2", variant = true }),
	INTRO = table.freeze({ shot = "INTRO" }), -- the garage under the story intro (Heist/Loading plays it)
} :: { [string]: Spec })

-- The scenario to stage, or nil. Only in Studio (isStudio = RunService:IsStudio()) and only
-- for a known name (any case, surrounding spaces ignored).
function Scenario.resolve(isStudio: boolean, value: any): string?
	if isStudio ~= true or type(value) ~= "string" then
		return nil
	end
	local name = string.upper((string.gsub(value, "^%s*(.-)%s*$", "%1")))
	return if Scenario.SPECS[name] then name else nil
end

function Scenario.spec(name: string?): Spec?
	return if name then Scenario.SPECS[name] else nil
end

-- "A" (textured clones, default) or "B" (stripped hologram) for CLONE_AB.
function Scenario.variant(value: any): string
	return if type(value) == "string" and string.upper(value) == "B" then "B" else "A"
end

return table.freeze(Scenario)
