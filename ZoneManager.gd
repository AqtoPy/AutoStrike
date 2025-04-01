extends Node
class_name ZoneManager

enum ZoneEffects {
    NONE,
    HEAL,
    DAMAGE,
    SPEED_BOOST,
    JUMP_BOOST,
    GRAVITY_CHANGE,
    TELEPORT,
    WEATHER_CHANGE,
    BUFF,
    DEBUFF,
    INVISIBILITY
}

func create_zone(type: ZoneType, position: Vector3, size: Vector3) -> Area3D:
    var zone = Area3D.new()
    zone.name = "Zone_%s" % ZoneType.keys()[type]
    
    # Collision shape
    var shape : Shape3D
    var mesh : Mesh
    
    match type:
        ZoneType.SPAWN, ZoneType.TEAM1_SPAWN, ZoneType.TEAM2_SPAWN:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
            
        ZoneType.OBJECTIVE, ZoneType.BUFF, ZoneType.DEBUFF:
            shape = SphereShape3D.new()
            shape.radius = size.x / 2
            mesh = SphereMesh.new()
            mesh.radius = size.x / 2
            
        ZoneType.TELEPORT:
            shape = CylinderShape3D.new()
            shape.radius = size.x / 2
            shape.height = size.y
            mesh = CylinderMesh.new()
            mesh.top_radius = size.x / 2
            mesh.bottom_radius = size.x / 2
            mesh.height = size.y
            
        ZoneType.GRAVITY:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
            
        ZoneType.WEATHER:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
            
        ZoneType.SAFE:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
            
        ZoneType.NO_BUILD:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
            
        ZoneType.CUSTOM:
            shape = BoxShape3D.new()
            shape.size = size
            mesh = BoxMesh.new()
            mesh.size = size
    
    var collision = CollisionShape3D.new()
    collision.shape = shape
    zone.add_child(collision)
    
    # Visual representation
    var visual = MeshInstance3D.new()
    visual.mesh = mesh
    var mat = StandardMaterial3D.new()
    
    match type:
        ZoneType.SPAWN: mat.albedo_color = Color(0, 1, 0, 0.3)
        ZoneType.TEAM1_SPAWN: mat.albedo_color = Color(0, 0, 1, 0.3)
        ZoneType.TEAM2_SPAWN: mat.albedo_color = Color(1, 0, 0, 0.3)
        ZoneType.OBJECTIVE: mat.albedo_color = Color(1, 1, 0, 0.4)
        ZoneType.BUFF: mat.albedo_color = Color(0.5, 0, 1, 0.3)
        ZoneType.DEBUFF: mat.albedo_color = Color(1, 0.5, 0, 0.3)
        ZoneType.TELEPORT: mat.albedo_color = Color(0, 1, 1, 0.4)
        ZoneType.GRAVITY: mat.albedo_color = Color(0.8, 0.2, 0.8, 0.3)
        ZoneType.WEATHER: mat.albedo_color = Color(0.2, 0.8, 0.8, 0.3)
        ZoneType.SAFE: mat.albedo_color = Color(1, 1, 1, 0.2)
        ZoneType.NO_BUILD: mat.albedo_color = Color(1, 0, 0, 0.2)
        ZoneType.CUSTOM: mat.albedo_color = Color(1, 1, 1, 0.3)
    
    mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
    visual.material_override = mat
    zone.add_child(visual)
    
    # Zone properties
    zone.set_meta("zone_type", type)
    zone.set_meta("zone_size", size)
    
    # Add script based on zone type
    match type:
        ZoneType.TELEPORT:
            zone.set_script(load("res://scripts/zones/teleport_zone.gd"))
        ZoneType.GRAVITY:
            zone.set_script(load("res://scripts/zones/gravity_zone.gd"))
        ZoneType.BUFF, ZoneType.DEBUFF:
            zone.set_script(load("res://scripts/zones/buff_zone.gd"))
        _:
            zone.set_script(load("res://scripts/zones/base_zone.gd"))
    
    return zone
