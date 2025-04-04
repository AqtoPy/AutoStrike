class NavigationPoint extends Node3D:
       var radius: float = 1.0
       var connections: Array = []
       
       func _ready():
           # Реализация визуализации точки
           pass

extends Node3D
class_name MapEditor

# Объявляем все необходимые типы в начале скрипта
class WaterVolume extends Area3D:
    var size: Vector3 = Vector3.ONE
    var water_level: float = 0.0
    var flow_direction: Vector3 = Vector3.ZERO
    
    func _ready():
        var collision = CollisionShape3D.new()
        collision.shape = BoxShape3D.new()
        collision.shape.size = size
        add_child(collision)
        
        var mesh = MeshInstance3D.new()
        mesh.mesh = BoxMesh.new()
        mesh.mesh.size = size
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.2, 0.5, 1.0, 0.7)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mesh.material_override = mat
        add_child(mesh)

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

# Объявляем все необходимые переменные
var nav_points: Array = []  # Добавляем объявление nav_points
var water_volumes: Array = []  # Добавляем объявление water_volumes
var zones: Array = []  # Добавляем объявление zones

# ... [остальная часть вашего скрипта] ...

func create_water_volume() -> WaterVolume:
    var water = WaterVolume.new()
    water.size = brush_size
    water.position = cursor.global_position
    add_child(water)
    water_volumes.append(water)
    return water

func create_zone(type: ZoneType, position: Vector3, size: Vector3) -> Area3D:
    var zone = Area3D.new()
    zone.name = "Zone_%s" % ZoneType.keys()[type]
    
    var shape = BoxShape3D.new()
    shape.size = size
    
    var collision = CollisionShape3D.new()
    collision.shape = shape
    zone.add_child(collision)
    
    var mesh = MeshInstance3D.new()
    mesh.mesh = BoxMesh.new()
    mesh.mesh.size = size
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = _get_zone_color(type)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh.material_override = mat
    
    zone.add_child(mesh)
    zone.position = position
    add_child(zone)
    zones.append(zone)
    
    return zone

func _get_zone_color(type: ZoneType) -> Color:
    match type:
        ZoneType.SPAWN: return Color(0, 1, 0, 0.3)
        ZoneType.TEAM1_SPAWN: return Color(0, 0, 1, 0.3)
        ZoneType.TEAM2_SPAWN: return Color(1, 0, 0, 0.3)
        ZoneType.OBJECTIVE: return Color(1, 1, 0, 0.4)
        _: return Color(1, 1, 1, 0.3)

# ... [остальная часть вашего скрипта] ...

func _ready():
       nav_points = []
       water_volumes = []
       zones = []
       # ... остальная инициализация ...
