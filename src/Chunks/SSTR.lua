local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local function SSTR(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local buffer = chunk.Data
	
	local ver = buffer:readNumber("<I4")
	if ver ~= 0 then
		chunk:Error("Invalid SSTR version")
	end

	for i = 1, buffer:readNumber("<I4") do
		buffer:read(16) --md5 hash (useless)
		rbxm.Strings[i] = BasicTypes.String(buffer)
	end
end

return SSTR