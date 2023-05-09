export type Buffer = {
	Offset: number,
	Source: string,
	Length: number,
	IsFinished: boolean,
	LastUnreadBytes: number,
	AllowOverflows: boolean,

	read: (Buffer, len: number?, shiftOffset: boolean?) -> string,
	readNumber: (Buffer, packfmt: string?, shift: boolean?) -> number,
	seek: (Buffer, len: number) -> (),
	append: (Buffer, newData: string) -> (),
	toEnd: (Buffer) -> ()
}

export type Chunk = {
	InternalID: number,
	Header: "END\0"|"INST"|"META"|"PRNT"|"PROP"|"SIGN"|"SSTR",
	Data: Buffer,
	Error: (Chunk, string) -> ()
}

export type VirtualInstance = {
	ClassId: number,
	ClassName: string,
	Properties: {[string]: any},
	Ref: number,
	Children: {VirtualInstance}
}

export type Rbxm = {
	ClassRefs: {
		{
			Name: string,
			Sizeof: number,
			Refs: {number}
		}
	},
	InstanceRefs: {VirtualInstance},
	Tree: {VirtualInstance},
	Metadata: {[string]: string},
	Strings: {string}
}

return nil