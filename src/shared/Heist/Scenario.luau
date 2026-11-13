--!strict
-- Shared/Heist/Scenario: golden-frame staging (docs/GOLDEN_FRAMES.md "Capture", PLAN_STEAM_PLUS
-- §3.3 and §8.1 R3 step 3; re-specced for first person and the Rookie, REVIEW_STEAM_PLUS #4). In Studio, set the
-- Workspace attribute EH_Scenario before Play:
--   G1        L1 "Back Room" in first person from the street spawn (eye ~3.8, your Rookie hands), looking at
--             the shop front where the cash glints through the window, tilted up to the tenement and the
--             aurora (Config.Heist.CAMERA.GOLDEN.G1)
--   G2        L5 Clone Party with 7 clones from the level's solution recordings, so run 1 is
--             you + 7 = "8 OF ME" (eight Rookies in your crew colours); the camera is the moment's pull-back
--   G3        the warehouse hideout in first person, standing at the vans with the job board
--             (Config.Heist.CAMERA.GOLDEN.G3: where you stand and what you look at)
--   TYPE      G1 plus the type specimen overlay (decision D8)
--   INTRO     the story intro (Heist/Cinematic) over the garage, whatever the profile says
--   TUTORIAL  replay the mandatory tutorial (L1 "Back Room" with the run coach), whatever the profile says; no
--             staged camera (shot "PLAY": you play it as a new player would)
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
	shot: string, -- the camera: "G1" (first person, L1), "G2" (pull-back), "G3" (first person, the hideout), "INTRO",
	-- "PLAY" (no staging: the game's own camera)
	fp: boolean?, -- first person: the camera stays in your eyes (hands, reticle, HUD); the look is staged
	specimen: boolean?, -- the type specimen overlay
	variant: boolean?, -- reads EH_Variant (A / B)
}

Scenario.SPECS = table.freeze({
	G1 = table.freeze({ level = "cs1_back_room", shot = "G1", fp = true }),
	G2 = table.freeze({ level = "cs5_clone_party", tapes = Scenario.TAPES, shot = "G2" }),
	G3 = table.freeze({ shot = "G3", fp = true }),
	TYPE = table.freeze({ level = "cs1_back_room", shot = "G1", fp = true, specimen = true }),
	CLONE_AB = table.freeze({ level = "cs5_clone_party", tapes = Scenario.TAPES, shot = "G2", variant = true }),
	INTRO = table.freeze({ shot = "INTRO" }), -- the garage under the story intro (Heist/Loading plays it)
	TUTORIAL = table.freeze({ level = "cs1_back_room", shot = "PLAY" }), -- the RUN2 CLARITY track's replay
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

-- The first-person look from an eye to a point: yaw in degrees (0 = toward -Z, positive turns toward -X, as
-- Heist/CameraDirector.lookFrame takes it) and pitch in degrees DOWN (negative looks up).
function Scenario.lookAt(eye: { number }, target: { number }): (number, number)
	local dx, dy, dz = target[1] - eye[1], target[2] - eye[2], target[3] - eye[3]
	local yaw = math.deg(math.atan2(-dx, -dz))
	local pitch = math.deg(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
	return yaw, pitch
end

-- A first-person golden frame's look (G1 / G3): where the eye stands (level space; nil = wherever you spawned) and
-- the yaw / pitch it looks at. g: Config.Heist.CAMERA.GOLDEN.G1 / G3; eye: your eye position (level space);
-- target: G1's look target (the level's loot of g.LOOT, level space) or nil for G3's LOOK_AT. The pitch is g.PITCH
-- when set (G1 tilts up to show the tenement and the aurora), else the pitch to the target.
function Scenario.fpLook(g: any, eye: { number }, target: { number }?): (number, number)
	local aim = target or g.LOOK_AT
	local yaw, pitch = Scenario.lookAt(eye, aim)
	return yaw + (g.YAW_OFFSET or 0), if g.PITCH ~= nil then g.PITCH else pitch
end

-- "A" (textured clones, default) or "B" (stripped hologram) for CLONE_AB.
function Scenario.variant(value: any): string
	return if type(value) == "string" and string.upper(value) == "B" then "B" else "A"
end

return table.freeze(Scenario)
