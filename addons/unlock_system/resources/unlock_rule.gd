class_name UnlockRule
extends Resource


@export var rule_id: String = ""
@export var conditions: CompoundCondition = null
@export var targets: Array[String] = []
@export var effects: Array[UnlockEffect] = []
@export var enabled: bool = true
