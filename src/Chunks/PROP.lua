local Types = require(script.Parent.Parent.Types)
local BasicTypes = require(script.Parent.Parent.BasicTypes)

local FACES_BIT_FLAG = {
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Bottom,
	Enum.NormalId.Front
}
local AXES_BIT_FLAG = {
	Enum.Axis.X,
	Enum.Axis.Y,
	Enum.Axis.Z
}

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
		if bit32.extract(byte, i) ~= 0 then
			table.insert(output, bitFlag[i+1])
		end
	end

	return unpack(output)
end

local function PROP(chunk: Types.Chunk, rbxm: Types.Rbxm)
	local reader = chunk.Data
	local classID = reader:readNumber("<I4")
	local classref = rbxm.ClassRefs[classID]
	local refs = classref.Refs
	local sizeof = classref.Sizeof

	local name = BasicTypes.String(reader)
	local optTypeIdCheck = string.byte(reader:read(1, false)) == 0x1E
	if optTypeIdCheck then
		-- although its only be spotted for CFrame, i do believe 0x1E will be used for
		-- other optional types in the future, this future proofs that case
		reader:seek(1)
	end

	local typeID = string.byte(reader:read())

	local properties = {}

	if typeID == 0x01 then
		-- String, Bytecode
		for i = 1, sizeof do
			properties[i] = BasicTypes.String(reader)
		end

	elseif typeID == 0x02 then
		-- Boolean
		for i = 1, sizeof do
			properties[i] = reader:read() ~= "\0"
		end

	elseif typeID == 0x03 then
		-- Int32
		properties = BasicTypes.Int32Array(reader, sizeof)

	elseif typeID == 0x04 then
		-- RbxFloat32
		properties = BasicTypes.RbxF32Array(reader, sizeof)

	elseif typeID == 0x05 then
		-- Float64
		for i = 1, sizeof do
			properties[i] = BasicTypes.Float64(reader)
		end

	elseif typeID == 0x06 then
		-- UDim
		local scale = BasicTypes.RbxF32Array(reader, sizeof)
		local offset = BasicTypes.Int32Array(reader, sizeof)

		for i = 1, sizeof do
			properties[i] = UDim.new(scale[i], offset[i])
		end

	elseif typeID == 0x07 then
		-- UDim2
		local scaleX, scaleY = BasicTypes.RbxF32Array(reader, sizeof), BasicTypes.RbxF32Array(reader, sizeof)
		local offsetX, offsetY = BasicTypes.Int32Array(reader, sizeof), BasicTypes.Int32Array(reader, sizeof)

		for i = 1, sizeof do
			properties[i] = UDim2.new(scaleX[i], offsetX[i], scaleY[i], offsetY[i])
		end

	elseif typeID == 0x08 then
		-- Ray
		for i = 1, sizeof do
			properties[i] = Ray.new(
				Vector3.new(
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")
				),
				Vector3.new(
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")
				)
			)
		end

	elseif typeID == 0x09 then
		-- Faces
		for i = 1, sizeof do
			local byte = string.byte(reader:read())
			properties[i] = Faces.new(parseBitFlag(byte, FACES_BIT_FLAG))
		end

	elseif typeID == 0x0A then
		-- Axes
		for i = 1, sizeof do
			local byte = string.byte(reader:read())
			properties[i] = Axes.new(parseBitFlag(byte, AXES_BIT_FLAG))
		end

	elseif typeID == 0x0B then
		-- BrickColor
		local ints = BasicTypes.unsignedIntArray(reader, sizeof)
		for i = 1, sizeof do
			properties[i] = BrickColor.new(ints[i])
		end

	elseif typeID == 0x0C then
		-- Color3
		local r = BasicTypes.RbxF32Array(reader, sizeof)
		local g = BasicTypes.RbxF32Array(reader, sizeof)
		local b = BasicTypes.RbxF32Array(reader, sizeof)

		for i = 1, sizeof do
			properties[i] = Color3.new(r[i], g[i], b[i])
		end

	elseif typeID == 0x0D then
		-- Vector2
		local x = BasicTypes.RbxF32Array(reader, sizeof)
		local y = BasicTypes.RbxF32Array(reader, sizeof)

		for i = 1, sizeof do
			properties[i] = Vector2.new(x[i], y[i])
		end

	elseif typeID == 0x0E then
		-- Vector3
		local x = BasicTypes.RbxF32Array(reader, sizeof)
		local y = BasicTypes.RbxF32Array(reader, sizeof)
		local z = BasicTypes.RbxF32Array(reader, sizeof)

		for i = 1, sizeof do
			properties[i] = Vector3.new(x[i], y[i], z[i])
		end

	-- elseif typeID == 0x0F then
		-- Vector2int16?

	elseif typeID == 0x10 then
		--CFrame
		local matricies = table.create(sizeof)

		for i = 1, sizeof do
			local rawOrientation = string.byte(reader:read())
			if rawOrientation > 0 then
				local orientID = rawOrientation - 1
				local R0 = Vector3.fromNormalId(orientID / 6)
				local R1 = Vector3.fromNormalId(orientID % 6)
				local R2 =	R0:Cross(R1)

				matricies[i] = {R0, R1, R2}
			else
				local r00, r01, r02 = 
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")
				local r10, r11, r12 = 
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")
				local r20, r21, r22 = 
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")

				matricies[i] = {
					Vector3.new(r00, r10, r20),
					Vector3.new(r01, r11, r21),
					Vector3.new(r02, r12, r22)
				}
			end
		end

		-- map interleaved position
		local cfX = BasicTypes.RbxF32Array(reader, sizeof)
		local cfY = BasicTypes.RbxF32Array(reader, sizeof)
		local cfZ = BasicTypes.RbxF32Array(reader, sizeof)

		for i = 1, sizeof do
			local thisMatrix = matricies[i]
			local pos = Vector3.new(cfX[i], cfY[i], cfZ[i])
			properties[i] = CFrame.fromMatrix(pos, thisMatrix[1], thisMatrix[2], thisMatrix[3])
		end

	elseif typeID == 0x11 then
		-- Quaternion (i can be a little quicker here by handling it differently)
		local quaternions = {}
		for i = 1, sizeof do
			quaternions[i] = {
				x = reader:readNumber("<f"),
				y = reader:readNumber("<f"),
				z = reader:readNumber("<f"),
				w = reader:readNumber("<f")
			}
		end

		local cfX = BasicTypes.RbxF32Array(reader, sizeof)
		local cfY = BasicTypes.RbxF32Array(reader, sizeof)
		local cfZ = BasicTypes.RbxF32Array(reader, sizeof)

		for i = 1, sizeof do
			local q = quaternions[i]
			properties[i] = CFrame.new(cfX[i], cfY[i], cfZ[i], q.x, q.y, q.z, q.w)
		end

	elseif typeID == 0x12 then
		-- Enum
		properties = BasicTypes.unsignedIntArray(reader, sizeof)

	elseif typeID == 0x13 then
		-- Ref
		properties = BasicTypes.RefArray(reader, sizeof)

	elseif typeID == 0x14 then
		-- Vector3int16
		for i = 1, sizeof do
			properties[i] = Vector3int16.new(
				reader:readNumber("<i2"),
				reader:readNumber("<i2"),
				reader:readNumber("<i2")
			)
		end

	elseif typeID == 0x15 then
		-- NumberSequence
		for i = 1, sizeof do
			local kpCount = reader:readNumber("<I4")
			local kp = table.create(kpCount)

			for i = 1, kp do
				table.insert(kp, NumberSequenceKeypoint.new(
					reader:readNumber("<f"),
					reader:readNumber("<f"),
					reader:readNumber("<f")
				))
			end

			properties[i] = NumberSequence.new(kp)
		end

	elseif typeID == 0x16 then
		-- ColorSequence
		for i = 1, sizeof do
			local kpCount = reader:readNumber("<I4")
			local kp = table.create(kpCount)

			for i = 1, kp do
				table.insert(kp, ColorSequenceKeypoint.new(
					reader:readNumber("<f"),
					Color3.new(
						reader:readNumber("<f"),
						reader:readNumber("<f"),
						reader:readNumber("<f")
					)
				))

				reader:readNumber("<f")
			end

			properties[i] = ColorSequence.new(kp)
		end

	elseif typeID == 0x17 then
		-- NumberRange
		for i = 1, sizeof do
			properties[i] = NumberRange.new(
				reader:readNumber("<f"),
				reader:readNumber("<f")
			)
		end

	elseif typeID == 0x18 then
		-- Rect
		local xmn, ymn = BasicTypes.RbxF32Array(reader, sizeof), BasicTypes.RbxF32Array(reader, sizeof)
		local xmx, ymx = BasicTypes.RbxF32Array(reader, sizeof), BasicTypes.RbxF32Array(reader, sizeof)

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
			if reader:read() == "\0" then continue end

			properties[i] = PhysicalProperties.new(
				reader:readNumber("<f"),
				reader:readNumber("<f"),
				reader:readNumber("<f"),
				reader:readNumber("<f"),
				reader:readNumber("<f")
			)
		end

	elseif typeID == 0x1A then
		-- Color3int8
		local r = string.split(reader:read(sizeof), "")
		local g = string.split(reader:read(sizeof), "")
		local b = string.split(reader:read(sizeof), "")

		for i = 1, sizeof do
			properties[i] = Color3.fromRGB(
				string.byte(r[i]),
				string.byte(g[i]),
				string.byte(b[i])
			)
		end

	elseif typeID == 0x1B then
		-- Int64
		properties = BasicTypes.Int64Array(reader, sizeof)

	elseif typeID == 0x1C then
		-- SharedString
		local strings = BasicTypes.unsignedIntArray(reader, sizeof)
		for i = 1, sizeof do
			local ref = strings[i] + 1
			properties[i] = rbxm.Strings[ref]
		end

	elseif typeID == 0x1D then
		-- Bytecode
		for i = 1, sizeof do
			properties[i] = buffer.fromstring(BasicTypes.String(reader))
		end

	elseif typeID == 0x20 then
		-- Font
		for i = 1, sizeof do
			local family = BasicTypes.String(reader)
			local weight = GetEnumValFromNumber(Enum.FontWeight, reader:readNumber("<I2"))
			local style = GetEnumValFromNumber(Enum.FontStyle, string.byte(reader:read()))
			
			BasicTypes.String(reader) --CachedFaceId

			properties[i] = Font.new(family, weight, style)
		end
	end

	-- perform optional prop handle
	if optTypeIdCheck then
		reader:read()

		for i = 1, sizeof do
			local archivable = reader:read() ~= "\0"
			if not archivable then
				-- null the key (hopefully if OptCFrame returns, it allows null as a prop)
				properties[i] = nil
			end
		end
	end

	-- map to referents
	for i, v in refs do
		local inst = rbxm.InstanceRefs[v]
		inst.Properties[name] = properties[i]
	end
end

return PROP