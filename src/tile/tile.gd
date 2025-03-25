@tool
extends RefCounted
class_name Tile

enum Face {
	NONE,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
}

const FACE_POINTS: PackedInt32Array = [
	4,# NONE
	1,# A
	3,# B
	3,# C
	2,# D
	1,# E
	5,# F
	2,# G
	5,# H
	1,# I
	7,# J
	7,# K
	2,# L
	3,# M
	3,# N
	1,# O
	3,# P
	1,# Q
	1,# R
	1,# S
	1,# T
	1,# U
	5,# V
	5,# W
	7,# X
	5,# Y
	1,# Z
]

const UNICODE_OFFSET: int = 64
const BIT_WILD: int = 1 << 7

var _face: Face = Face.NONE

func get_face() -> Face:
	return _face

func set_face(face: Face) -> void:
	if _wild:
		_face = face

func get_face_points() -> int:
	if _wild:
		return 0
	return FACE_POINTS[_face]

func get_face_string() -> String:
	if _face == Face.NONE:
		return "?"
	return String.chr(_face + UNICODE_OFFSET)

var _wild: bool = false

func is_wild() -> bool:
	return _wild

func _init(face: Face = Face.NONE, wild: bool = false) -> void:
	_face = face
	_wild = wild

func duplicate() -> Tile:
	return Tile.new(_face, _wild)
