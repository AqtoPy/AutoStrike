extends MeshInstance3D
class_name Line3D

@export var width: float = 0.1
@export var points: PackedVector3Array = []:
    set(value):
        points = value
        update_mesh()

func _ready():
    update_mesh()

func update_mesh():
    if points.size() < 2:
        mesh = null
        return
    
    var immediate_mesh = ImmediateMesh.new()
    var material = StandardMaterial3D.new()
    
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
    for point in points:
        immediate_mesh.surface_add_vertex(point)
    immediate_mesh.surface_end()
    
    mesh = immediate_mesh
