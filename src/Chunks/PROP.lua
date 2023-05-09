local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local FACES_BIT_FLAG = {}
local AXES_BIT_FLAG = {}

local function GetEnumValFromNumber(enum: Enum, num: number): EnumItem
	local enums = enum:GetEnumItems()

	for _, v in enums do
		if v.Value == num then
			return v
		end
	end

	return enums[1]
end

local function parseBitFlag<T>(byte: number, bitFlag: {T}): T
	local output = {}
	for i = 0, 7 do
		local bit = 2^i
		if bit32.extract(byte, bit) then
			table.insert(output, bitFlag[bit])
		end
	end

	return unpack(output)
end

local function PROP(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local buffer = chunk.Data
	local classID = buffer:readNumber("<I4")
	local classref = rbxm.ClassRefs[classID]
	local refs = classref.Refs
	local sizeof = classref.Sizeof

	local name = BasicTypes.String(buffer)
	local typeID = string.byte(buffer:read())

	local properties = {}

	if typeID == 0x01 or typeID == 0x1D then
		-- String, Bytecode
		for i = 1, sizeof do
			properties[i] = BasicTypes.String(buffer)
		end

	elseif typeID == 0x02 then
		-- Boolean
		for i = 1, sizeof do
			properties[i] = buffer:read() ~= "\0"
		end

	elseif typeID == 0x03 then
		-- Int32
		properties = BasicTypes.Int32Array(buffer, sizeof)

	elseif typeID == 0x04 then
		-- RbxFloat32
		properties = BasicTypes.RbxF32Array(buffer, sizeof)

	elseif typeID == 0x05 then
		-- Float64
		for i = 1, sizeof do
			properties[i] = BasicTypes.Float64(buffer)
		end

	elseif typeID == 0x06 then
		-- UDim
		local scale = BasicTypes.RbxF32Array(buffer, sizeof)
		local offset = BasicTypes.Int32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = UDim.new(scale[i], offset[i])
		end

	elseif typeID == 0x07 then
		-- UDim2
		local scaleX, scaleY = BasicTypes.RbxF32Array(buffer, sizeof), BasicTypes.RbxF32Array(buffer, sizeof)
		local offsetX, offsetY = BasicTypes.Int32Array(buffer, sizeof), BasicTypes.Int32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = UDim2.new(scaleX[i], offsetX[i], scaleY[i], offsetY[i])
		end

	elseif typeID == 0x08 then
		-- Ray
		for i = 1, sizeof do
			properties[i] = Ray.new(
				Vector3.new(
					buffer:readNumber("<f"),
					buffer:readNumber("<f"),
					buffer:readNumber("<f")
				),
				Vector3.new(
					buffer:readNumber("<f"),
					buffer:readNumber("<f"),
					buffer:readNumber("<f")
				)
			)
		end

	elseif typeID == 0x09 then
		-- Faces
		for i = 1, sizeof do
			local byte = string.byte(buffer:read())
			properties[i] = parseBitFlag(byte, FACES_BIT_FLAG)
		end

	elseif typeID == 0x0A then
		-- Axes
		for i = 1, sizeof do
			local byte = string.byte(buffer:read())
			properties[i] = parseBitFlag(byte, AXES_BIT_FLAG)
		end

	elseif typeID == 0x0B then
		-- BrickColor
		local ints = BasicTypes.unsignedIntArray(buffer, sizeof)
		for i = 1, sizeof do
			properties[i] = BrickColor.new(ints[i])
		end

	elseif typeID == 0x0C then
		-- Color3
		local r = BasicTypes.RbxF32Array(buffer, sizeof)
		local g = BasicTypes.RbxF32Array(buffer, sizeof)
		local b = BasicTypes.RbxF32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = Color3.new(r[i], g[i], b[i])
		end

	elseif typeID == 0x0D then
		-- Vector2
		local x = BasicTypes.RbxF32Array(buffer, sizeof)
		local y = BasicTypes.RbxF32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = Vector2.new(x[i], y[i])
		end

	elseif typeID == 0x0E then
		-- Vector3
		local x = BasicTypes.RbxF32Array(buffer, sizeof)
		local y = BasicTypes.RbxF32Array(buffer, sizeof)
		local z = BasicTypes.RbxF32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = Vector3.new(x[i], y[i], z[i])
		end

	-- elseif typeID == 0x0F then
		-- Vector2int16?

	elseif typeID == 0x10 or typeID == 0x11 or typeID == 0x1E then
		--CFrame, Quaternion and OptCFrame
		if typeID == 0x1E then
			-- check for the cframe bit
			local t = string.byte(buffer:read())
			if t ~= 0x10 then
				chunk:Error("OptionalCFrame has an invalid type flag.")
			end
		end
		local matricies = table.create(sizeof)

		for i = 1, sizeof do
			local rawOrientation = string.byte(buffer:read())
			if rawOrientation > 0 then
				local orientID = (rawOrientation-1) % 36
				local x = GetEnumValFromNumber(Enum.NormalId, orientID / 6)
				local y = GetEnumValFromNumber(Enum.NormalId, orientID % 6)
				
				local R0 = Vector3.fromNormalId(x)
				local R1 = Vector3.fromNormalId(y)
				local R2 =	R0:Cross(R1)

				matricies[i] = {
					0, 0, 0, 
					R0.X, R0.Y, R0.Z, 
					R1.X, R1.Y, R1.Z,
					R2.X, R2.Y, R2.Z
				}
			elseif typeID == 0x11 then
				local x, y, z, w =
					buffer:readNumber("<f"),
					buffer:readNumber("<f"),
					buffer:readNumber("<f"),
					buffer:readNumber("<f")

				local q = CFrame.new(0, 0, 0, x, y, z, w)
				matricies[i] = {q:GetComponents()}
			else
				local out = table.create(12, 0)
				for i = 4, 12 do
					out[i] = buffer:readNumber("<f")
				end

				matricies[i] = out
			end
		end

		-- map interleaved position
		local cfX = BasicTypes.RbxF32Array(buffer, sizeof)
		local cfY = BasicTypes.RbxF32Array(buffer, sizeof)
		local cfZ = BasicTypes.RbxF32Array(buffer, sizeof)

		for i = 1, sizeof do
			local thisMatrix = matricies[i]
			thisMatrix[1] = cfX[i]
			thisMatrix[2] = cfY[i]
			thisMatrix[3] = cfZ[i]

			properties[i] = CFrame.new(
				thisMatrix[1], thisMatrix[2], thisMatrix[3],
				thisMatrix[4], thisMatrix[5], thisMatrix[6],
				thisMatrix[7], thisMatrix[8], thisMatrix[9],
				thisMatrix[10], thisMatrix[11], thisMatrix[12]
			)
		end

		if typeID == 0x1E then
			local bool = string.byte(buffer:read())
			if bool ~= 0x02 then
				chunk:Error("OptionalCFrame does not have correct following type")
			end

			for i = 1, sizeof do
				local archivable = buffer:read() ~= "\0"

				if not archivable then
					properties[i] = CFrame.new()
				end
			end
		end

	elseif typeID == 0x12 then
		-- Enum
		properties = BasicTypes.unsignedIntArray(buffer, sizeof)

	elseif typeID == 0x13 then
		-- Ref
		properties = BasicTypes.RefArray(buffer, sizeof)

	elseif typeID == 0x14 then
		-- Vector3int16
		for i = 1, sizeof do
			properties[i] = Vector3int16.new(
				buffer:readNumber("<i2"),
				buffer:readNumber("<i2"),
				buffer:readNumber("<i2")
			)
		end

	elseif typeID == 0x15 then
		-- NumberSequence
		for i = 1, sizeof do
			local kpCount = buffer:readNumber("<I4")
			local kp = table.create(kpCount)

			for i = 1, kp do
				table.insert(kp, NumberSequenceKeypoint.new(
					buffer:readNumber("<f"),
					buffer:readNumber("<f"),
					buffer:readNumber("<f")
				))
			end

			properties[i] = NumberSequence.new(kp)
		end

	elseif typeID == 0x16 then
		-- ColorSequence
		for i = 1, sizeof do
			local kpCount = buffer:readNumber("<I4")
			local kp = table.create(kpCount)

			for i = 1, kp do
				table.insert(kp, ColorSequenceKeypoint.new(
					buffer:readNumber("<f"),
					Color3.new(
						buffer:readNumber("<f"),
						buffer:readNumber("<f"),
						buffer:readNumber("<f")
					)
				))

				buffer:readNumber("<f")
			end

			properties[i] = ColorSequence.new(kp)
		end

	elseif typeID == 0x17 then
		-- NumberRange
		for i = 1, sizeof do
			properties[i] = NumberRange.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		end

	elseif typeID == 0x18 then
		-- Rect
		local xmn, ymn = BasicTypes.RbxF32Array(buffer, sizeof), BasicTypes.RbxF32Array(buffer, sizeof)
		local xmx, ymx = BasicTypes.RbxF32Array(buffer, sizeof), BasicTypes.RbxF32Array(buffer, sizeof)

		for i = 1, sizeof do
			properties[i] = Rect.new(
				Vector2.new(
					xmn[i], ymn[i]
				),
				Vector2.new(
					xmx[i], ymx[i]
				)
			)
		end

	elseif typeID == 0x19 then
		-- PhysicalProperties
		for i = 1, sizeof do
			if buffer:read() == "\0" then continue end

			properties[i] = PhysicalProperties.new(
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f"),
				buffer:readNumber("<f")
			)
		end

	elseif typeID == 0x1A then
		-- Color3int8
		local r = string.split(buffer:read(sizeof), "")
		local g = string.split(buffer:read(sizeof), "")
		local b = string.split(buffer:read(sizeof), "")

		for i = 1, sizeof do
			properties[i] = Color3.fromRGB(
				string.byte(r[i]),
				string.byte(g[i]),
				string.byte(b[i])
			)
		end

	elseif typeID == 0x1B then
		-- Int64
		properties = BasicTypes.Int64Array(buffer, sizeof)

	elseif typeID == 0x1C then
		-- SharedString
		local strings = BasicTypes.unsignedIntArray(buffer, sizeof)
		for i = 1, sizeof do
			local ref = strings[i] + 1
			properties[i] = rbxm.Strings[ref]
		end

	elseif typeID == 0x20 then
		-- Font
		for i = 1, sizeof do
			local family = BasicTypes.String(buffer)
			local weight = GetEnumValFromNumber(Enum.FontWeight, buffer:readNumber("<I2"))
			local style = GetEnumValFromNumber(Enum.FontStyle, string.byte(buffer:read()))
			
			BasicTypes.String(buffer) --CachedFaceId

			properties[i] = Font.new(family, weight, style)
		end
	end

	-- map to referents
	for i, v in refs do
		local inst = rbxm.InstanceRefs[v]
		inst.Properties[name] = properties[i]
	end
end

return PROP