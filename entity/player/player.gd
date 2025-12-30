class_name Player
extends CharacterBody2D

const SPEED = 170.0
const JUMP_VELOCITY = -600.0

@onready var visuals: Node2D = $Visuals
@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSynchronizerComponent
@onready var portal_cooldown: Timer = $PortalCooldown
@onready var game_camera: GameCamera = $GameCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var ladder_ray_cast_2d: RayCast2D = $LadderRayCast2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var exp_component: ExpComponent = $ExpComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var invincibility_frames_timer: Timer = $InvincibilityFramesTimer

var basic_attack_scene: PackedScene = preload("uid://cgxe6h7qy8uoh")
var damage_number_scene: PackedScene = preload("uid://bs02ccyodye1u")
var attack_damage: int = 4
var input_multiplayer_authority: int
var is_dying: bool = false
var state_machine: CallableStateMachine = CallableStateMachine.new()
var server_is_on_floor: bool = false

var current_state:String:
	get:
		return state_machine.current_state
	set(value):
		state_machine.change_state(Callable.create(self, value))

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		state_machine.add_states(state_normal, enter_state_normal, leave_state_normal)
		state_machine.add_states(state_climb, enter_state_climb, leave_state_climb)
		state_machine.add_states(state_attack, enter_state_attack, leave_state_attack)

func _ready() -> void:
	player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)
	if multiplayer.get_unique_id() == input_multiplayer_authority:
		game_camera.enabled = true
	
	if is_multiplayer_authority():
		state_machine.set_initial_state(state_normal)
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)
		exp_component.leveled_up.connect(health_component._on_leveled_up)
		invincibility_frames_timer.timeout.connect(_on_invincibility_frames_timer_timeout)


func _physics_process(delta: float) -> void:
	state_machine.update()
	
	if is_multiplayer_authority():
		if is_dying:
			global_position = Vector2.RIGHT * 1000
			return
		
		if state_machine.current_state != "state_climb":
			velocity += get_gravity() * delta
		
		if !player_input_synchronizer_component.movement_direction || state_machine.current_state != "state_normal":
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, 3000 * delta) #HIGH FRICTION
			else:
				velocity.x = move_toward(velocity.x, 0, 300 * delta) #LOW FRICTION
		
		move_and_slide()

func enter_state_normal():
	pass

func state_normal():
	
	var movement_direction := player_input_synchronizer_component.movement_direction
	var climb_direction := player_input_synchronizer_component.climb_direction
	if is_multiplayer_authority():
		var ladder_collider := ladder_ray_cast_2d.get_collider()
		if ladder_collider && climb_direction != 0:
			var is_going_up := climb_direction < 0
			var is_going_down := climb_direction > 0
			var ladder_is_below_player: bool = ladder_collider.global_position.y > global_position.y
			var ladder_is_above_player: bool = ladder_collider.global_position.y < global_position.y
			if !(ladder_is_below_player && is_going_up)\
				&& !(is_on_floor() && is_going_down && ladder_is_above_player):
				global_position.x = ladder_collider.global_position.x + 32.0/2
				if ladder_is_below_player:
					global_position.y += 1
				state_machine.change_state(state_climb)
		
		if player_input_synchronizer_component.is_jump_pressed && is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var target_x_velocity = movement_direction * SPEED
		if movement_direction:
			velocity.x = target_x_velocity
		
		if player_input_synchronizer_component.is_attack_pressed:
			state_machine.change_state(state_attack)
	
	flip(movement_direction)
	set_animation()

func leave_state_normal():
	animation_player.play("RESET")

func enter_state_climb():
	pass

func state_climb():
	var climb_direction := player_input_synchronizer_component.climb_direction
	if is_multiplayer_authority():
		var ladder_collider = ladder_ray_cast_2d.get_collider()
		if !ladder_collider: 
			state_machine.change_state(state_normal)
			
		if player_input_synchronizer_component.is_jump_pressed:
			state_machine.change_state(state_normal)
		
		var target_y_velocity = climb_direction * SPEED / 2
		if climb_direction:
			velocity = Vector2(0, target_y_velocity)
		else:
			velocity = Vector2.ZERO
		
		if target_y_velocity > 0 && is_on_floor():
			state_machine.change_state(state_normal)
	
func leave_state_climb():
	animation_player.play("RESET")

func enter_state_attack():
	animation_player.play("swing1")

func state_attack():
	if !animation_player.is_playing():
		state_machine.change_state(state_normal)

func leave_state_attack():
	animation_player.play("RESET")

func flip(movement_direction: float):
	if movement_direction > 0:
		visuals.scale = Vector2(-1, 1)
	elif movement_direction < 0:
		visuals.scale = Vector2.ONE

func set_animation():
	if player_input_synchronizer_component.movement_direction:
		animation_player.play("walk")
	else:
		animation_player.play("stand")
	
	if is_multiplayer_authority():
		server_is_on_floor = is_on_floor() #client is_on_floor is broken because no move_and_slide
	if !server_is_on_floor:
		animation_player.play("jump")



func execute_basic_attack():
	if is_multiplayer_authority():
		var basic_attack = basic_attack_scene.instantiate() as BasicAttack
		basic_attack.damage = attack_damage
		basic_attack.global_position.y = global_position.y - collision_shape_2d.get_shape().size.y / 2
		if visuals.scale == Vector2.ONE:
			basic_attack.global_position.x = global_position.x - 45 
		else:
			basic_attack.global_position.x = global_position.x + 45
		basic_attack.source_global_position = global_position
		basic_attack.source_peer_id = input_multiplayer_authority
		get_parent().add_child(basic_attack, true)

func start_invincibility_frames():
	hurtbox_component.set_deferred("monitoring", false)
	invincibility_frames_timer.start()


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

func _on_died():
	kill()

func _on_hit_by_hitbox(attacking_hitbox_component: HitboxComponent):
	if !invincibility_frames_timer.is_stopped():
		return
	if (attacking_hitbox_component.global_position.x < global_position.x): #KNOCKBACK
		velocity.x = 190.0
	else:
		velocity.x = -190.0
		
	if is_on_floor():
		velocity.y = -220.0
	start_invincibility_frames()

func _on_invincibility_frames_timer_timeout():
	hurtbox_component.set_deferred("monitoring", true)

@rpc("authority", "call_local")
func spawn_damage_number(damage_amount: int):
	var damage_number = damage_number_scene.instantiate() as DamageNumber
	get_parent().add_child(damage_number, true)
	damage_number.label.text = str(damage_amount)
	damage_number.label.add_theme_color_override("font_color", Color.PURPLE)
	damage_number.global_position.y = global_position.y - 110
	damage_number.global_position.x = global_position.x - damage_number.label.size.x / 2

func _on_damaged(damage_amount: int):
	spawn_damage_number.rpc(damage_amount)
