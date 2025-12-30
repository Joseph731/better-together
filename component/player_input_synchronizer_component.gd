class_name PlayerInputSynchronizerComponent
extends MultiplayerSynchronizer

var movement_direction:float
var climb_direction: float
var is_attack_pressed:bool
var is_jump_pressed:bool
var is_enter_pressed: bool

func _process(_delta: float):
	if is_multiplayer_authority():
		gather_input()

func gather_input():
	movement_direction = Input.get_axis("move_left", "move_right")
	climb_direction = Input.get_axis("climb_up", "climb_down")
	is_attack_pressed = Input.is_action_pressed("attack")
	is_jump_pressed = Input.is_action_pressed("jump")
	is_enter_pressed = Input.is_action_pressed("enter")
