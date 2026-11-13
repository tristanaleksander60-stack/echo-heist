--!strict
-- Shared/Heist/IntroRig: Sir Hoardsworth's 17-part rigid rig (assets/blender/intro.py; the STYLE_BIBLE §12 rules,
-- like Gus). Each part's pivot is its joint; origins and bounds (relative to the pivot) are the kit manifest's
-- (assets/fbx/kit_manifest.json, checked by tests/unit/HeistIntro.spec.luau). Heist/Cinematic poses the mesh rig
-- (ReplicatedStorage/EH_IntroKit) or, until it arrives, a box rig sized from these bounds:
-- world[joint] = world[parent] * C0 * pose, C0 = origin - parentOrigin. Pure data: Lune reads it.

local IntroRig = {}

export type Part = {
	name: string,
	joint: string,
	parent: string?,
	origin: { number }, -- joint position at rest (model space: feet on the floor at 0, facing -Z)
	min: { number }, -- bounds relative to the pivot
	max: { number },
	role: string, -- box-rig colour role
}

local function part(
	name: string,
	joint: string,
	parent: string?,
	origin: { number },
	min: { number },
	max: { number },
	role: string
): Part
	return table.freeze({
		name = name,
		joint = joint,
		parent = parent,
		origin = table.freeze(origin),
		min = table.freeze(min),
		max = table.freeze(max),
		role = role,
	})
end

-- Parent first. Origins and bounds: the kit manifest.
-- stylua: ignore
IntroRig.PARTS = table.freeze({
	part("Hoardsworth_LowerTorso", "Root", nil, { 0, 3.55, 0 }, { -0.72, -1.43, -0.534 }, { 0.72, 0.55, 0.722 }, "legs"),
	part("Hoardsworth_UpperTorso", "Waist", "Hoardsworth_LowerTorso", { 0, 4, 0 }, { -0.94, -0.08, -0.717 }, { 0.94, 2.62, 0.662 }, "coat"),
	part("Hoardsworth_Head", "Neck", "Hoardsworth_UpperTorso", { 0, 6.1, 0 }, { -0.635, -0.08, -0.8 }, { 0.635, 1.36, 0.395 }, "skin"),
	part("Hoardsworth_Hat", "HatAttach", "Hoardsworth_Head", { 0, 7.36, 0 }, { -0.8, -0.02, -0.72 }, { 0.8, 1.4, 0.72 }, "hat"),
	part("Hoardsworth_Monocle", "Monocle", "Hoardsworth_Head", { 0.2, 6.92, -0.47 }, { -0.21, -0.517, -0.03 }, { 0.265, 0.205, 0.319 }, "gold"),
	part("Hoardsworth_RightUpperArm", "RightShoulder", "Hoardsworth_UpperTorso", { 0.92, 5.8, 0 }, { -0.3, -1.079, -0.285 }, { 0.333, 0.3, 0.285 }, "coat"),
	part("Hoardsworth_RightLowerArm", "RightElbow", "Hoardsworth_RightUpperArm", { 1.04, 4.8, 0 }, { -0.215, -0.973, -0.238 }, { 0.303, 0.071, 0.238 }, "coat"),
	part("Hoardsworth_RightHand", "RightWrist", "Hoardsworth_RightLowerArm", { 1.1, 3.9, 0 }, { -0.25, -0.502, -0.23 }, { 0.168, 0.022, 0.19 }, "glove"),
	part("Hoardsworth_LeftUpperArm", "LeftShoulder", "Hoardsworth_UpperTorso", { -0.92, 5.8, 0 }, { -0.333, -1.079, -0.285 }, { 0.3, 0.3, 0.285 }, "coat"),
	part("Hoardsworth_LeftLowerArm", "LeftElbow", "Hoardsworth_LeftUpperArm", { -1.04, 4.8, 0 }, { -0.303, -0.973, -0.238 }, { 0.215, 0.071, 0.238 }, "coat"),
	part("Hoardsworth_LeftHand", "LeftWrist", "Hoardsworth_LeftLowerArm", { -1.1, 3.9, 0 }, { -0.168, -0.502, -0.23 }, { 0.25, 0.022, 0.19 }, "glove"),
	part("Hoardsworth_RightUpperLeg", "RightHip", "Hoardsworth_LowerTorso", { 0.36, 3.42, 0 }, { -0.22, -1.56, -0.209 }, { 0.22, 0.06, 0.209 }, "legs"),
	part("Hoardsworth_RightLowerLeg", "RightKnee", "Hoardsworth_RightUpperLeg", { 0.36, 1.92, 0 }, { -0.18, -1.56, -0.171 }, { 0.18, 0.06, 0.171 }, "legs"),
	part("Hoardsworth_RightFoot", "RightAnkle", "Hoardsworth_RightLowerLeg", { 0.36, 0.42, 0 }, { -0.21, -0.42, -0.95 }, { 0.21, 0.2, 0.3 }, "shoe"),
	part("Hoardsworth_LeftUpperLeg", "LeftHip", "Hoardsworth_LowerTorso", { -0.36, 3.42, 0 }, { -0.22, -1.56, -0.209 }, { 0.22, 0.06, 0.209 }, "legs"),
	part("Hoardsworth_LeftLowerLeg", "LeftKnee", "Hoardsworth_LeftUpperLeg", { -0.36, 1.92, 0 }, { -0.18, -1.56, -0.171 }, { 0.18, 0.06, 0.171 }, "legs"),
	part("Hoardsworth_LeftFoot", "LeftAnkle", "Hoardsworth_LeftLowerLeg", { -0.36, 0.42, 0 }, { -0.21, -0.42, -0.95 }, { 0.21, 0.2, 0.3 }, "shoe"),
})

-- Box-rig colours by role (hex; Heist/Cinematic turns them into Color3): the eh_palette cells the mesh uses.
IntroRig.ROLE_HEX = table.freeze({
	coat = "#8C2F4B",
	legs = "#2A2D52",
	skin = "#D09673",
	hat = "#1C1F3B",
	gold = "#A8987A",
	glove = "#C0C3D5",
	shoe = "#1C1F3B",
} :: { [string]: string })

IntroRig.MONOCLE = "Hoardsworth_Monocle" -- the glint sits at its pivot
IntroRig.HEIGHT = 8.76 -- studs, feet to hat top

return table.freeze(IntroRig)
