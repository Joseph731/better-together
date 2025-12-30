class_name Slime
extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -600.0


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent
@onready var enemy_health_bar: TextureProgressBar = $EnemyHealthBar
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
var damage_number_scene: PackedScene = preload("uid://bs02ccyodye1u")
var exp_reward:int = 5
var attack_damage:float = 1.0
var last_hit_by_peer_id: int = -1

func _ready():
	if is_multiplayer_authority():
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)


func _physics_process(delta):
	if is_multiplayer_authority():
		velocity += get_gravity() * delta #APPLY GRAVITY
		
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 3000.0 * delta) #HIGH FRICTION
		else:
			velocity.x = move_toward(velocity.x, 0, 350.0 * delta) #LOW FRICTION
		
		move_and_slide()

func turn_hitbox_on_or_off(bool_val: bool):
	hurtbox_component.set_deferred("monitoring", bool_val)
	hurtbox_component.set_deferred("monitorable", bool_val)
	hitbox_component.set_deferred("monitoring", bool_val)
	hitbox_component.set_deferred("monitorable", bool_val)

@rpc("authority", "call_local", "reliable")
func play_death_animation():
	enemy_health_bar.visible = false
	animation_player.play("death") #queue_free_if_server at end of animation

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

func _on_died():
	#Global.monster_killed_logic(exp_given)
	turn_hitbox_on_or_off(false)
	if last_hit_by_peer_id > -1:
		var players = get_tree().get_nodes_in_group("player") as Array[Player]
		var killer: Player
		for player in players:
			if player.input_multiplayer_authority == last_hit_by_peer_id:
				killer = player
				killer.exp_component.give_exp(exp_reward)
				players.erase(player)
				break
		for player in players: #players had the killer removed from it in the for loop above
			if player.global_position.distance_squared_to(killer.global_position) < 2000 * 2000: #squared is more optimized and functionally the same when comparing
				player.exp_component.give_exp(exp_reward/2)
		
	play_death_animation.rpc() #queue_frees_the_slime

func _on_hit_by_hitbox(attacking_hitbox_component: HitboxComponent):
	last_hit_by_peer_id = attacking_hitbox_component.source_peer_id
	if attacking_hitbox_component.owner.get("source_global_position") == null:
		return
	if (attacking_hitbox_component.owner.source_global_position.x < global_position.x): #KNOCKBACK
		velocity.x = 450.0
	else:
		velocity.x = -450.0
