class_name BossData
extends Resource

@export_group("Identity")
@export var id: StringName = &"the_fractured_seal"
@export var boss_name: String = "The Fractured Seal"

@export_group("Stats")
@export var max_health: int = 300

@export_group("Arena And AoE Telegraph")
@export var arena_radius: float = 220.0
@export var aoe_radius: float = 56.0
@export var aoe_charge_duration: float = 1.6
@export var aoe_lock_ratio: float = 0.8
@export var aoe_cooldown: float = 1.4
@export var aoe_damage: int = 20
@export var aoe_knockback: float = 200.0
@export var target_group: StringName = &"player"

@export_group("Phase Two")
@export var phase2_health_threshold: int = 30
@export var phase2_tint: Color = Color(1.0, 0.3, 0.45, 1.0)
@export var phase2_minion_scene: PackedScene = preload("res://scenes/characters/enemy_dummy.tscn")
@export var phase2_minion_data: Resource = preload("res://resources/enemies/greedy_gremlin.tres")
@export var phase2_minion_count: int = 2
@export var phase2_aoe_cooldown_multiplier: float = 0.75

@export_group("Visual")
@export var core_texture: Texture2D = null
@export var core_scale: Vector2 = Vector2.ONE
@export var explosion_texture: Texture2D = null
@export var explosion_hframes: int = 6
@export var explosion_vframes: int = 24
@export var explosion_row: int = 22
@export var explosion_frame_count: int = 6