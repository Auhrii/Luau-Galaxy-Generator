local module = {}

--// DECLARATIONS

local MathUtils = require(script.Parent.MathUtils)

local colourCorrection = 0
local showGlint = true
local wackyMode = 0

local prefabStar = Instance.new("Part")
prefabStar.Anchored = true
prefabStar.Material = Enum.Material.Neon
prefabStar.Shape = Enum.PartType.Ball
prefabStar.CastShadow = false
prefabStar.CanCollide = false

-- Star classification definitions; by defining a minimum and maximum mass band, we can find which possible classes a generated
-- star can be based purely on its mass. Not 100% realistic, but it's a good fast approximation.
local starTypes = {
	["O"] = {
		description = "",
		minMass = 16,
		maxMass = 1e309,
		minTemp = 30000,
		maxTemp = 50000,
		subClasses = {1e309, 1e309, 1e309, 120, 85.31, 60, 43.71, 30.85, 23, 15}, -- O0V through O2V just don't exist, apparently
		lumClass = "V"
	},
	["B"] = {
		description = "",
		minMass = 2,
		maxMass = 17.7,
		minTemp = 10000,
		maxTemp = 30000,
		subClasses = {17.7, 11, 7.3, 5.4, 5.1, 4.7, 4.3, 3.92, 3.38, 2},
		lumClass = "V"
	},
	["A"] = {
		description = "",
		minMass = 1.65,
		maxMass = 2.18,
		minTemp = 7400,
		maxTemp = 10000,
		subClasses = {2.18, 2.05, 1.98, 1.93, 1.88, 1.86, 1.83, 1.81, 1.77, 1.65},
		lumClass = "V"
	},
	["F"] = {
		description = "",
		minMass = 1,
		maxMass = 1.675,
		minTemp = 6000,
		maxTemp = 7600,
		subClasses = {1.61, 1.5, 1.46, 1.44, 1.38, 1.33, 1.25, 1.21, 1.18, 1},
		lumClass = "V"
	},
	["G"] = {
		description = "",
		minMass = 0.9,
		maxMass = 1.1,
		minTemp = 5300,
		maxTemp = 6000,
		subClasses = {1.06, 1.03, 1, 0.99, 0.985, 0.98, 0.97, 0.95, 0.94, 0.9},
		lumClass = "V"
	},
	["K"] = {
		description = "",
		minMass = 0.5,
		maxMass = 0.9,
		minTemp = 3900,
		maxTemp = 5200,
		subClasses = {0.88, 0.86, 0.82, 0.78, 0.73, 0.7, 0.69, 0.64, 0.62, 0.5},
		lumClass = "V"
	},
	["M"] = {
		description = "",
		minMass = 0.075,
		maxMass = 0.8,
		minTemp = 2000,
		maxTemp = 4000,
		subClasses = {0.57, 0.5, 0.44, 0.37, 0.23, 0.162, 0.102, 0.09, 0.085, 0.075},
		lumClass = "V"
	}
}

-- A lerp table for colours based on star temperature; a linear search is performed when a class (and temperature) are assigned to a
-- star to get the temperatures in this table that are above and below it. No clamping has to be performed, as the temperature
-- ranges defined above are within or at the maximum bounds here.
local temperatures = {
	[1900] = Color3.fromRGB(255, 147, 41),
	[2600] = Color3.fromRGB(255, 197, 143),
	[2850] = Color3.fromRGB(255, 214, 170),
	[3200] = Color3.fromRGB(255, 241, 224),
	[5200] = Color3.fromRGB(255, 250, 244),
	[5400] = Color3.fromRGB(255, 255, 251),
	[6000] = Color3.fromRGB(255, 255, 255),
	[7000] = Color3.fromRGB(201, 226, 255),
	[20000] = Color3.fromRGB(64, 156, 255),
	[50000] = Color3.fromRGB(16, 64, 255) -- maxed out the blue value 3 entries ago, reduce the other values to approximate it leaving the visible spectrum
}

--// FUNCTIONS

-- Note about the arguments: Roblox's Luau allows strict typing, as well as nullable types.
-- Assigns a class to a star based on its mass, then assigns a random luminosity and a radius based on it, and a random temperature
-- within that star classification's range. May produce somewhat unrealistic results, but once again the aim was performance, not
-- strict accuracy.
function AssignStarClass(star: BasePart, galaxyScalar: number, position: Vector3, rng: Random?)
	rng = typeof(rng) == "Random" and rng or Random.new()
	local coreDistance = math.abs(position.Magnitude / galaxyScalar) ^ 2
	local eclipticDistance = math.abs(position.Y / galaxyScalar) ^ 2
	
	local mass = math.clamp(MathUtils:Gaussian(1, 0.92) / math.max(coreDistance, 0.01) / math.max(eclipticDistance, 0.01), 0.08, 1.92)
	if mass > 1 then
		mass = mass * (1 + math.abs(MathUtils:Gaussian(0, 32)))
	end
	local luminosity = mass ^ (3.5 + rng:NextNumber(-0.1, 0.1))
	local radius = math.sqrt(luminosity)
	
	local spectralClass = "Unknown"
	local validClasses = {}
	for className, data in pairs(starTypes) do
		if mass >= data.minMass and mass <= data.maxMass then
			table.insert(validClasses, className)
		end
	end
	local spectralClass, spectralSubclass = validClasses[rng:NextInteger(1, #validClasses)], 0
	local classData = starTypes[spectralClass]
	for subClass, minMass in pairs(classData.subClasses) do
		spectralSubclass = subClass - 1
		if mass > minMass then break end
	end
	
	-- Generate the temperature first as a strict lerped value between the classification's min and max depending on where the mass
	-- rests, then apply a slight variance to it. Can produce stars that are cooler than they should be in edge cases where the mass
	-- is at either extreme.
	local massPerc = (mass - classData.minMass) / classData.maxMass
	local temperature = classData.minTemp + ((classData.maxTemp - classData.minTemp) * massPerc)
	temperature *= 1 + rng:NextNumber(-0.025, 0.025)
	local minK, maxK
	for k, colour in pairs(temperatures) do
		if temperature >= k then minK = k end
		if temperature <= k then maxK = k end
		if minK and maxK then break end
	end
	local tempColour = temperatures[minK]:Lerp(temperatures[maxK], (temperature - minK) / maxK)
	local correctedColour = tempColour
	if colourCorrection then
		correctedColour = tempColour:Lerp(Color3.new(1, 1, 1), colourCorrection)
	end
	
	-- Applies a decorative lens flare effect to O-class stars.
	if showGlint and spectralClass == "O" then
		local starGlow = script.StarGlow:Clone()
		starGlow.Parent = star
		starGlow.Adornee = star
		local classMod = 11 / (spectralSubclass + 1)
		starGlow.Size = UDim2.new(0.25 * classMod, 0, 0.25 * classMod, 0)
		starGlow.Glint.ImageTransparency = 1 - classMod
		starGlow.Glint.ImageColor3 = correctedColour
	end
	
	-- Roblox instance-specific code here, just setting the generated primitive's name, colour, and custom attributes to what
	-- was generated above.
	star.Name = spectralClass..spectralSubclass..classData.lumClass
	star.Color = correctedColour
	star:SetAttribute("Mass", mass)
	star:SetAttribute("Luminosity", luminosity)
	star:SetAttribute("Radius", radius)
	star:SetAttribute("SpectralClass", spectralClass)
	star:SetAttribute("SpectralSubclass", spectralSubclass)
	star:SetAttribute("LuminosityClass", classData.lumClass)
	star:SetAttribute("Temperature", temperature)
	star:SetAttribute("TemperatureColour", tempColour)
	
	local mesh = Instance.new("SpecialMesh")
	mesh.Parent = star
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.one * math.max((radius ^ (1 / radius)), 0.5) * 0.5
end

function PositionStar(star: BasePart, origin: CFrame, position: Vector3, rng: Random?)
	rng = typeof(rng) == "Random" and rng or Random.new()
	if position.Magnitude < 0.175 then
		position *= (0.175 / math.max(position.Magnitude, 0.01))
	end
	
	-- Keeping this mistake as a feature, as it produced very interesting-looking results.
	if wackyMode > 0 then
		if wackyMode > 1 then
			position = origin:PointToObjectSpace(position)
		end
		position = origin:VectorToObjectSpace(position)
	else
		position = origin:PointToWorldSpace(position)
	end
	
	star.Position = position
end

function module:NewSpiral(origin: CFrame, starCount: number, arms: number, angle: number, seed: number?)
	local rng = typeof(seed) == "number" and Random.new(seed) or Random.new()
	starCount = math.max(starCount, 1000)
	arms = arms >= 2 and arms or 2
	
	local starList = {}
	
	local galaxyScalar = starCount ^ (1 / 3) / 10
	local galaxyModel = Instance.new("Model")
	galaxyModel.Name = "SpiralGalaxyModel"
	galaxyModel.Parent = workspace
	galaxyModel.WorldPivot = origin
	
	local coreModel = Instance.new("Model")
	coreModel.Name = "Core"
	coreModel.Parent = galaxyModel
	local core = prefabStar:Clone()
	core.Name = "Core"
	core.CFrame = origin
	core.Size = Vector3.one / 4
	core.Color = Color3.new(1, 1, 1)
	core.Material = Enum.Material.Glass
	core.Transparency = 0.5
	core.Parent = coreModel
	local glow = script.DiskGlow:Clone()
	glow.CFrame = origin
	glow.Size = Vector3.new(
		galaxyScalar * 16,
		0,
		galaxyScalar * 16
	)
	glow.Parent = coreModel
	
	local baseCount = starCount / (arms + 1)
	starCount -= baseCount
	local coreCount = baseCount * (1 / 3)
	baseCount -= coreCount
	
	for count = 1, coreCount do
		local position = Vector3.new(
			MathUtils:Gaussian(0, galaxyScalar * 0.5, rng),
			MathUtils:Gaussian(0, galaxyScalar * 0.5, rng),
			MathUtils:Gaussian(0, galaxyScalar * 0.5, rng)
		)
		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = coreModel
		table.insert(starList, star)
	end
	
	local haloModel = Instance.new("Model")
	haloModel.Name = "Halo"
	haloModel.Parent = galaxyModel
	
	for count = 1, baseCount do
		local position = Vector3.new(
			MathUtils:Gaussian(0, galaxyScalar * 10, rng),
			MathUtils:Gaussian(0, galaxyScalar * 0.25, rng),
			MathUtils:Gaussian(0, galaxyScalar * 10, rng)
		)
		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = haloModel
		table.insert(starList, star)
	end
	
	local armCount = starCount / (arms / 2)
	
	for arm = 1, arms / 2 do
		local armModel = Instance.new("Model")
		armModel.Name = "Arm"..arm
		armModel.Parent = galaxyModel
		
		for count = 1, armCount do
			local armAngle = (360 / arms) * (count - 1)
			local position = Vector3.new(
				MathUtils:Gaussian(origin.X * math.min(wackyMode, 1), galaxyScalar * 10, rng),
				MathUtils:Gaussian(origin.Y * math.min(wackyMode, 1), galaxyScalar * 0.25, rng),
				MathUtils:Gaussian(origin.Z * math.min(wackyMode, 1), galaxyScalar * 2, rng)
			)
			position = CFrame.Angles(0, math.rad(armAngle) + math.rad(angle * (math.abs(position.X) / (galaxyScalar * 10))), 0):VectorToObjectSpace(position)
			
			local star = prefabStar:Clone()
			PositionStar(star, origin, position, rng)
			star.Size = Vector3.one / 10
			AssignStarClass(star, galaxyScalar, position, rng)
			star.Parent = armModel
			table.insert(starList, star)
		end
		
		starCount -= armCount
		armCount = math.min(armCount, starCount) -- Just to make sure the galaxy always has the exact total number of stars we want
	end
	
	return starList
end

function module:NewElliptical(origin: CFrame, starCount: number, scale: Vector3, seed: number?)
	local rng = typeof(seed) == "number" and Random.new(seed) or Random.new()
	starCount = math.max(starCount, 100)
	scale = Vector3.new(
		math.clamp(scale.X, 0.1, 1),
		math.clamp(scale.Y, 0.1, 1),
		math.clamp(scale.Z, 0.1, 1)
	)
	
	local starList = {}
	
	local galaxyScalar = starCount ^ (1 / 3) / 4
	local galaxyModel = Instance.new("Model")
	galaxyModel.Name = "EllipticalGalaxyModel"
	galaxyModel.Parent = workspace
	galaxyModel.WorldPivot = origin
	
	local core = prefabStar:Clone()
	core.Name = "Core"
	core.CFrame = origin
	core.Size = Vector3.one / 4
	core.Color = Color3.new(1, 1, 1)
	core.Material = Enum.Material.Glass
	core.Transparency = 0.5
	core.Parent = galaxyModel
	
	for count = 1, starCount do
		local position = Vector3.new(
			MathUtils:Gaussian(origin.X * math.min(wackyMode, 1), galaxyScalar * scale.X, rng),
			MathUtils:Gaussian(origin.Y * math.min(wackyMode, 1), galaxyScalar * scale.Y, rng),
			MathUtils:Gaussian(origin.Z * math.min(wackyMode, 1), galaxyScalar * scale.Z, rng)
		)

		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = galaxyModel
		table.insert(starList, star)
	end
	
	return starList
end

function module:NewBar(origin: CFrame, starCount: number, barSize: number, angle: number, seed: number?)
	local rng = typeof(seed) == "number" and Random.new(seed) or Random.new()
	starCount = math.max(starCount, 1000)
	barSize = math.clamp(barSize, 0.2, 0.75)
	
	local starList = {}

	local galaxyScalar = starCount ^ (1 / 3) / 10
	local galaxyModel = Instance.new("Model")
	galaxyModel.Name = "BarGalaxyModel"
	galaxyModel.Parent = workspace
	galaxyModel.WorldPivot = origin

	local coreModel = Instance.new("Model")
	coreModel.Name = "Core"
	coreModel.Parent = galaxyModel
	local core = prefabStar:Clone()
	core.Name = "Core"
	core.CFrame = origin
	core.Size = Vector3.one / 4
	core.Color = Color3.new(1, 1, 1)
	core.Material = Enum.Material.Glass
	core.Transparency = 0.5
	core.Parent = coreModel
	local glow = script.DiskGlow:Clone()
	glow.CFrame = origin
	glow.Size = Vector3.new(
		galaxyScalar * 16,
		0,
		galaxyScalar * 16
	)
	glow.Parent = coreModel

	local baseCount = starCount / 3
	starCount -= baseCount
	local coreCount = baseCount * 0.75
	baseCount -= coreCount

	for count = 1, coreCount do
		local position = Vector3.new(
			MathUtils:Gaussian(0, galaxyScalar * 0.25, rng),
			MathUtils:Gaussian(0, galaxyScalar * 0.5, rng),
			MathUtils:Gaussian(0, galaxyScalar * 5 * barSize, rng)
		)

		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = coreModel
		table.insert(starList, star)
	end

	local haloModel = Instance.new("Model")
	haloModel.Name = "Halo"
	haloModel.Parent = galaxyModel

	for count = 1, baseCount do
		local position = Vector3.new(
			MathUtils:Gaussian(0, galaxyScalar * 10, rng),
			MathUtils:Gaussian(0, galaxyScalar * 0.25, rng),
			MathUtils:Gaussian(0, galaxyScalar * 10, rng)
		)

		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = haloModel
		table.insert(starList, star)
	end
	
	local armModel = Instance.new("Model")
	armModel.Name = "Arm"
	armModel.Parent = galaxyModel

	for count = 1, starCount do
		local position = Vector3.new(
			MathUtils:Gaussian(origin.X * math.min(wackyMode, 1), galaxyScalar * 10, rng),
			MathUtils:Gaussian(origin.Y * math.min(wackyMode, 1), galaxyScalar * 0.25, rng),
			MathUtils:Gaussian(origin.Z * math.min(wackyMode, 1), galaxyScalar * 2, rng)
		)
		position = CFrame.Angles(0, math.rad(angle * (math.abs(position.X) / (galaxyScalar * 10) * math.max(galaxyScalar - (galaxyScalar * barSize), 0))), 0):VectorToObjectSpace(position)

		local star = prefabStar:Clone()
		PositionStar(star, origin, position, rng)
		star.Size = Vector3.one / 10
		AssignStarClass(star, galaxyScalar, position, rng)
		star.Parent = armModel
		table.insert(starList, star)
	end
	
	return starList
end

--// END OF MODULE

return module