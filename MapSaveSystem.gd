extends Node
class_name MapSaveSystem

const MAP_DIR = "user://custom_maps/"
const THUMBNAIL_DIR = "user://thumbnails/"

static func save_map(map_name: String, data: Dictionary) -> bool:
    DirAccess.make_dir_recursive_absolute(MAP_DIR)
    DirAccess.make_dir_recursive_absolute(THUMBNAIL_DIR)
    
    var file_path = MAP_DIR.path_join(map_name + ".map")
    var thumbnail_path = THUMBNAIL_DIR.path_join(map_name + ".png")
    
    # Save thumbnail
    var viewport = _get_thumbnail_viewport()
    var image = viewport.get_texture().get_image()
    image.resize(256, 256)
    image.save_png(thumbnail_path)
    
    # Save map data
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_var(data)
        file.close()
        return true
    return false

static func load_map(map_name: String) -> Dictionary:
    var file_path = MAP_DIR.path_join(map_name + ".map")
    if FileAccess.file_exists(file_path):
        var file = FileAccess.open(file_path, FileAccess.READ)
        var data = file.get_var()
        file.close()
        return data
    return {}

static func get_saved_maps() -> Array:
    var maps := []
    var dir = DirAccess.open(MAP_DIR)
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if file.ends_with(".map"):
                var map_name = file.get_basename()
                maps.append({
                    "name": map_name,
                    "path": MAP_DIR.path_join(file),
                    "thumbnail": THUMBNAIL_DIR.path_join(map_name + ".png"),
                    "timestamp": FileAccess.get_modified_time(MAP_DIR.path_join(file))
                })
            file = dir.get_next()
    return maps

static func _get_thumbnail_viewport() -> Viewport:
    var viewport = Viewport.new()
    viewport.size = Vector2(512, 512)
    viewport.render_target_update_mode = Viewport.UPDATE_ONCE
    viewport.transparent_bg = true
    return viewport
