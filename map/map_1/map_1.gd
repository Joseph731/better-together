class_name Map_1
extends Node2D

const INTERIOR_HOUSE_POSITION: Vector2 = Vector2(0, 1500)

@onready var portal: Portal = $Portal
@onready var interior_multiplayer_spawner: MultiplayerSpawner = $InteriorMultiplayerSpawner

var interior_house_scene: PackedScene = preload("uid://n3uguejcx2wq")
var peer_ids_inside_house: Array[int] = []
var interior_house_instance: Interior_House

func _ready() -> void:
	interior_multiplayer_spawner.spawn_function = func(_data):
		var interior_house = interior_house_scene.instantiate() as Interior_House
		interior_house.global_position = INTERIOR_HOUSE_POSITION
		interior_house.z_index = -1
		return interior_house
	
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		portal.portal_used.connect(_on_portal_used)

func remove_peer_id_from_peer_ids_inside_house(peer_id: int):
	peer_ids_inside_house.erase(peer_id)
	if peer_ids_inside_house.is_empty():
		interior_house_instance.queue_free()

func _on_peer_disconnected(peer_id: int):
	if peer_ids_inside_house.has(peer_id):
		remove_peer_id_from_peer_ids_inside_house(peer_id)

func _on_portal_used(player: Player):
	if !is_instance_valid(interior_house_instance):
		interior_house_instance = interior_multiplayer_spawner.spawn()
		interior_house_instance.portal.portal_used.connect(_on_interior_portal_used)
	player.global_position = interior_house_instance.portal.global_position
	peer_ids_inside_house.append(player.input_multiplayer_authority)

func _on_interior_portal_used(player: Player):
	player.global_position = portal.global_position
	remove_peer_id_from_peer_ids_inside_house(player.input_multiplayer_authority)
