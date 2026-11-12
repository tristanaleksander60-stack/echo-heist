--!strict
-- Heist/RigJoints: the joints that hold an avatar rig together (PLAN_STEAM_PLUS §1 S1).
-- Older rigs use Motor6Ds; the 2026 engine builds avatar rigs
-- (Players:CreateHumanoidModelFromDescriptionAsync) from kinematic AnimationConstraints joined
-- through the rig attachments. A joint is whole when both its ends are still in the rig.
-- Used by the server strip (Avatars), the client rigs (Rigs, CloneHealth) and the engine tests.

local RigJoints = {}

function RigJoints.whole(rig: Instance): number
	local n = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 and p0:IsDescendantOf(rig) and p1:IsDescendantOf(rig) then
				n += 1
			end
		elseif d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if d.Enabled and a0 and a1 and a0:IsDescendantOf(rig) and a1:IsDescendantOf(rig) then
				n += 1
			end
		end
	end
	return n
end

return RigJoints
