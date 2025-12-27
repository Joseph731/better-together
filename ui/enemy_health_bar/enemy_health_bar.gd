extends TextureProgressBar

@export var health_component: HealthComponent

func _ready():
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(current_health: int, max_health: int):
	visible = true
	value = float(current_health) / float(max_health)
