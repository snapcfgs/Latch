--!strict
--[[
	VFX helpers — Parts, Beams, Highlights only.
	BUDGET: Prefer short lifetimes; cap concurrent instances.
	Avoid ParticleEmitters for mobile performance (DESIGN_SPEC).
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Shared.Constants)

local activeCount = 0

local VFX = {}

local function canSpawn(): boolean
	return activeCount < Constants.MaxConcurrentAbilityVFX
end

local function track(instance: Instance, lifetime: number)
	activeCount += 1
	local capped = math.min(lifetime, Constants.AbilityVFXLifetimeCap)
	Debris:AddItem(instance, capped)
	task.delay(capped, function()
		activeCount = math.max(0, activeCount - 1)
	end)
end

--[[ Thin Part trail along a path (Skid dash). Short lifetime, no particles. ]]
function VFX.DashTrail(origin: Vector3, direction: Vector3, length: number, color: Color3?)
	if not canSpawn() then
		return
	end
	local dir = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, -1)
	local part = Instance.new("Part")
	part.Name = "LatchDashTrail"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(80, 200, 255)
	part.Transparency = 0.35
	part.Size = Vector3.new(0.35, 0.35, math.clamp(length, 2, 20))
	part.CFrame = CFrame.lookAt(origin + dir * (part.Size.Z / 2), origin + dir * length)
	part.Parent = workspace
	track(part, 0.35)

	local tween = TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.1, 0.1, part.Size.Z),
	})
	tween:Play()
end

--[[ Beam between two attachments for a brief streak. ]]
function VFX.BeamStreak(a: Vector3, b: Vector3, color: Color3?)
	if not canSpawn() then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "LatchBeamHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Position = a
	holder.Parent = workspace

	local att0 = Instance.new("Attachment")
	att0.WorldPosition = a
	att0.Parent = holder
	local att1 = Instance.new("Attachment")
	att1.WorldPosition = b
	att1.Parent = holder

	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Width0 = 0.4
	beam.Width1 = 0.15
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color or Color3.fromRGB(120, 220, 255))
	beam.Transparency = NumberSequence.new(0.2, 1)
	beam.Parent = holder
	track(holder, 0.25)
end

--[[ Explosion as expanding translucent sphere (grenade). No ParticleEmitters. ]]
function VFX.ExplosionSphere(position: Vector3, radius: number, color: Color3?)
	if not canSpawn() then
		return
	end
	local part = Instance.new("Part")
	part.Name = "LatchExplosion"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.ForceField
	part.Color = color or Color3.fromRGB(255, 140, 40)
	part.Transparency = 0.4
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = workspace
	track(part, 0.4)

	local tween = TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
end

--[[ Highlight outline for Jolt mark / Splice panel. ]]
function VFX.AttachHighlight(adornee: Instance, fill: Color3, outline: Color3, lifetime: number): Highlight?
	if not canSpawn() then
		return nil
	end
	local hl = Instance.new("Highlight")
	hl.Name = "LatchHighlight"
	hl.Adornee = adornee
	hl.FillColor = fill
	hl.OutlineColor = outline
	hl.FillTransparency = 0.7
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = adornee
	track(hl, lifetime)
	return hl
end


--[[ Smoke Can fog — translucent sphere + soft Beam spokes (no ParticleEmitters). ]]
function VFX.SmokeSphere(position: Vector3, radius: number, duration: number, color: Color3?)
	if not canSpawn() then
		return
	end
	local life = math.clamp(duration, 1, Constants.AbilityVFXLifetimeCap)
	local folder = Instance.new("Folder")
	folder.Name = "LatchSmoke"
	folder.Parent = workspace

	local core = Instance.new("Part")
	core.Name = "SmokeCore"
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Material = Enum.Material.ForceField
	core.Color = color or Color3.fromRGB(160, 170, 180)
	core.Transparency = 0.55
	core.Size = Vector3.new(2, 2, 2)
	core.Position = position
	core.Parent = folder

	local grow = TweenService:Create(core, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 0.72,
	})
	grow:Play()

	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * (radius * 0.35)
		local tip = Instance.new("Part")
		tip.Name = "SmokeSpoke"
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.Transparency = 1
		tip.Size = Vector3.new(0.1, 0.1, 0.1)
		tip.Position = position + offset
		tip.Parent = folder

		local att0 = Instance.new("Attachment")
		att0.Parent = core
		local att1 = Instance.new("Attachment")
		att1.Parent = tip
		local beam = Instance.new("Beam")
		beam.Attachment0 = att0
		beam.Attachment1 = att1
		beam.Width0 = radius * 0.5
		beam.Width1 = radius * 0.2
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(color or Color3.fromRGB(150, 160, 170))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(1, 0.95),
		})
		beam.Parent = tip
	end

	track(folder, life)
	task.delay(math.max(0.1, life - 0.8), function()
		if core.Parent then
			TweenService:Create(core, TweenInfo.new(0.75), { Transparency = 1 }):Play()
		end
	end)
end

function VFX.GetActiveCount(): number
	return activeCount
end

return VFX
