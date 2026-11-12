extends Node2D

@onready var interact: Area2D = $Interact
@onready var sprite_2d: Sprite2D = $CharacterBody2D/Sprite2D

func _ready() -> void:
	interact.interact = _on_interact
	
func _on_interact():
	if sprite_2d.frame == 0:
		sprite_2d.frame = 1
		interact.is_interactable = false
		print("Kamu sudah berinteraksi dengan rafa hama!!!")
