@tool
extends EditorScript

func _run() -> void:
	#var bytes: PackedByteArray = PackedByteArray()
	#var byte: int = 14
	#bytes.resize(1)
	#bytes.encode_u8(0, byte)
	#byte |= 1 << 7
	#bytes[0] |= 1 << 7
	#print(String.num_uint64(byte, 2))
	#print(String.num_uint64(bytes[0], 2))
	
	var foo: Array[Tile] = [Tile.new(Tile.Face.C, true)]
	var bar: Array[Tile] = foo.duplicate(true)
	foo[0].set_face(Tile.Face.G)
	print(foo[0].get_face_string())
	print(bar[0].get_face_string())
	
	
