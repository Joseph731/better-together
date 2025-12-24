class_name Portal
extends Node2D

signal portal_used(player: Player)

@onready var area_2d: Area2D = $Area2D

var players_on_portal: Array[Player]

func _ready() -> void:
	if is_multiplayer_authority():
		area_2d.area_entered.connect(_on_area_entered)
		area_2d.area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if is_multiplayer_authority() && !players_on_portal.is_empty():
		for player in players_on_portal: 
			if player.player_input_synchronizer_component.is_enter_pressed && player.portal_cooldown.is_stopped():
				portal_used.emit(player)
				player.portal_cooldown.start()
				temporarily_disable_players_camera_effects.rpc(player.input_multiplayer_authority)

@rpc("authority", "call_local")
func temporarily_disable_players_camera_effects(peer_id: int):
	for player in get_tree().get_nodes_in_group("player") as Array[Player]:
		if player.input_multiplayer_authority == peer_id:
			player.game_camera.temporarily_disable_position_smoothing_and_drag()
			break

func _on_area_entered(other_area: Area2D):
	if other_area.get_owner() is not Player:
		return
	var player: Player = other_area.get_owner()
	players_on_portal.append(player)

func _on_area_exited(other_area: Area2D):
	if other_area.get_owner() is not Player:
		return
	var player: Player = other_area.get_owner()
	players_on_portal.erase(player)
