class_name BasicAttack
extends Node2D

@onready var hitbox_component: HitboxComponent = $HitboxComponent
var source_global_position: Vector2
var source_peer_id: int
var frame_passed: bool = false
var damage: int = 1

func _process(_delta):
	if !is_multiplayer_authority():
		return
	if (frame_passed):
		queue_free()
	frame_passed = true

func _ready() -> void:
	hitbox_component.damage = damage
	hitbox_component.source_peer_id = source_peer_id
	hitbox_component.hit_hurtbox.connect(_on_hit_hurtbox)


func register_collision():
	hitbox_component.is_hit_handled = true
	queue_free()

func _on_hit_hurtbox(_hurtbox_component: HurtboxComponent):
	register_collision()
