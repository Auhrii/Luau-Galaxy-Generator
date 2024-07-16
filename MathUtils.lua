local module = {}

function module:Gaussian(mean: number, variance: number, rng: Random?) -- https://rosettacode.org/wiki/Statistics/Normal_distribution#Lua
	rng = typeof(rng) == "Random" and rng or Random.new() -- Edit: Support instanced random number generation, for repeat generation of the same numbersets
	return math.sqrt(-2 * variance * math.log(rng:NextNumber())) *
		math.cos(2 * math.pi * rng:NextNumber()) + mean
end

return module