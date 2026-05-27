@tool
extends EditorPlugin


const AUTOLOAD_NAME: String = "UnlockManager"
const AUTOLOAD_PATH: String = "res://addons/unlock_system/unlock_manager.gd"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
