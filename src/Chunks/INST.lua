local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local function VirtualInstance(classID: number, className: string, ref: number): Types.VirtualInstance
	return {
		ClassId = classID,
		ClassName = className,
		Ref = ref,

		Properties = {},
		Children = {}
	}
end

local function INST(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local buffer = chunk.Data
	-- creates virtual instances for each given instance
	-- this will reject service instances (errors)
	local ClassID = buffer:readNumber("<I4")
	local ClassName = BasicTypes.String(buffer)

	if buffer:read() == "\1" then
		chunk:Error("Attempt to insert binary model with services")
	end

	local count = buffer:readNumber("<I4")
	local refs = BasicTypes.RefArray(buffer, count)

	-- dont bother reading serivce markers since this does not support services
	-- map virtual instances and refs to RBXM
	rbxm.ClassRefs[ClassID] = {
		Name = ClassName,
		Sizeof = count,
		Refs = refs
	}

	for _, ref in refs do
		rbxm.InstanceRefs[ref] = VirtualInstance(ClassID, ClassName, ref)
	end
end

return INST