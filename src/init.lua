--[[
	Reading process:

	Parse header
	Decompress chunks
	Parse META and SSTR chunks
	Parse INST chunks
	Parse PROP chunks
	Parse PRNT chunk

	We parse this way to prevent eroneous chunk placement, whenever possible, break the script if something
	doesn't read correctly
]]

local HEADER = "<roblox!"
local RBXM_SIGNATURE = "\x89\xff\x0d\x0a\x1a\x0a"
local ZSTD_HEADER = "\x28\xB5\x2F\xFD"

local Buffer = require(script.Buffer)
local Types = require(script.Types)
local lz4 = require(script.lz4)
local ObjectBuilder = require(script.ObjectBuilder)

local Chunks = script.Chunks

local VALID_CHUNK_IDENTIFIERS = {
	["END\0"] = true,
	["INST"] = true,
	["META"] = true,
	["PRNT"] = true,
	["PROP"] = true,
	["SIGN"] = true,
	["SSTR"] = true
}
local CHUNK_MODULES = {
	INST = require(Chunks.INST),
	META = require(Chunks.META),
	PRNT = require(Chunks.PRNT),
	PROP = require(Chunks.PROP),
	SSTR = require(Chunks.SSTR)

	--END\0 and SIGN are not processed because they're irrelevant
}

local function Chunk(buffer: Types.Buffer, chunkIndex: number): Types.Chunk
	local chunk = {}
	chunk.InternalID = chunkIndex
	chunk.Header = buffer:read(4)
	if not VALID_CHUNK_IDENTIFIERS[chunk.Header] then
		error(`Invalid chunk identifier {chunk.Header} on chunk id {chunkIndex}`)
	end

	-- validate LZ4 header, though we can provide the buffer in directly, just used for checking for zstd
	local data

	local lz4Header = buffer:read(16, false)
	local compressed = string.unpack("<I4", string.sub(lz4Header, 1, 4))
	local decompressed = string.unpack("<I4", string.sub(lz4Header, 5, 8))
	local reserved = string.sub(lz4Header, 9, 12)
	local zstd_check = string.sub(lz4Header, 13, 16)

	if reserved ~= "\0\0\0\0" then
		error(`Invalid chunk header on chunk id {chunkIndex} of identifier {chunk.Header}`)
	end

	if compressed == 0 then
		data = buffer:read(decompressed)
	else
		if zstd_check == ZSTD_HEADER then
			error(`Chunk id {chunkIndex} of identifier {chunk.Header} is a ZSTD compressed chunk and cannot be decompressed`)
		end
		data = lz4(buffer:read(compressed + 12))
	end

	chunk.Data = Buffer(data, false)

	function chunk:Error(msg)
		error(`[{self.Header}:{self.InternalID}]: {msg}`)
	end
	
	return chunk
end

local function procChunkType(chunkStore: {[string]: {Types.Chunk}}, id: string, rbxm: Types.Rbxm)
	local chunks = chunkStore[id]
	local f = CHUNK_MODULES[id]

	if chunks and f then
		for _, chunk in chunks do
			f(chunk, rbxm)
		end
	end
end

local function rbxm(buffer: string): Types.Rbxm
	local rbxmBuffer = Buffer(buffer, false)

	-- read signature data
	if
		rbxmBuffer:read(8) ~= HEADER
		or rbxmBuffer:read(6) ~= RBXM_SIGNATURE
	then
		error("Provided file does not match the header of an RBXM file.")
	end

	if rbxmBuffer:read(2) ~= "\0\0" then
		error("Invalid RBXM version, if Roblox has released a newer version (unlikely), please let me know.")
	end

	local rbxm = {}
	local classCount = rbxmBuffer:readNumber("<i4")
	local instCount = rbxmBuffer:readNumber("<i4")

	local classRefIds = table.create(classCount)
	local instRefIds = table.create(instCount)
	rbxm.ClassRefs = classRefIds
	rbxm.InstanceRefs = instRefIds
	rbxm.Tree = {}
	rbxm.Metadata = {}
	rbxm.Strings = {}

	function rbxm:GetObjects(): {Instance}
		return ObjectBuilder(self)
	end

	local chunkInfo = {}
	for k in VALID_CHUNK_IDENTIFIERS do
		chunkInfo[k] = {}
	end

	if rbxmBuffer:read(8) ~= "\0\0\0\0\0\0\0\0" then
		error("Provided file does not match the header of an RBXM file.")
	end

	local index = 0
	repeat
		index+=1
		local last_chunk = Chunk(rbxmBuffer, index)
		local header = last_chunk.Header
		local chunkInfoSection = chunkInfo[header]
		table.insert(chunkInfoSection, last_chunk)
	until last_chunk.Header == "END\0"

	procChunkType(chunkInfo, "META", rbxm)
	procChunkType(chunkInfo, "SSTR", rbxm)
	procChunkType(chunkInfo, "INST", rbxm)
	procChunkType(chunkInfo, "PROP", rbxm)
	procChunkType(chunkInfo, "PRNT", rbxm)

	return rbxm
end

return rbxm