local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local function PRNT(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local buffer = chunk.Data
	--Builds the instance tree from the given PRNT structure

	local ver = buffer:read()
	if ver ~= "\0" then
		chunk:Error("Invalid PRNT version")
	end

	local count = buffer:readNumber("<I4")
	local child_refs = BasicTypes.RefArray(buffer, count)
	local parent_refs = BasicTypes.RefArray(buffer, count)

	for i = 1, count do
		local childID = child_refs[i]
		local parentID = parent_refs[i]

		local child = rbxm.InstanceRefs[childID]
		local parent = if parentID >= 0 then rbxm.InstanceRefs[parentID] else nil

		if not child then
			chunk:Error(`Could not parent {childID} to {parentID} because child {childID} was nil`)
		end

		if parentID >= 0 and not parent then
			chunk:Error(`Could not parent {childID} to {parentID} because parent {parentID} was nil`)
		end

		local parentTable = if parent then parent.Children else rbxm.Tree
		table.insert(parentTable, child)
	end
end

return PRNT