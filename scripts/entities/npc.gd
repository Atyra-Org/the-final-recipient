extends Node2D

@onready var interact: Area2D = $Interact
@onready var sprite_2d: Sprite2D = $CharacterBody2D/Sprite2D

func _ready() -> void:
	interact.interact = _on_interact

func _on_interact():
	print("Kamu sudah berinteraksi dengan rafa hama!!!")
	interact.is_interactable = false
