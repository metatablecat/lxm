-- This is such a hack lmao

-- {"m":null,"t":"buffer","zbase64":""}

local HttpService = game:GetService("HttpService")
local b64 = require(script.Parent.b64)

return function(stream: string): string
	local zbase64 = b64.encode(stream)
	local x = HttpService:JSONDecode(`\{"m": null, "t":"buffer", "zbase64":"{zbase64}"\}`)
	return buffer.tostring(x)
end