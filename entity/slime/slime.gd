class_name Slime
extends CharacterBody2D

const SPEED = 140.0
const JUMP_VELOCITY = -600.0

@onready var target_acquisition_timer: Timer = $TargetAcquisitionTimer
@onready var jump_timer: Timer = $JumpTimer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent
@onready var enemy_health_bar: TextureProgressBar = $EnemyHealthBar
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var damage_number_scene: PackedScene = preload("uid://bs02ccyodye1u")
var state_machine: CallableStateMachine = CallableStateMachine.new()
var exp_reward:int = 5
var attack_damage:float = 1.0
var last_hit_by_player: Player
var movement_direction: int = -1
var target_x_position: float
var server_is_on_floor: bool = false
var old_x_position: float
var is_first_aggro_loop: bool = true

var current_state:String:
	get:
		return state_machine.current_state
	set(value):
		state_machine.change_state(Callable.create(self, value))

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		state_machine.add_states(state_spawn, enter_state_spawn, leave_state_spawn)
		state_machine.add_states(state_normal, enter_state_normal, leave_state_normal)
		state_machine.add_states(state_pain, enter_state_pain, leave_state_pain)
		state_machine.add_states(state_aggro, enter_state_aggro, leave_state_aggro)
		state_machine.add_states(state_dying, enter_state_dying, Callable())

func _ready():
	if is_multiplayer_authority():
		state_machine.set_initial_state(state_spawn)
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)
		jump_timer.timeout.connect(_on_jump_timeout)


func _physics_process(delta):
	state_machine.update()
	if is_multiplayer_authority():
		velocity += get_gravity() * delta #APPLY GRAVITY
		
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 3000.0 * delta) #HIGH FRICTION
		else:
			velocity.x = move_toward(velocity.x, 0, 350.0 * delta) #LOW FRICTION
		
		move_and_slide()
		
	flip()

func enter_state_spawn():
	animation_player.play("spawn")

func state_spawn():
	if is_multiplayer_authority() && !animation_player.is_playing():
		state_machine.change_state(state_normal)

func leave_state_spawn():
	animation_player.play("RESET")

func enter_state_normal():
	pass

func state_normal():
	if is_multiplayer_authority():
		if jump_timer.is_stopped():
			jump_timer.wait_time = randf_range(1, 9)
			jump_timer.start()
		
		if is_on_wall() && is_on_floor():
			movement_direction = -movement_direction
		
		velocity.x = movement_direction * SPEED
	
	set_animation()

func leave_state_normal():
	animation_player.play("RESET")
	jump_timer.stop()

func enter_state_pain():
	animation_player.play("hurt")

func state_pain():
	if is_multiplayer_authority() && !animation_player.is_playing() && is_on_floor():
		state_machine.change_state(state_aggro)

func leave_state_pain():
	animation_player.play("RESET")

func enter_state_aggro():
	is_first_aggro_loop = true

func state_aggro():
	if is_multiplayer_authority():
		if jump_timer.is_stopped():
			jump_timer.wait_time = randf_range(1, 9)
			jump_timer.start()
		
		if target_acquisition_timer.is_stopped():
			acquire_target()
			target_acquisition_timer.wait_time = randf_range(.8, 1.2)
			target_acquisition_timer.start()
		
		if is_on_floor():
			if global_position.x < target_x_position:
				movement_direction = 1
			else:
				movement_direction = -1
		
		
		velocity.x = movement_direction * SPEED
	
	set_animation()
	is_first_aggro_loop = false

func leave_state_aggro():
	animation_player.play("RESET")
	jump_timer.stop()
	target_acquisition_timer.stop()

func enter_state_dying():
	if is_multiplayer_authority():
		defer_turn_hitbox_and_hurtbox_on_or_off(false)
		if last_hit_by_player != null:
			var players = get_tree().get_nodes_in_group("player") as Array[Player]
			players.erase(last_hit_by_player)
			
			var exp_multiplier: float = 1
			for player in players: #players had the killer removed from it in the for loop above
				if player.global_position.distance_squared_to(last_hit_by_player.global_position) < 1500 * 1500: #squared is more optimized and functionally the same when comparing
					player.exp_component.give_exp(ceil(float(exp_reward) / 2))
					exp_multiplier = .75
			
			last_hit_by_player.exp_component.give_exp(ceil(exp_reward * exp_multiplier))
	
	enemy_health_bar.visible = false
	animation_player.play("death") #queue_free_if_server at end of animation

func state_dying():
	pass

func set_animation():
	if movement_direction == -1 || movement_direction == 1:
		animation_player.play("walk")
	else:
		animation_player.play("idle")
	
	if is_multiplayer_authority():
		server_is_on_floor = is_on_floor() #client is_on_floor is broken because no move_and_slide
	if !server_is_on_floor:
		animation_player.play("jump")

func flip():
	if movement_direction > 0:
		sprite_2d.scale = Vector2(-1, 1)
	elif movement_direction < 0:
		sprite_2d.scale = Vector2.ONE

func defer_turn_hitbox_and_hurtbox_on_or_off(bool_val: bool):
	hurtbox_component.set_deferred("monitoring", bool_val)
	hurtbox_component.set_deferred("monitorable", bool_val)
	hitbox_component.set_deferred("monitoring", bool_val)
	hitbox_component.set_deferred("monitorable", bool_val)

func acquire_target():
	if !is_instance_valid(last_hit_by_player):
		state_machine.change_state(state_normal)
		return
	
	var offset: float = 500
	if global_position.x == old_x_position && !is_first_aggro_loop: #entering pain_state exits the aggro_state so !is_first_aggro_loop prevents juggling against wall
		target_x_position = global_position.x + offset * -movement_direction
	else:
		if global_position.x < last_hit_by_player.global_position.x:
			target_x_position = global_position.x + offset
		else:
			target_x_position = global_position.x - offset
	old_x_position = global_position.x

func queue_free_if_server():
	if is_multiplayer_authority():
		queue_free()

@rpc("authority", "call_local")
func spawn_damage_number(damage_amount: int):
	var damage_number = damage_number_scene.instantiate() as DamageNumber
	get_parent().add_child(damage_number, true)
	damage_number.label.text = str(damage_amount)
	damage_number.global_position.y = global_position.y - 105
	damage_number.global_position.x = global_position.x - damage_number.label.size.x / 2

func _on_damaged(damage_amount: int):
	spawn_damage_number.rpc(damage_amount)
	state_machine.change_state(state_pain)

func _on_died():
	state_machine.change_state(state_dying)

func _on_hit_by_hitbox(attacking_hitbox_component: HitboxComponent):
	var attacking_player = attacking_hitbox_component.owner.get("source_player") as Player
	if !is_instance_valid(attacking_player):
		return
	last_hit_by_player = attacking_player
	
	if (attacking_player.global_position.x < global_position.x): #KNOCKBACK
		velocity.x = 450.0
		movement_direction = -1
	else:
		velocity.x = -450.0
		movement_direction = 1

func _on_jump_timeout():
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
