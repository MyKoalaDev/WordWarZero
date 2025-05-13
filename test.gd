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
	
	#var foo: Array[Tile] = [Tile.new(Tile.Face.C, true)]
	#var bar: Array[Tile] = foo.duplicate(true)
	#foo[0].set_face(Tile.Face.G)
	#print(foo[0].get_face_string())
	#print(bar[0].get_face_string())
	
	var foo: Dictionary[int, String] = {
		32: "gamer",
		69: "epic",
	}
	
	var keys: Array[int] = foo.keys() as Array[int]
	print(keys)
	keys.erase(32)
	print(keys)
	print(foo)
	var network: Network = Network.new()
	
	_bar()
	network.free()

func _bar() -> void:
	print(get_stack())
