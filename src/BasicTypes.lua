-- Used for deserialising interleaving, strings, numbers and refs
-- Refs are held here since multiple chunks rely on it

local Types = require(script.Parent.Types)
local Buffer = require(script.Parent.Buffer)
local basicTypes = {}

local function transformInt(x: number): number
	-- cant use the bit method because bit32 (yay)
	return if x % 2 == 0
		then x / 2
		else -(x + 1) / 2
end

local function rbxF32(x: number): number
	x = bit32.rrotate(x, 1)
	return string.unpack(">f", string.pack(">I4", x))
end

function basicTypes.String(buffer: Types.Buffer): string
	return buffer:read(buffer:readNumber("<I4"))
end

function basicTypes.Int32(buffer: Types.Buffer): number
	return transformInt(buffer:readNumber(">I4"))
end

function basicTypes.Int64(buffer: Types.Buffer): number
	return transformInt(buffer:readNumber(">I8"))
end

function basicTypes.Float32(buffer: Types.Buffer): number
	return rbxF32(buffer:readNumber(">I4"))
end

function basicTypes.Float64(buffer: Types.Buffer): number --just use <d lol (here for completeness)
	return buffer:readNumber("<d")
end

-- my favourite function :D
function basicTypes.InterleaveArrayWithSize(buffer: Types.Buffer, count: number, sizeof: number): Types.Buffer
	if count < 0 then return Buffer("", false) end
	
	local stream = buffer:read(count * sizeof)
	local out = table.create(count)
	for i = 1, count do
		local chunk = table.create(sizeof)
		for s = 0, sizeof-1 do
			local bitPos = i + (count * s)
			chunk[s+1] = string.sub(stream, bitPos, bitPos)
		end
		out[i] = table.concat(chunk)
	end

	return Buffer(table.concat(out), false)
end

function basicTypes.unsignedIntArray(buffer: Types.Buffer, count: number): {number}
	if count < 1 then return {} end

	local o = table.create(count)
	local strings = basicTypes.InterleaveArrayWithSize(buffer, count, 4)
	for i = 1, count do
		o[i] = strings:readNumber("<I4")
	end

	return o
end

function basicTypes.Int32Array(buffer: Types.Buffer, count: number): {number}
	if count < 1 then return {} end

	local o = table.create(count)
	local strings = basicTypes.InterleaveArrayWithSize(buffer, count, 4)
	for i = 1, count do
		o[i] = basicTypes.Int32(strings)
	end

	return o
end

function basicTypes.Int64Array(buffer: Types.Buffer, count: number): {number}
	if count < 1 then return {} end

	local o = table.create(count)
	local strings = basicTypes.InterleaveArrayWithSize(buffer, count, 8)
	for i = 1, count do
		o[i] = basicTypes.Int64(strings)
	end

	return o
end

function basicTypes.RbxF32Array(buffer: Types.Buffer, count: number): {number}
	if count < 1 then return {} end

	local o = table.create(count)
	local strings = basicTypes.InterleaveArrayWithSize(buffer, count, 4)

	for i = 1, count do
		o[i] = basicTypes.Float32(strings)
	end

	return o
end

function basicTypes.RefArray(buffer: Types.Buffer, count: number): {number}
	if count < 1 then return {} end

	local o = table.create(count)
	local refs = basicTypes.Int32Array(buffer, count)

	local last = 0
	for i = 1, count do
		local ref = last + refs[i]
		o[i] = ref
		last = ref
	end

	return o
end

return basicTypes