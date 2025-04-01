extends Control
class_name MapEditorUI

signal tool_changed(tool: int)
signal brush_changed(brush: int)
signal zone_changed(zone: int)
signal material_changed(index: int)
signal brush_size_changed(size: Vector3)
signal symmetry_toggled(enabled: bool)
signal mirror_x_toggled(enabled: bool)
signal mirror_z_toggled(enabled: bool)
signal save_pressed
signal load_pressed
signal test_pressed
signal exit_pressed

@onready var tool_panel = $ToolPanel
@onready var brush_panel = $BrushPanel
@onready var zone_panel = $ZonePanel
@onready var material_panel = $MaterialPanel
@onready var settings_panel = $SettingsPanel
@onready var status_label = $StatusLabel
@onready var map_name_edit = $TopBar/MapNameEdit
@onready var grid_button = $TopBar/GridButton
@onready var symmetry_button = $TopBar/SymmetryButton
@onready var mirror_x_button = $TopBar/MirrorXButton
@onready var mirror_z_button = $TopBar/MirrorZButton

var material_buttons := []
var zone_buttons := []
var current_tool := MapEditor.ToolMode.TERRAIN
var current_zone := MapEditor.ZoneType.SPAWN

func _ready():
    setup_ui()
    connect_signals()
    update_ui()

func setup_ui():
    # Создаем кнопки инструментов
    for tool in MapEditor.ToolMode.keys():
        var btn = Button.new()
        btn.text = tool.capitalize()
        btn.toggle_mode = true
        btn.custom_minimum_size = Vector2(100, 40)
        btn.pressed.connect(_on_tool_button_pressed.bind(MapEditor.ToolMode[tool]))
        tool_panel.add_child(btn)
    
    # Создаем кнопки кистей
    for brush in MapEditor.BrushShape.keys():
        var btn = TextureButton.new()
        btn.texture_normal = load("res://assets/icons/brush_%s.png" % brush.to_lower())
        btn.custom_minimum_size = Vector2(40, 40)
        btn.tooltip_text = brush.capitalize()
        btn.pressed.connect(_on_brush_button_pressed.bind(MapEditor.BrushShape[brush]))
        brush_panel.add_child(btn)
    
    # Создаем кнопки зон
    for zone in MapEditor.ZoneType.keys():
        var btn = Button.new()
        btn.text = zone.capitalize()
        btn.custom_minimum_size = Vector2(100, 30)
        btn.pressed.connect(_on_zone_button_pressed.bind(MapEditor.ZoneType[zone]))
        zone_panel.add_child(btn)
        zone_buttons.append(btn)
    
    # Создаем кнопки материалов
    for i in range(10):
        var btn = TextureButton.new()
        btn.texture_normal = load("res://assets/materials/tex_%d.png" % i)
        btn.custom_minimum_size = Vector2(40, 40)
        btn.pressed.connect(_on_material_button_pressed.bind(i))
        material_panel.add_child(btn)
        material_buttons.append(btn)
    
    # Настройка панели параметров
    $SettingsPanel/BrushSizeX.value = 2
    $SettingsPanel/BrushSizeY.value = 2
    $SettingsPanel/BrushSizeZ.value = 2

func connect_signals():
    $TopBar/SaveButton.pressed.connect(_on_save_pressed)
    $TopBar/LoadButton.pressed.connect(_on_load_pressed)
    $TopBar/TestButton.pressed.connect(_on_test_pressed)
    $TopBar/ExitButton.pressed.connect(_on_exit_pressed)
    grid_button.toggled.connect(_on_grid_toggled)
    symmetry_button.toggled.connect(_on_symmetry_toggled)
    mirror_x_button.toggled.connect(_on_mirror_x_toggled)
    mirror_z_button.toggled.connect(_on_mirror_z_toggled)
    $SettingsPanel/BrushSizeX.value_changed.connect(_on_brush_size_changed)
    $SettingsPanel/BrushSizeY.value_changed.connect(_on_brush_size_changed)
    $SettingsPanel/BrushSizeZ.value_changed.connect(_on_brush_size_changed)

func update_ui():
    # Обновляем состояние кнопок инструментов
    for i in range(tool_panel.get_child_count()):
        var btn = tool_panel.get_child(i)
        btn.button_pressed = (i == current_tool)
    
    # Обновляем видимость панелей
    brush_panel.visible = current_tool == MapEditor.ToolMode.TERRAIN
    zone_panel.visible = current_tool == MapEditor.ToolMode.ZONES
    material_panel.visible = current_tool in [MapEditor.ToolMode.TERRAIN, MapEditor.ToolMode.DECALS]
    
    # Обновляем статус специальных кнопок
    symmetry_button.button_pressed = get_parent().symmetry
    mirror_x_button.button_pressed = get_parent().mirror_x
    mirror_z_button.button_pressed = get_parent().mirror_z
    grid_button.button_pressed = get_parent().grid_snap

func _on_tool_button_pressed(tool: int):
    current_tool = tool
    tool_changed.emit(tool)
    update_ui()

func _on_brush_button_pressed(brush: int):
    brush_changed.emit(brush)
    get_parent().current_brush = brush
    get_parent().update_cursor_appearance()

func _on_zone_button_pressed(zone: int):
    current_zone = zone
    zone_changed.emit(zone)
    get_parent().current_zone_type = zone
    
    # Подсветка выбранной зоны
    for btn in zone_buttons:
        btn.button_pressed = (btn.text.to_upper() == MapEditor.ZoneType.keys()[zone])

func _on_material_button_pressed(index: int):
    material_changed.emit(index)
    get_parent().selected_material = get_parent().terrain_materials[index]
    
    # Подсветка выбранного материала
    for i in range(material_buttons.size()):
        material_buttons[i].modulate = Color(1, 1, 1, 0.5 if i != index else 1.0)

func _on_brush_size_changed(value: float):
    var size = Vector3(
        $SettingsPanel/BrushSizeX.value,
        $SettingsPanel/BrushSizeY.value,
        $SettingsPanel/BrushSizeZ.value
    )
    brush_size_changed.emit(size)
    get_parent().brush_size = size
    get_parent().update_cursor_appearance()

func _on_grid_toggled(button_pressed: bool):
    get_parent().grid_snap = button_pressed

func _on_symmetry_toggled(button_pressed: bool):
    symmetry_toggled.emit(button_pressed)
    get_parent().symmetry = button_pressed
    mirror_x_button.disabled = button_pressed
    mirror_z_button.disabled = button_pressed

func _on_mirror_x_toggled(button_pressed: bool):
    mirror_x_toggled.emit(button_pressed)
    get_parent().mirror_x = button_pressed
    if button_pressed:
        mirror_z_button.button_pressed = false

func _on_mirror_z_toggled(button_pressed: bool):
    mirror_z_toggled.emit(button_pressed)
    get_parent().mirror_z = button_pressed
    if button_pressed:
        mirror_x_button.button_pressed = false

func _on_save_pressed():
    if map_name_edit.text.strip_edges() == "":
        show_status("Введите название карты!", Color.RED)
        return
    
    save_pressed.emit()
    show_status("Карта сохранена: " + map_name_edit.text, Color.GREEN)

func _on_load_pressed():
    load_pressed.emit()

func _on_test_pressed():
    test_pressed.emit()
    show_status("Тестовый режим запущен", Color.YELLOW)

func _on_exit_pressed():
    exit_pressed.emit()

func show_status(message: String, color: Color = Color.WHITE):
    status_label.text = message
    status_label.modulate = color
    
    # Анимация появления/исчезания
    var tween = create_tween()
    tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
    tween.tween_interval(3.0)
    tween.tween_property(status_label, "modulate:a", 0.0, 0.5)

func get_map_name() -> String:
    return map_name_edit.text.strip_edges()

func update_tool_ui(tool: int):
    current_tool = tool
    update_ui()

func update_brush_ui(brush: int):
    for i in range(brush_panel.get_child_count()):
        brush_panel.get_child(i).modulate = Color(1, 1, 1, 0.5 if i != brush else 1.0)

func update_zone_ui(zone: int):
    _on_zone_button_pressed(zone)

func update_grid_status(enabled: bool):
    grid_button.button_pressed = enabled
