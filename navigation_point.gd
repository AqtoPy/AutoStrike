extends Node3D
class_name NavigationPoint

@export var radius: float = 1.0
@export var connections: Array[NavigationPoint] = []
@export var is_important: bool = false

func _ready():
    # Визуальное представление точки
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = mesh
    
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0, 1, 0, 0.5) if is_important else Color(1, 0, 0, 0.5)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    
    mesh_instance.material_override = material
    add_child(mesh_instance)
    
    # Коллизия для выделения
    var collision = CollisionShape3D.new()
    collision.shape = SphereShape3D.new()
    collision.shape.radius = radius
    add_child(collision)

func add_connection(point: NavigationPoint):
    if not point in connections:
        connections.append(point)
        point.connections.append(self)
        update_visual_connections()

func update_visual_connections():
    # Очищаем старые соединения
    for child in get_children():
        if child is Line3D:
            child.queue_free()
    
    # Создаём новые линии соединений
    for connected_point in connections:
        if is_instance_valid(connected_point):
            var line = Line3D.new()
            line.width = 0.1
            line.points = [Vector3.ZERO, to_local(connected_point.global_position)]
            line.material = StandardMaterial3D.new()
            line.material.albedo_color = Color(1, 1, 1, 0.3)
            add_child(line)
