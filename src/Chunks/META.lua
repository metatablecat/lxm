local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local function META(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local buffer = chunk.Data
	for i = 1, buffer:readNumber("<I4") do
		local k = BasicTypes.String(buffer)
		local v = BasicTypes.String(buffer)

		rbxm.Metadata[k] = v
	end
end

return META