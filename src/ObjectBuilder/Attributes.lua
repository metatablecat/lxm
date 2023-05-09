local BasicTypes = require(script.Parent.Parent.BasicTypes)
local Buffer = require(script.Parent.Parent.Buffer)

local function GetEnumValFromNumber(enum: Enum, num: number): EnumItem
	local enums = enum:GetEnumItems()

	for _, v in enums do
		if v.Value == num then
			return v
		end
	end

	return enums[1]
end

return function(attribStream: string): {[string]: any}
	local buffer = Buffer(attribStream, false)

	local count = buffer:readNumber("<I4")
	if count == 0 then return {} end
	
	local out = {}

	for i = 1, count do
		local name = BasicTypes.String(buffer)
		local value = nil

		local typeid = string.byte(buffer:read())
		if typeid == 0x02 then
			value = BasicTypes.String(buffer)
		elseif typeid == 0x03 then
			value = buffer:read() ~= "\0"
		elseif typeid == 0x05 then
			value = buffer:readNumber("<f")
		elseif typeid == 0x06 then
			value = buffer:readNumber("<d")
		elseif typeid == 0x09 then
			value = UDim.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<i4")
			)
		elseif typeid == 0x0A then
			value = UDim2.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<i4"),
				buffer:readNumber("<f"),
				buffer:readNumber("<i4")
			)
		elseif typeid == 0x0E then
			value = BrickColor.new(buffer:readNumber("<I4"))
		elseif typeid == 0x0F then
			value = Color3.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		elseif typeid == 0x10 then
			value = Vector2.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		elseif typeid == 0x11 then
			value = Vector3.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		elseif typeid == 0x17 then
			local kpc = buffer:readNumber("<I4")

			local kp = {}
			if kpc > 0 then 
				kp = table.create(kpc)
				for kpi = 1, kpc do
					local env = buffer:readNumber("<f")
					local time = buffer:readNumber("<f")
					local val = buffer:readNumber("<f")

					kp[kpi] = NumberSequenceKeypoint.new(time, val, env)
				end
			end

			value = NumberSequence.new(kp)
		elseif typeid == 0x18 then
			value = NumberRange.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		elseif typeid == 0x19 then
			local kpc = buffer:readNumber("<I4")

			local kp = {}
			if kpc > 0 then 
				kp = table.create(kpc)
				for kpi = 1, kpc do
					buffer:read(4)
					local time = buffer:readNumber("<f")
					local val = buffer:readNumber("<f")

					kp[kpi] = ColorSequenceKeypoint.new(time, val)
				end
			end

			value = ColorSequence.new(kp)
		elseif typeid == 0x1c then
			value = Rect.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		elseif typeid == 0x14 then
			local x = buffer:readNumber("<f")
			local y = buffer:readNumber("<f")
			local z = buffer:readNumber("<f")

			local rotid = string.byte(buffer:read())
			if rotid > 0 then
				local orientID = (rotid-1) % 36
				local rx = GetEnumValFromNumber(Enum.NormalId, orientID / 6)
				local ry = GetEnumValFromNumber(Enum.NormalId, orientID % 6)
				
				local R0 = Vector3.fromNormalId(rx)
				local R1 = Vector3.fromNormalId(ry)
				local R2 = R0:Cross(R1)

				value = CFrame.fromMatrix(Vector3.new(x,y,z), R0, R1, R2)
			else
				value = CFrame.new(
					x,y,z,
					buffer:readNumber("<f"), buffer:readNumber("<f"), buffer:readNumber("<f"),
					buffer:readNumber("<f"), buffer:readNumber("<f"), buffer:readNumber("<f"),
					buffer:readNumber("<f"), buffer:readNumber("<f"), buffer:readNumber("<f")
				)
			end
		elseif typeid == 0x21 then
			local weight = GetEnumValFromNumber(Enum.FontWeight, buffer:readNumber("<I2"))
			local style = GetEnumValFromNumber(Enum.FontWeight, buffer:readNumber("<I2"))
			local family = BasicTypes.String(buffer)
			BasicTypes.String(buffer) --Cached

			value = Font.new(family, weight, style)
		end

		out[name] = value
	end

	return out
end