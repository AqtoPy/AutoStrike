extends Control

# Константы
const SAVED_SERVERS_PATH = "user://saved_servers.json"
const DEFAULT_PORT = 9050
const MAPS = {
    "de_dust2": "Dust II",
    "de_inferno": "Inferno",
    "de_nuke": "Nuke"
}
const GAME_MODES = {
    "deathmatch": "Deathmatch",
    "team_deathmatch": "Team Deathmatch",
    "zombie": "Zombie Mode"
}

# Ноды интерфейса
@onready var server_list = $TabContainer/Join/ScrollContainer/ServerList
@onready var ip_edit = $TabContainer/Join/HBoxContainer/IPEdit
@onready var port_edit = $TabContainer/Join/HBoxContainer/PortSpinBox
@onready var map_option = $TabContainer/Host/ServerConfig/MapOption
@onready var mode_option = $TabContainer/Host/ServerConfig/ModeOption
@onready var status_label = $TabContainer/Join/StatusLabel

# Данные
var saved_servers = []
var current_server_info = {}

func _ready():
    load_servers()
    setup_defaults()
    populate_map_options()
    populate_mode_options()

func setup_defaults():
    ip_edit.text = "127.0.0.1"
    port_edit.value = DEFAULT_PORT
    status_label.visible = false

func populate_map_options():
    map_option.clear()
    for map_id in MAPS:
        map_option.add_item(MAPS[map_id])

func populate_mode_options():
    mode_option.clear()
    for mode_id in GAME_MODES:
        mode_option.add_item(GAME_MODES[mode_id])

func load_servers():
    if FileAccess.file_exists(SAVED_SERVERS_PATH):
        var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.READ)
        var data = JSON.parse_string(file.get_as_text())
        if data is Array:
            saved_servers = data
            update_server_list()

func save_servers():
    var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(saved_servers))
    file.close()

func update_server_list():
    # Очищаем старый список
    for child in server_list.get_children():
        child.queue_free()
    
    # Добавляем только валидные серверы
    for server in saved_servers:
        if is_valid_server(server):
            add_server_button(server)

func is_valid_server(server: Dictionary) -> bool:
    var required = ["ip", "port", "map", "mode", "name"]
    for key in required:
        if not key in server:
            printerr("Invalid server: missing key", key)
            return false
    return true

func add_server_button(server: Dictionary):
    var hbox = HBoxContainer.new()
    var btn = Button.new()
    
    # Форматируем текст кнопки
    btn.text = "%s\n%s | %s:%d" % [
        server["name"],
        MAPS.get(server["map"], server["map"]),
        server["ip"],
        server["port"]
    ]
    
    btn.custom_minimum_size.y = 60
    btn.pressed.connect(_connect_to_server.bind(server))
    
    var del_btn = Button.new()
    del_btn.text = "X"
    del_btn.custom_minimum_size.x = 40
    del_btn.pressed.connect(_remove_server.bind(server))
    
    hbox.add_child(btn)
    hbox.add_child(del_btn)
    server_list.add_child(hbox)

func _on_connect_button_pressed():
    var selected_map = MAPS.keys()[map_option.selected]
    var selected_mode = GAME_MODES.keys()[mode_option.selected]
    
    var server = {
        "ip": ip_edit.text.strip_edges(),
        "port": int(port_edit.value),
        "map": selected_map,
        "mode": selected_mode,
        "name": "Custom Server"
    }
    
    if server["ip"].is_valid_ip_address():
        _connect_to_server(server)
    else:
        show_error("Invalid IP address")

func _connect_to_server(server: Dictionary):
    if not is_valid_server(server):
        show_error("Invalid server data")
        return
    
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(server["ip"], server["port"])
    
    if error == OK:
        # Сохраняем в историю
        if not server in saved_servers:
            saved_servers.append(server)
            save_servers()
            update_server_list()
        
        multiplayer.multiplayer_peer = peer
        current_server_info = server
        _start_game()
    else:
        show_error("Connection error: %d" % error)

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    save_servers()
    update_server_list()

func show_error(message: String):
    status_label.text = message
    status_label.modulate = Color.RED
    status_label.visible = true
    await get_tree().create_timer(3.0).timeout
    status_label.visible = false

func _on_create_server_pressed():
    var selected_map = MAPS.keys()[map_option.selected]
    var selected_mode = GAME_MODES.keys()[mode_option.selected]
    
    current_server_info = {
        "name": "My %s Server" % GAME_MODES[selected_mode],
        "ip": "127.0.0.1",
        "port": DEFAULT_PORT,
        "map": selected_map,
        "mode": selected_mode,
        "max_players": 8
    }
    
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(DEFAULT_PORT)
    
    if error == OK:
        multiplayer.multiplayer_peer = peer
        show_status("Server created successfully!", Color.GREEN)
        _start_game()
    else:
        show_error("Server creation failed: %d" % error)

func show_status(message: String, color: Color):
    status_label.text = message
    status_label.modulate = color
    status_label.visible = true
    await get_tree().create_timer(3.0).timeout
    status_label.visible = false

func _start_game():
    var game_scene = load("res://game_scene.tscn").instantiate()
    game_scene.server_info = current_server_info
    
    get_tree().root.add_child(game_scene)
    get_tree().current_scene.queue_free()
    get_tree().current_scene = game_scene
