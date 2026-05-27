class_name UnlockEffect
extends Resource


enum Operation {
	SET,
	ADD,
	SUBTRACT,
}

@export var target_source: String = ""
@export var target_key: String = ""
@export var operation: Operation = Operation.SET
@export var value: Variant = null
