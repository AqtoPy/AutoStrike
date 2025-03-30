extends CharacterBody3D

# ... существующие переменные ...

## Cheat variables ##
var god_mode: bool = false
var noclip: bool = false
var infinite_ammo: bool = false
var wallhack_enabled: bool = false
var aimbot_enabled: bool = false
var aimbot_strength: float = 0.5
var original_speeds: Dictionary
var wallhack_materials = []

@onready var cheats_menu = preload("res://CheatMenu.tscn").instantiate()
@onready var camera_pivot = $CameraPivot
@onready var weapon_system = $WeaponSystem

func _ready():
    # ... существующий код ...
    add_child(cheats_menu)
    cheats_menu.setup(self)
    original_speeds = {
        "walk": walk_speed,
        "run": run_speed,
        "crouch": crouch_speed
    }
    _store_original_materials()

func _store_original_materials():
    var environment = get_world_3d().environment
    for mesh in get_tree().get_nodes_in_group("wall"):
        if mesh is MeshInstance3D:
            wallhack_materials.append({
                "node": mesh,
                "material": mesh.material_override
            })

func _physics_process(delta):
    if noclip:
        _noclip_movement(delta)
        return
    
    if aimbot_enabled:
        _update_aimbot()
    
    # ... существующий код ...

func _update_aimbot():
    var targets = get_tree().get_nodes_in_group("enemies")
    var closest_target = null
    var closest_angle = 180.0
    
    for target in targets:
        var dir_to_target = (target.global_transform.origin - camera_pivot.global_transform.origin).normalized()
        var angle = rad_to_deg(dir_to_target.angle_to(camera_pivot.global_transform.basis.z))
        
        if angle < closest_angle and angle < 45.0:
            closest_angle = angle
            closest_target = target
    
    if closest_target:
        var target_pos = closest_target.global_transform.origin
        var current_rot = camera_pivot.rotation
        var look_at_rot = (camera_pivot.global_transform.looking_at(target_pos, Vector3.UP)).rotation
        camera_pivot.rotation = current_rot.lerp(look_at_rot, aimbot_strength * get_physics_process_delta_time())

func _noclip_movement(delta):
    # ... существующий код ...

func set_wallhack(enabled: bool):
    wallhack_enabled = enabled
    if multiplayer.is_server():
        rpc("sync_wallhack", enabled)
    
    for entry in wallhack_materials:
        if enabled:
            entry.node.material_override = cheats_menu.wallhack_material
        else:
            entry.node.material_override = entry.material

@rpc("any_peer", "call_local")
func sync_wallhack(enabled: bool):
    wallhack_enabled = enabled
    # Повторно применить материалы для синхронизации

func set_aimbot(enabled: bool):
    aimbot_enabled = enabled
    if multiplayer.is_server():
        rpc("sync_aimbot", enabled)

@rpc("any_peer", "call_local")
func sync_aimbot(enabled: bool):
    aimbot_enabled = enabled

# ... остальные существующие функции ...
