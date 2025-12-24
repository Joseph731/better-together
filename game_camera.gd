class_name GameCamera
extends Camera2D

#const NOISE_GROWTH: float = 750
#const SHAKE_DECAY_RATE: float = 10

#@export var noise_texture: FastNoiseLite
#@export var shake_strength: float

@onready var position_smoothing_and_drag_disabled_timer: Timer = $PositionSmoothingAndDragDisabledTimer


static var instance: GameCamera

#var noise_offset_x: float
#var noise_offset_y: float
#var current_shake_percentage: float

func _ready() -> void:
	instance = self
	position_smoothing_and_drag_disabled_timer.timeout.connect(_on_position_smoothing_and_drag_disabled_timeout)

#func _process(delta: float) -> void:
	##if current_shake_percentage == 0:
		##return
	##
	##noise_offset_x += NOISE_GROWTH * delta
	#noise_offset_y += NOISE_GROWTH * delta
	#
	#var offset_sample_x := noise_texture.get_noise_2d(noise_offset_x, 0)
	#var offset_sample_y := noise_texture.get_noise_2d(0, noise_offset_y)
	#offset = Vector2(offset_sample_x, offset_sample_y) * shake_strength\
		 #* current_shake_percentage * current_shake_percentage
	#
	#current_shake_percentage = max(current_shake_percentage - (SHAKE_DECAY_RATE * delta), 0)

#static func shake(shake_percent: float):
	#instance.current_shake_percentage = clamp(shake_percent, 0, 1)

func temporarily_disable_position_smoothing_and_drag():
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	position_smoothing_and_drag_disabled_timer.start()

func _on_position_smoothing_and_drag_disabled_timeout():
	position_smoothing_enabled = true
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
