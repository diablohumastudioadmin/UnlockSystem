class_name CompoundCondition
extends Resource


enum Logic {
	AND,
	OR,
}

@export var operator: Logic = Logic.AND
@export var children: Array = []
