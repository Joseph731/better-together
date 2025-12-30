class_name GameUI
extends CanvasLayer

@onready var exp_bar: TextureProgressBar = $ExpBar
@onready var game_text_label: Label = $GameTextLabel
@onready var game_text_animation_player: AnimationPlayer = %GameTextAnimationPlayer
@onready var hp_bar: TextureProgressBar = $HPBar
@onready var level_count_label: Label = $LevelCountLabel
@onready var exp_label: Label = %ExpLabel
@onready var hp_label: Label = %HPLabel


func _ready():
	pass

func connect_player(player: Player):
	(func():
		player.health_component.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health_component.current_health,\
			 player.health_component.max_health)
		player.exp_component.exp_changed.connect(_on_exp_changed)
		_on_exp_changed(player.exp_component.current_exp,\
			 player.exp_component.max_exp)
		player.exp_component.leveled_up.connect(_on_leveled_up)
		_on_leveled_up(player.exp_component.current_level)
		player.exp_component.exp_given.connect(_on_exp_given)
	).call_deferred()


func _on_health_changed(current_health: int, max_health: int):
	hp_bar.value = float(current_health) / max_health if max_health != 0 else 0.0
	hp_label.text = str(current_health) + "/" + str(max_health)

func _on_exp_changed(current_exp: int, max_exp: int):
	exp_bar.value = float(current_exp) / max_exp if max_exp != 0 else 0.0
	exp_label.text = str(current_exp) + "[" + "%.2f" % (current_exp * 100 / max_exp) + "%]"

func _on_leveled_up(current_level: int):
	level_count_label.text = "Lvl " + str(current_level)

func _on_exp_given(amount: int):
	game_text_label.text = "You have gained experience (+" + str(amount) + ")"
	game_text_animation_player.stop()
	game_text_animation_player.play("fade_text")
