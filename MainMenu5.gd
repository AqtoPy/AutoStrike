extends Control

# Константы
const GAME_SCENE_PATH = "res://game_scene.tscn"
const SAVED_SERVERS_PATH = "user://saved_servers.json"
const SAVE_PATH = "user://player_data.dat"
const SERVER_PORT = 9050
const VIP_PRICE = 500
const VIP_DAYS = 30

# Сигналы
signal vip_purchased(player_id)
signal player_name_changed(new_name)
signal balance_updated(new_balance)

# Ноды интерфейса
@onready var tab_container = $TabContainer
@onready var player_name_edit = $TabContainer/Main/PlayerInfo/NameEdit
@onready var balance_label = $TabContainer/Main/PlayerInfo/BalanceLabel
@onready var vip_button = $TabContainer/Main/PlayerInfo/VIPButton
@onready var vip_status_label = $TabContainer/Main/PlayerInfo/VIPStatusLabel

# Вкладка Host
@onready var server_name_edit = $TabContainer/Host/ServerConfig/NameEdit
@onready var player_limit_slider = $TabContainer/Host/ServerConfig/PlayerLimitSlider
@onready var player_limit_label = $TabContainer/Host/ServerConfig/PlayerLimitLabel
@onready var map_option = $TabContainer/Host/ServerConfig/MapOption
@onready var mode_option = $TabContainer/Host/ServerConfig/ModeOption
@onready var host_status_label = $TabContainer/Host/StatusLabel
@onready var ip_label = $TabContainer/Host/ServerConfig/IPLabel
@onready var copy_ip_button = $TabContainer/Host/ServerConfig/CopyIPButton

# Вкладка Join
@onready var join_ip_input = $TabContainer/Join/HBoxContainer/IPEdit
@onready var join_port_input = $TabContainer/Join/HBoxContainer/PortSpinBox
@onready var join_server_list = $TabContainer/Join/ScrollContainer/ServerList
@onready var join_status_label = $TabContainer/Join/StatusLabel

# Данные
var player_data = {
    "name": "Player",
    "balance": 1000,
    "is_vip": false,
    "vip_days": 0,
    "player_id": ""
}
var current_server_info = {}
var saved_servers = []
var available_maps = ["Dust", "Inferno", "Nuke"]
var available_modes = ["Deathmatch", "Team Deathmatch", "ZombieMode"]
var multiplayer_peer: MultiplayerPeer
var is_server: bool = false

func _ready():
    _load_player_data()
    _generate_player_id()
    _setup_ui()
    _connect_signals()
    load_servers()

func _setup_ui():
    # Main Tab
    player_name_edit.text = player_data["name"]
    _update_balance_ui()
    _update_vip_status_ui()
    
    # Host Tab
    _update_player_limit_label(player_limit_slider.value)
    _populate_map_options()
    _populate_mode_options()
    ip_label.visible = false
    copy_ip_button.visible = false
    
    # Join Tab
    join_port_input.value = SERVER_PORT
    join_ip_input.placeholder_text = "127.0.0.1"
    join_status_label.visible = false

func _connect_signals():
    # Main Tab
    vip_button.pressed.connect(_on_vip_button_pressed)
    player_name_edit.text_submitted.connect(_change_player_name)
    
    # Host Tab
    player_limit_slider.value_changed.connect(_update_player_limit_label)
    copy_ip_button.pressed.connect(_on_copy_ip_button_pressed)
    
    # Join Tab
    join_ip_input.text_changed.connect(_on_ip_edit_text_changed)

func _load_player_data():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        var saved_data = file.get_var()
        if saved_data is Dictionary:
            player_data = saved_data

func _save_player_data():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(player_data)
    file.close()

func _generate_player_id():
    if player_data["player_id"] == "":
        randomize()
        player_data["player_id"] = "player_%d" % randi_range(100000, 999999)
        _save_player_data()

func _update_balance_ui():
    balance_label.text = "Balance: %d$" % player_data["balance"]

func _update_vip_status_ui():
    vip_button.text = "VIP Active" if player_data["is_vip"] else "Buy VIP"
    vip_button.disabled = player_data["is_vip"]
    vip_status_label.text = "VIP expires in %d days" % player_data["vip_days"] if player_data["is_vip"] else "Regular Player"
    vip_status_label.modulate = Color.GREEN if player_data["is_vip"] else Color.WHITE

func _update_player_limit_label(value: float):
    player_limit_label.text = "Max Players: %d" % value

func _populate_map_options():
    map_option.clear()
    for map in available_maps:
        map_option.add_item(map)

func _populate_mode_options():
    mode_option.clear()
    for mode in available_modes:
        mode_option.add_item(mode)

# Host Tab Functions
func _on_host_button_pressed():
    var server_name = server_name_edit.text.strip_edges()
    if server_name.length() < 3:
        host_status_label.text = "Server name too short!"
        host_status_label.modulate = Color.RED
        return
    
    current_server_info = {
        "name": server_name,
        "map": available_maps[map_option.selected],
        "mode": available_modes[mode_option.selected],
        "max_players": int(player_limit_slider.value),
        "port": SERVER_PORT,
        "is_vip": player_data["is_vip"]
    }
    
    _create_network_server()

func _create_network_server():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var error = multiplayer_peer.create_server(SERVER_PORT)
    
    if error == OK:
        multiplayer.multiplayer_peer = multiplayer_peer
        is_server = true
        
        var ips = _get_local_ips()
        var main_ip = ips[0] if ips.size() > 0 else "127.0.0.1"
        ip_label.text = "Server IP: %s:%d" % [main_ip, SERVER_PORT]
        ip_label.visible = true
        copy_ip_button.visible = true
        
        host_status_label.text = "Server created successfully!"
        host_status_label.modulate = Color.GREEN
        
        _start_game()
    else:
        host_status_label.text = "Failed to create server (error %d)" % error
        host_status_label.modulate = Color.RED

func _get_local_ips() -> Array:
    var ips = []
    for ip in IP.get_local_addresses():
        if ip.count(":") == 0 and !ip.begins_with("172.") and ip != "127.0.0.1":
            ips.append(ip)
    return ips

func _on_copy_ip_button_pressed():
    var ip_port = ip_label.text.replace("Server IP: ", "")
    DisplayServer.clipboard_set(ip_port)
    host_status_label.text = "IP copied to clipboard!"
    host_status_label.modulate = Color.WHITE

# Join Tab Functions
func load_servers():
    if FileAccess.file_exists(SAVED_SERVERS_PATH):
        var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.READ)
        var data = JSON.parse_string(file.get_as_text())
        if data is Array:
            saved_servers = data
        file.close()
    update_server_list()

func update_server_list():
    for child in join_server_list.get_children():
        child.queue_free()
    
    for server in saved_servers:
        var hbox = HBoxContainer.new()
        hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
        var btn = Button.new()
        btn.text = "%s:%d" % [server["ip"], server["port"]]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(_connect_to_server.bind(server))
        
        var del_btn = Button.new()
        del_btn.text = "X"
        del_btn.custom_minimum_size.x = 40
        del_btn.pressed.connect(_remove_server.bind(server))
        
        hbox.add_child(btn)
        hbox.add_child(del_btn)
        join_server_list.add_child(hbox)

func _on_connect_button_pressed():
    var ip = join_ip_input.text.strip_edges()
    var port = join_port_input.value
    
    if ip.is_valid_ip_address():
        _connect_to_server({"ip": ip, "port": port})
    else:
        join_status_label.text = "Invalid IP address"
        join_status_label.modulate = Color.RED
        join_status_label.visible = true

func _connect_to_server(server: Dictionary):
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(server["ip"], server["port"])
    
    if error == OK:
        if not server in saved_servers:
            saved_servers.append(server)
            FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)\
                .store_string(JSON.stringify(saved_servers))
        
        multiplayer.multiplayer_peer = peer
        is_server = false
        current_server_info = server
        _start_game()
    else:
        join_status_label.text = "Connection failed (error %d)" % error
        join_status_label.modulate = Color.RED
        join_status_label.visible = true

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)\
        .store_string(JSON.stringify(saved_servers))
    update_server_list()

func _on_ip_edit_text_changed(new_text):
    join_status_label.visible = false
    join_ip_input.modulate = Color.WHITE if new_text.is_valid_ip_address() else Color(1, 0.5, 0.5)

# Common Functions
func _start_game():
    var game_scene = load(GAME_SCENE_PATH).instantiate()
    game_scene.server_info = current_server_info
    
    get_tree().root.add_child(game_scene)
    get_tree().current_scene.queue_free()
    get_tree().current_scene = game_scene
    
    if is_server:
        game_scene.init_host(player_data)
    else:
        game_scene.init_client(player_data)

func _change_player_name(new_name: String):
    new_name = new_name.strip_edges()
    if new_name.length() < 3 or new_name.length() > 16:
        return
    
    player_data["name"] = new_name
    _save_player_data()
    player_name_changed.emit(new_name)

func _on_vip_button_pressed():
    if player_data["is_vip"] or player_data["balance"] < VIP_PRICE:
        return
    
    player_data["balance"] -= VIP_PRICE
    player_data["is_vip"] = true
    player_data["vip_days"] = VIP_DAYS
    _save_player_data()
    _update_balance_ui()
    _update_vip_status_ui()
    vip_purchased.emit(player_data["player_id"])

func add_funds(amount: int):
    if amount > 0:
        player_data["balance"] += amount
        _save_player_data()
        _update_balance_ui()
        balance_updated.emit(player_data["balance"])

func _exit_tree():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()
