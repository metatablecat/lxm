-- builds an object and maps attributes if possible
local CollectionService = game:GetService("CollectionService")

local Types = require(script.Parent.Types)
local Attributes = require(script.Attributes)

local function GetEnumValFromNumber(enum: Enum, num: number): EnumItem
	local enums = enum:GetEnumItems()

	for _, v in enums do
		if v.Value == num then
			return v
		end
	end

	return enums[1]
end

local function trySetProp(inst, name, val)
	local o = inst[name]
	if typeof(o) == "EnumItem" then
		inst[name] = GetEnumValFromNumber(o.EnumType, val)
	else
		inst[name] = val
	end
end

local function createObject(inst: Types.VirtualInstance): Instance
	local rbxInst = Instance.new(inst.ClassName)
	for _, child in inst.Children do
		createObject(child).Parent = rbxInst
	end

	for k, v in inst.Properties do
		if k == "AttributesSerialize" then
			-- TODO: Attributes
			local attribs = Attributes(v)
			for name, value in attribs do
				rbxInst:SetAttribute(name, value)
			end
		elseif k == "Tags" then
			local tags = string.split(v, "\0")
			for _, tag in tags do
				CollectionService:AddTag(rbxInst, tag)
			end
		else
			pcall(trySetProp, rbxInst, k, v)
		end
	end

	return rbxInst
end

return function(rbxm: Types.Rbxm): {Instance}
	local output = {}
	for _, inst in rbxm.Tree do
		table.insert(output, createObject(inst))
	end

	return output
end