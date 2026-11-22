class_name EnemyData
extends Resource

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Stats")
@export var max_health: int = 50
@export var move_speed: float = 80.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0

@export_group("Wander")
@export var can_wander: bool = true
@export var wander_speed: float = 55.0
@export var wander_radius: float = 90.0
@export var idle_wait_min: float = 1.5
@export var idle_wait_max: float = 3.5

@export_group("Combat")
@export var attack_damage: int = 10
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.0
@export var hitbox_offset: float = 18.0
@export var attack_active_frames: Array[int] = [1, 2]

@export_group("Detection")
@export var target_group: StringName = &"player"
@export var require_line_of_sight: bool = true
@export var investigate_wait_time: float = 2.0
@export var detection_radius: float = 140.0

@export_group("Behavior")
@export var is_invulnerable: bool = false
@export var freeze_when_observed: bool = false
@export var observer_fov_angle: float = 75.0

@export_group("Visual")
@export var sprite_frames: SpriteFrames = null
@export var sprite_scale: Vector2 = Vector2.ONE
