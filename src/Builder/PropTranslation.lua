-- Renames for some of the weirder property names
-- Translation(className, propName) -> string
-- These are based on the "SerializeAs" tags under rbx-dom-lua/database.json
-- metatablecat

local function tryForEnum(inst, name, val)
	local possibleEnum = inst[name]
	if typeof(possibleEnum) ~= "EnumItem" then return false end
	
	local class = possibleEnum.EnumType
	local first
	
	for _, v in class:GetEnumItems() do
		if v.Value == val then
			inst[name] = v
			return true
		end
		
		if not first then first = v end
	end
	
	inst[name] = first
	return true
end

local function MakeTRDBItem(type: "Translation"|"Func", val)
	return {Type = type, Value = val}
end

local trdb = {
	BasePart = {
		Color3uint8 = MakeTRDBItem("Translation", "Color"),
		size = MakeTRDBItem("Translation", "Size")
	},

	Fire = {
		heat_xml = MakeTRDBItem("Translation", "Heat"),
		size_xml = MakeTRDBItem("Translation", "Size")
	},

	FormFactorPart = {
		formFactorRaw = MakeTRDBItem("Translation", "FormFactor")
	},

	Instance = {
		archivable = MakeTRDBItem("Translation", "Archivable")
	},

	Model = {
		ScaleFactor = MakeTRDBItem("Func", function(inst: Model, val)
			inst:ScaleTo(val)
		end)
	},

	Part = {
		shape = MakeTRDBItem("Translation", "Shape")
	},

	Smoke = {
		opacity_xml = MakeTRDBItem("Translation", "Opacity"),
		riseVelocity_xml = MakeTRDBItem("Translation", "RiseVelocity"),
		size_xml = MakeTRDBItem("Translation", "Size")
	},

	WeldConstraint = {
		-- why
		Part0Internal = "Part0",
		Part1Internal = "Part1"
	}
}

local translator = {}
local stalled_func_calls = {}

function translator.compute(inst, propName: string, val: any)
	local translation = {Type = "Translation", Value = propName}

	for class, translator in trdb do
		if not inst:IsA(class) then continue end
		local translateTo = translator[propName]
		if not translateTo then continue end
		translation = translateTo
		break
	end

	if translation.Type == "Translation" then
		pcall(function()
			if not tryForEnum(inst, propName, val) then
				inst[translation.Value] = val
			end
		end)
		
		return
	end

	-- create a new stall to flush (you MUST flush)
	local stalled = stalled_func_calls[inst]
	if not stalled then
		stalled = {}
		stalled_func_calls[inst] = stalled
	end

	table.insert(stalled, {call = translation.Value, value = val})
end

function translator.flush()
	for inst, funcs in stalled_func_calls do
		for _, func in funcs do
			func.call(func.value)
		end
	end

	stalled_func_calls = {}
end

return translator