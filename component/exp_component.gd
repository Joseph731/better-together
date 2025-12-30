class_name ExpComponent
extends Node

signal leveled_up(level)
signal exp_changed(current_exp: int, max_exp: int)
signal exp_given(amount: int)

const MAX_LEVEL: int = 200

var max_exp: int = 10
var _current_level: int
var current_level: int:
	get:
		return _current_level
	set(value):
		_current_level = value
		leveled_up.emit(_current_level)
var _current_exp: int
var current_exp: int:
	get:
		return _current_exp
	set(value):
		_current_exp = value
		exp_changed.emit(_current_exp, max_exp)

func _ready() -> void:
	current_exp = 0
	current_level = 199

@rpc("authority", "call_local")
func emit_exp_given(amount: int):
	exp_given.emit(amount)

func give_exp(amount:int):
	current_exp += amount
	emit_exp_given.rpc(amount)
	if current_level >= MAX_LEVEL:
		if current_exp >= max_exp:
			current_exp = max_exp
		return
	while current_exp >= max_exp:
		current_level += 1
		current_exp -= max_exp
