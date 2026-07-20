extends Node
class_name WorldRepository

const SAVE_FORMAT := "world_smithr"
const SAVE_ROOT := "user://worlds"

var userfs_persistent := true


func initialize(_main: Node) -> void:
	userfs_persistent = OS.is_userfs_persistent()


func get_worlds_path() -> String:
	return SAVE_ROOT


func get_save_format() -> String:
	return SAVE_FORMAT
