class_name Player
extends CharacterBody2D

const SPEED = 230.0
const JUMP_VELOCITY = -450.0

@onready var visuals: Node2D = $Visuals
@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSynchronizerComponent
@onready var portal_cooldown: Timer = $PortalCooldown
@onready var game_camera: GameCamera = $GameCamera

var input_multiplayer_authority: int
var is_dying: bool = false

func _ready() -> void:
	player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)
	if multiplayer.get_unique_id() == input_multiplayer_authority:
		game_camera.enabled = true


func _physics_process(delta: float) -> void:

	var movement_direction := player_input_synchronizer_component.movement_direction
	if is_multiplayer_authority():
		if is_dying:
			global_position = Vector2.RIGHT * 1000
			return
		velocity += get_gravity() * delta
		
		if player_input_synchronizer_component.is_jump_pressed && is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var target_x_velocity = movement_direction * SPEED
		
		if movement_direction:
			velocity.x = target_x_velocity
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		move_and_slide()
		
	if movement_direction > 0:
		visuals.scale = Vector2.ONE
	elif movement_direction < 0:
		visuals.scale = Vector2(-1, 1)

func kill():
	if !is_multiplayer_authority():
		push_error("Cannot call kill on non-server client")
		return
	
	_kill.rpc()
	await get_tree().create_timer(0.5).timeout
	
	queue_free()

@rpc("authority", "call_local", "reliable")
func _kill():
	is_dying = true
	player_input_synchronizer_component.public_visibility = false
