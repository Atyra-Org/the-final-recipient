class_name BossData
extends Resource

@export_group("Identity")
@export var id: StringName = &"the_fractured_seal"
@export var boss_name: String = "The Fractured Seal"

@export_group("Stats")
@export var max_health: int = 300

@export_group("Arena And Phase One")
@export var arena_radius: float = 220.0
@export var chain_count: int = 4
@export var chain_rotation_speed: float = 0.65
@export var chain_damage: int = 15
@export var chain_knockback: float = 180.0
@export var chain_hit_cooldown: float = 0.6
@export var chain_width: float = 8.0
@export var target_group: StringName = &"player"

@export_group("Visual")
@export var core_texture: Texture2D = null
@export var core_scale: Vector2 = Vector2.ONE
@export var chain_texture: Texture2D = null