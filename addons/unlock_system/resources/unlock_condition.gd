class_name UnlockCondition
extends Resource


enum Operator {
	EQ,
	NEQ,
	GEQ,
	LEQ,
	GT,
	LT,
}

@export var source_name: String = ""
@export var key: String = ""
@export var operator: Operator = Operator.EQ
@export var target_value: Variant = null
