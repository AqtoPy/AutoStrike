extends Node3D
class_name MapEditor

enum ToolMode {
    TERRAIN, 
    OBJECTS, 
    ZONES, 
    DECALS,
    LIGHTING,
    PATHING,
    WATER,
    TRIGGERS
}

enum BrushShape {
    CUBE, 
    SPHERE, 
    CYLINDER,
    RAMP,
    ARCH,
    STAIRS
}

enum ZoneType {
    SPAWN,
    TEAM1_SPAWN,
    TEAM2_SPAWN,
    OBJECTIVE,
    BUFF,
    DEBUFF,
    TELEPORT,
    GRAVITY,
    WEATHER,
    SAFE,
    NO_BUILD,
    CUSTOM
}

# Настройки
@export var grid_size := 1.0
@export var grid_snap := true
@export var max_undo_steps := 50
@export var default_material : StandardMaterial3D

# Текущее состояние
var current_tool := ToolMode.TERRAIN
var current_brush := BrushShape.CUBE
var brush_size := Vector3(2, 2, 2)
var selected_material : Material
var current_zone_type := ZoneType.SPAWN
var mirror_x := false
var mirror_z := false
var symmetry := false

# Данные карты
var map_objects := []
var terrain_blocks := []
var zones := []
var decals := []
var lights := []
var nav_points := []
var water_volumes := []
var triggers := []
var undo_stack := []
var redo_stack := []

# Ноды
@onready var camera : Camera3D = $EditorCamera
@onready var cursor : MeshInstance3D = $EditorCursor
@onready var object_library : Node = $ObjectLibrary
@onready var zone_manager : Node = $ZoneManager
@onready var ui : Control = $UI
@onready var selection_outline : MeshInstance3D = $SelectionOutline

# Текстуры и материалы
var terrain_materials := []
var decal_materials := []

func _ready():
    setup_editor()
    load_resources()
    
func setup_editor():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    update_cursor_appearance()
    ui.update_tool_ui(current_tool)
    
func load_resources():
    # Загрузка материалов
    var mat_dir = "res://materials/terrain/"
    var dir = DirAccess.open(mat_dir)
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if file.ends_with(".tres"):
                terrain_materials.append(load(mat_dir + file))
            file = dir.get_next()
    
    # Загрузка декалей
    var decal_dir = "res://materials/decals/"
    dir = DirAccess.open(decal_dir)
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if file.ends_with(".tres"):
                decal_materials.append(load(decal_dir + file))
            file = dir.get_next()

func _process(delta):
    update_cursor_position()
    handle_hotkeys()
    
func _input(event):
    if event is InputEventMouseMotion:
        handle_camera_rotation(event)
    
    if event.is_action_pressed("editor_place"):
        place_object()
    elif event.is_action_pressed("editor_remove"):
        remove_object()
    elif event.is_action_pressed("editor_rotate"):
        rotate_selected(45)
    elif event.is_action_pressed("editor_scale_up"):
        scale_selected(1.1)
    elif event.is_action_pressed("editor_scale_down"):
        scale_selected(0.9)

func update_cursor_position():
    var mouse_pos = get_viewport().get_mouse_position()
    var ray_length = 1000
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * ray_length
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = space_state.intersect_ray(query)
    
    if result:
        var pos = result.position
        if grid_snap:
            pos = pos.snapped(Vector3.ONE * grid_size)
        cursor.global_position = pos
        cursor.visible = true
    else:
        cursor.visible = false

func handle_hotkeys():
    if Input.is_action_just_pressed("editor_undo"):
        undo_action()
    elif Input.is_action_just_pressed("editor_redo"):
        redo_action()
    elif Input.is_action_just_pressed("editor_save"):
        save_map()
    elif Input.is_action_just_pressed("editor_load"):
        load_map()
    elif Input.is_action_just_pressed("editor_toggle_grid"):
        grid_snap = !grid_snap
        ui.update_grid_status(grid_snap)

func place_object():
    var new_objects := []
    
    match current_tool:
        ToolMode.TERRAIN:
            var main_obj = create_terrain_block()
            if main_obj:
                new_objects.append(main_obj)
                if symmetry:
                    var mirrored = mirror_object(main_obj)
                    if mirrored: new_objects.append(mirrored)
        
        ToolMode.OBJECTS:
            var obj = object_library.instantiate_selected()
            if obj:
                obj.position = cursor.global_position
                add_child(obj)
                new_objects.append(obj)
        
        ToolMode.ZONES:
            var zone = zone_manager.create_zone(current_zone_type, cursor.global_position, brush_size)
            if zone:
                add_child(zone)
                new_objects.append(zone)
        
        ToolMode.DECALS:
            var decal = create_decal()
            if decal:
                new_objects.append(decal)
        
        ToolMode.LIGHTING:
            var light = create_light()
            if light:
                new_objects.append(light)
        
        ToolMode.PATHING:
            var point = create_nav_point()
            if point:
                new_objects.append(point)
        
        ToolMode.WATER:
            var water = create_water_volume()
            if water:
                new_objects.append(water)
        
        ToolMode.TRIGGERS:
            var trigger = create_trigger()
            if trigger:
                new_objects.append(trigger)
    
    if not new_objects.is_empty():
        save_state("add_objects", {"objects": new_objects})

func create_terrain_block() -> MeshInstance3D:
    var mesh_instance = MeshInstance3D.new()
    
    match current_brush:
        BrushShape.CUBE:
            mesh_instance.mesh = BoxMesh.new()
            mesh_instance.mesh.size = brush_size
        BrushShape.SPHERE:
            mesh_instance.mesh = SphereMesh.new()
            mesh_instance.mesh.radius = brush_size.x / 2
            mesh_instance.mesh.height = brush_size.x
        BrushShape.CYLINDER:
            mesh_instance.mesh = CylinderMesh.new()
            mesh_instance.mesh.top_radius = brush_size.x / 2
            mesh_instance.mesh.bottom_radius = brush_size.x / 2
            mesh_instance.mesh.height = brush_size.y
        BrushShape.RAMP:
            mesh_instance.mesh = PrismMesh.new()
            mesh_instance.mesh.size = Vector3(brush_size.x, brush_size.y, brush_size.z)
        BrushShape.ARCH:
            mesh_instance.mesh = load("res://meshes/arch.obj")
        BrushShape.STAIRS:
            mesh_instance.mesh = load("res://meshes/stairs.obj")
    
    mesh_instance.position = cursor.global_position
    
    if selected_material:
        mesh_instance.material_override = selected_material
    elif default_material:
        mesh_instance.material_override = default_material
    
    add_child(mesh_instance)
    return mesh_instance

func mirror_object(original: Node3D) -> Node3D:
    var mirrored = original.duplicate()
    
    if mirror_x:
        mirrored.position.x = -original.position.x
        mirrored.scale.x = -original.scale.x
    elif mirror_z:
        mirrored.position.z = -original.position.z
        mirrored.scale.z = -original.scale.z
    
    if mirrored != original:
        add_child(mirrored)
        return mirrored
    return null

func remove_object():
    var space_state = get_world_3d().direct_space_state
    var mouse_pos = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * 1000
    
    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var obj = result.collider.get_parent()
        if obj is MeshInstance3D or obj is Area3D or obj is Light3D:
            save_state("remove_object", {"object": obj})
            obj.queue_free()

func save_state(action: String, data: Dictionary):
    undo_stack.push_back({"action": action, "data": data})
    if undo_stack.size() > max_undo_steps:
        undo_stack.pop_front()
    redo_stack.clear()

func undo_action():
    if undo_stack.is_empty(): return
    
    var last_action = undo_stack.pop_back()
    match last_action["action"]:
        "add_objects":
            for obj in last_action["data"]["objects"]:
                if is_instance_valid(obj):
                    obj.queue_free()
        "remove_object":
            var obj = last_action["data"]["object"]
            if obj and not is_instance_valid(obj.get_parent()) and obj.filename:
                var new_obj = load(obj.filename).instantiate()
                new_obj.transform = obj.transform
                add_child(new_obj)
    
    redo_stack.push_back(last_action)

func redo_action():
    if redo_stack.is_empty(): return
    
    var last_redo = redo_stack.pop_back()
    match last_redo["action"]:
        "add_objects":
            for obj in last_redo["data"]["objects"]:
                if obj and not is_instance_valid(obj.get_parent()) and obj.filename:
                    var new_obj = load(obj.filename).instantiate()
                    new_obj.transform = obj.transform
                    add_child(new_obj)
        "remove_object":
            var obj = last_redo["data"]["object"]
            if is_instance_valid(obj):
                obj.queue_free()
    
    undo_stack.push_back(last_redo)

func rotate_selected(degrees: float):
    var selected = get_selected_object()
    if selected:
        selected.rotate_y(deg_to_rad(degrees))
        save_state("rotate_object", {"object": selected, "amount": degrees})

func scale_selected(factor: float):
    var selected = get_selected_object()
    if selected:
        selected.scale *= factor
        save_state("scale_object", {"object": selected, "factor": factor})

func get_selected_object() -> Node3D:
    var mouse_pos = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * 1000
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var obj = result.collider.get_parent()
        if obj is MeshInstance3D or obj is Area3D or obj is Light3D:
            selection_outline.global_transform = obj.global_transform
            selection_outline.visible = true
            return obj
    
    selection_outline.visible = false
    return null

func save_map():
    var map_name = ui.get_map_name()
    if map_name.is_empty():
        map_name = "untitled_" + str(Time.get_unix_time_from_system())
    
    var map_data = {
        "terrain": serialize_objects(terrain_blocks),
        "zones": serialize_objects(zones),
        "objects": serialize_objects(map_objects),
        "lights": serialize_objects(lights),
        "nav_points": serialize_objects(nav_points),
        "water": serialize_objects(water_volumes),
        "triggers": serialize_objects(triggers),
        "metadata": {
            "version": "1.0",
            "created": Time.get_datetime_string_from_system()
        }
    }
    
    MapSaveSystem.save_map(map_name, map_data)
    ui.show_message("Map saved successfully!")

func load_map():
    var map_name = ui.get_selected_map()
    if map_name:
        var map_data = MapSaveSystem.load_map(map_name)
        if map_data:
            clear_map()
            deserialize_objects(map_data.get("terrain", []))
            deserialize_objects(map_data.get("zones", []))
            deserialize_objects(map_data.get("objects", []))
            deserialize_objects(map_data.get("lights", []))
            deserialize_objects(map_data.get("nav_points", []))
            deserialize_objects(map_data.get("water", []))
            deserialize_objects(map_data.get("triggers", []))
            ui.show_message("Map loaded successfully!")

func clear_map():
    for child in get_children():
        if child != camera and child != cursor and child != ui and child != selection_outline:
            child.queue_free()

func serialize_objects(objects: Array) -> Array:
    var result = []
    for obj in objects:
        if is_instance_valid(obj):
            var data = {
                "type": obj.get_class(),
                "position": obj.position,
                "rotation": obj.rotation,
                "scale": obj.scale,
                "properties": {}
            }
            
            if obj is MeshInstance3D:
                data["mesh"] = obj.mesh.resource_path if obj.mesh else ""
                data["material"] = obj.material_override.resource_path if obj.material_override else ""
            
            result.append(data)
    return result

func deserialize_objects(data: Array):
    for item in data:
        var obj : Node3D
        
        match item["type"]:
            "MeshInstance3D":
                obj = MeshInstance3D.new()
                if item.has("mesh"):
                    obj.mesh = load(item["mesh"])
                if item.has("material"):
                    obj.material_override = load(item["material"])
            
            "Area3D":
                obj = zone_manager.create_zone_from_data(item)
            
            "Light3D":
                obj = create_light_from_data(item)
            
            "NavigationPoint":
                obj = create_nav_point_from_data(item)
            
            "WaterVolume":
                obj = create_water_from_data(item)
            
            "TriggerVolume":
                obj = create_trigger_from_data(item)
        
        if obj:
            obj.position = item["position"]
            obj.rotation = item["rotation"]
            obj.scale = item["scale"]
            add_child(obj)

func update_cursor_appearance():
    cursor.mesh = null
    
    match current_brush:
        BrushShape.CUBE:
            cursor.mesh = BoxMesh.new()
            cursor.mesh.size = brush_size
        BrushShape.SPHERE:
            cursor.mesh = SphereMesh.new()
            cursor.mesh.radius = brush_size.x / 2
            cursor.mesh.height = brush_size.x
        BrushShape.CYLINDER:
            cursor.mesh = CylinderMesh.new()
            cursor.mesh.top_radius = brush_size.x / 2
            cursor.mesh.bottom_radius = brush_size.x / 2
            cursor.mesh.height = brush_size.y
        BrushShape.RAMP:
            cursor.mesh = PrismMesh.new()
            cursor.mesh.size = brush_size
        BrushShape.ARCH:
            cursor.mesh = load("res://meshes/arch.obj")
        BrushShape.STAIRS:
            cursor.mesh = load("res://meshes/stairs.obj")
    
    if cursor.mesh:
        cursor.material_override = StandardMaterial3D.new()
        cursor.material_override.albedo_color = Color(1, 1, 1, 0.5)
        cursor.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        cursor.material_override.flags_no_depth_test = true

func handle_camera_rotation(event: InputEventMouseMotion):
    if Input.is_action_pressed("editor_rotate_camera"):
        camera.rotate_y(-event.relative.x * 0.01)
        camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * 0.01)
        camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

# Дополнительные функции создания объектов
func create_decal() -> Decal:
    var decal = Decal.new()
    decal.size = Vector3(brush_size.x, 0.1, brush_size.z)
    decal.position = cursor.global_position
    decal.texture_albedo = decal_materials[0].albedo_texture if decal_materials else null
    add_child(decal)
    return decal

func create_light() -> Light3D:
    var light = OmniLight3D.new()
    light.position = cursor.global_position
    light.light_color = Color(1, 1, 0.8)
    light.light_energy = 5.0
    light.shadow_enabled = true
    add_child(light)
    return light

func create_nav_point() -> NavigationPoint:
    var point = NavigationPoint.new()
    point.position = cursor.global_position
    point.radius = brush_size.x / 2
    add_child(point)
    return point

func create_water_volume() -> WaterVolume:
    var water = WaterVolume.new()
    water.size = brush_size
    water.position = cursor.global_position
    add_child(water)
    return water

func create_trigger() -> TriggerVolume:
    var trigger = TriggerVolume.new()
    trigger.size = brush_size
    trigger.position = cursor.global_position
    trigger.script = preload("res://scripts/triggers/default_trigger.gd")
    add_child(trigger)
    return trigger

# Сигналы от UI
func _on_ui_tool_changed(tool: int):
    current_tool = tool
    update_cursor_appearance()

func _on_ui_brush_changed(brush: int):
    current_brush = brush
    update_cursor_appearance()

func _on_ui_zone_changed(zone: int):
    current_zone_type = zone

func _on_ui_material_changed(index: int):
    if index < terrain_materials.size():
        selected_material = terrain_materials[index]

func _on_ui_brush_size_changed(size: Vector3):
    brush_size = size
    update_cursor_appearance()

func _on_ui_symmetry_toggled(enabled: bool):
    symmetry = enabled

func _on_ui_mirror_x_toggled(enabled: bool):
    mirror_x = enabled
    mirror_z = false if enabled else mirror_z

func _on_ui_mirror_z_toggled(enabled: bool):
    mirror_z = enabled
    mirror_x = false if enabled else mirror_x
