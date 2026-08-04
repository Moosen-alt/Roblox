-- Minimal stand-ins for Roblox datatypes so the pure game math can run under
-- the standalone Luau CLI (tests/run.sh concatenates this ahead of the modules).

Color3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}

-- Any Enum.X.Y resolves to a placeholder string (configs reference materials etc.)
Enum = setmetatable({}, {
	__index = function(_, category)
		return setmetatable({}, {
			__index = function(_, item)
				return category .. "." .. item
			end,
		})
	end,
})

Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 1) % 2147483647 }, Random)
end
function Random:NextNumber(a, b)
	self.s = (self.s * 48271) % 2147483647
	local r = self.s / 2147483647
	if a ~= nil then
		return a + r * (b - a)
	end
	return r
end
function Random:NextInteger(a, b)
	return math.floor(self:NextNumber(a, b + 0.9999999))
end
