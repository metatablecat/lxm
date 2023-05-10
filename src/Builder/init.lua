local PropTranslator = require(script.PropTranslation)
local Attributes = require(script.Attributes)
local CollectionService = game:GetService("CollectionService")
local Types = require(script.Parent.Types)

local function BuildChildMember(virt: Types.VirtualInstance): Instance
	local inst = Instance.new(virt.ClassName)
	for _, child in virt.Children do
		BuildChildMember(child).Parent = inst
	end
	
	for propName, propValue in virt.Properties do
		if propName == "AttributesSerialize" then
			continue
			--TODO
		elseif propName == "Tags" then
			local tags = string.split(propValue, "\0")
			for _, tag in tags do
				CollectionService:AddTag(inst, tag)
			end
		else
			PropTranslator.compute(inst, propName, propValue)
		end
	end

	return inst
end

return function(RBXM: Types.Rbxm): {Instance}
	local built_tree = {}
	for _, virt in RBXM.Tree do
		table.insert(built_tree, BuildChildMember(virt))
	end

	PropTranslator.flush()
	return built_tree
end