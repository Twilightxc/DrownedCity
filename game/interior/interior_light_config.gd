class_name InteriorLightConfig
extends Resource
## Dark interiors and the flashlight (GDD §5, PHASE0 0.8 part 2). Instances live in data/fx/.

@export_group("Rooms")
@export var dark: float = 0.06  ## albedo scale in a room the player has never seen
@export var remembered: float = 0.4  ## a room seen before, out of sight now
@export var fade_per_sec: float = 3.0  ## light level change per second
@export var view_range: float = 18.0  ## m: doors farther than this don't reveal their rooms
@export var check_sec: float = 0.15  ## sight checks run this often

@export_group("Flashlight")
@export var flashlight_energy: float = 2.5
@export var flashlight_range: float = 12.0  ## m
@export var flashlight_angle: float = 32.0  ## degrees, half cone
@export var flashlight_height: float = 1.4  ## m above the player's floor
@export var flashlight_tilt: float = 0.25  ## down per metre along the aim
@export var flashlight_color: Color = Color(1.0, 0.93, 0.8)
