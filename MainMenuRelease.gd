extends Control

const GAME_SCENE_PATH = "res://game_scene.tscn"
const SAVED_SERVERS_PATH = "user://saved_servers.json"
const MAPS = {
    "Dust": "res://maps/Dust.tscn",
    "ZeroWall": "res://maps/ZeroWall.tscn"
}

# Сигналы
signal vip_purchased(player_id)
signal server_created(server_config: Array)
signal server_selected(server_info: Dictionary)
signal player_name_changed(new_name)
signal balance_updated(new_balance)

# Константы
const VIP_PRICE = 500
const VIP_DAYS = 30
const SAVE_PATH = "user://player_data.dat"
const CUSTOM_MODES_DIR = "res://game_modes/"
const DEFAULT_PORT = 9050
const SERVER_PORT = 9050
const ColorGOLD = Color(1.0, 0.84, 0.0)  # Золотой цвет для VIP

# Переменные
var multiplayer_peer = ENetMultiplayerPeer.new()
var current_server_info: Dictionary = {}
var is_server: bool = false
var active_servers = []
var udp = PacketPeerUDP.new()
var player_data = {
    "name": "Player",
    "balance": 1000,
    "is_vip": false,
    "vip_days": 0,
    "player_id": ""
}
var available_maps = ["Dust", "ZeroWall"]
var available_modes = []
var custom_modes = []
var server_list_data = []
var saved_servers = []

# Ноды интерфейса
@onready var tabs = $TabContainer
@onready var player_name_edit = $TabContainer/Main/PlayerInfo/NameEdit
@onready var balance_label = $TabContainer/Main/PlayerInfo/BalanceLabel
@onready var vip_button = $TabContainer/Main/PlayerInfo/VIPButton
@onready var vip_status_label = $TabContainer/Main/PlayerInfo/VIPStatusLabel
@onready var server_list = $TabContainer/Join/ScrollContainer/ServerList
@onready var server_name_edit = $TabContainer/Create/ServerConfig/NameEdit
@onready var player_limit_slider = $TabContainer/Create/ServerConfig/PlayersLimitSlider
@onready var player_limit_label = $TabContainer/Create/ServerConfig/PlayersLimitLabel
@onready var map_option = $TabContainer/Create/ServerConfig/MapOption
@onready var mode_option = $TabContainer/Create/ServerConfig/ModeOption
@onready var status_label = $StatusLabel
@onready var vip_dialog = $VIPDialog
@onready var vip_price_label = $TabContainer/Main/PlayerInfo/VIPPrice
@onready var purchase_button = $VIPDialog/PurchaseButton
@onready var server_manager = $ServerManager
@onready var host_status_label = $TabContainer/Join/HostStatusLabel
@onready var ip_label = $TabContainer/Join/HBoxContainer/IPLabel
@onready var copy_ip_button = $TabContainer/Join/HBoxContainer/CopyIPButton
@onready var ip_edit = $TabContainer/Join/HBoxContainer/IPEdit
@onready var port_edit = $TabContainer/Join/HBoxContainer/PortSpinBox
@onready var join_status_label = $TabContainer/Join/StatusLabel

func _ready():
    _setup_directories()
    _load_player_data()
    _generate_player_id()
    _load_custom_modes()
    _setup_ui()
    _connect_signals()
    load_servers()
    setup_defaults()

#region Инициализация
func _setup_directories():
    DirAccess.make_dir_recursive_absolute(CUSTOM_MODES_DIR)

func setup_defaults():
    ip_edit.text = "127.0.0.1"
    port_edit.value = DEFAULT_PORT
    status_label.visible = false

func _generate_player_id():
    if player_data["player_id"] == "":
        randomize()
        player_data["player_id"] = "player_%d" % randi_range(100000, 999999)
        _save_player_data()

func _load_player_data():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        var saved_data = file.get_var()
        if saved_data is Dictionary:
            var old_id = player_data["player_id"]
            player_data = saved_data
            if old_id != "":
                player_data["player_id"] = old_id
        file.close()

func _save_player_data():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(player_data)
    file.close()

func _load_custom_modes():
    var dir = DirAccess.open(CUSTOM_MODES_DIR)
    if not dir:
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".gd"):
            var mode_name = file_name.get_basename()
            if not mode_name in available_modes:
                custom_modes.append(mode_name)
                available_modes.append(mode_name)
        file_name = dir.get_next()
#endregion

#region UI
func _setup_ui():
    player_name_edit.text = player_data["name"]
    _update_balance_ui()
    _update_vip_status_ui()
    _update_player_limit_label(player_limit_slider.value)
    _populate_map_options()
    _populate_mode_options()
    ip_label.visible = false
    copy_ip_button.visible = false
    vip_price_label.text = "VIP Статус (%d days): %d$" % [VIP_DAYS, VIP_PRICE]

func _update_balance_ui():
    balance_label.text = "Баланс: %d$" % player_data["balance"]
    purchase_button.disabled = player_data["balance"] < VIP_PRICE || player_data["is_vip"]

func _update_vip_status_ui():
    if player_data["is_vip"]:
        vip_button.text = "VIP Активен"
        vip_button.disabled = true
        vip_status_label.text = "VIP закончится через %d дней" % player_data["vip_days"]
        vip_status_label.modulate = Color.GREEN
    else:
        vip_button.text = "Купить VIP"
        vip_button.disabled = false
        vip_status_label.text = "Обычный Игрок"
        vip_status_label.modulate = Color.WHITE

func _update_player_limit_label(value: float):
    player_limit_label.text = "Максимум Игроков: %d" % value

func _populate_map_options():
    map_option.clear()
    for map_name in MAPS.keys():
        map_option.add_item(map_name)

func _populate_mode_options():
    mode_option.clear()
    for i in range(available_modes.size()):
        mode_option.add_item(available_modes[i])
        if available_modes[i] in custom_modes:
            mode_option.set_item_icon(i, load("res://assets/icons/icon.svg"))

func _connect_signals():
    vip_button.pressed.connect(_on_vip_button_pressed)
    purchase_button.pressed.connect(_purchase_vip)
    player_name_edit.text_submitted.connect(_change_player_name)
    player_limit_slider.value_changed.connect(_update_player_limit_label)
    copy_ip_button.pressed.connect(_on_copy_ip_button_pressed)
#endregion

#region VIP
func _on_vip_button_pressed():
    if not player_data["is_vip"]:
        vip_dialog.popup_centered()

func _purchase_vip():
    if player_data["is_vip"]:
        return
    
    if player_data["balance"] >= VIP_PRICE:
        player_data["balance"] -= VIP_PRICE
        player_data["is_vip"] = true
        player_data["vip_days"] = VIP_DAYS
        _save_player_data()
        _update_balance_ui()
        _update_vip_status_ui()
        vip_purchased.emit(player_data["player_id"])
        vip_dialog.hide()
        show_status("VIP Куплен!", Color.GREEN)
        balance_updated.emit(player_data["balance"])
#endregion

#region Игрок
func _change_player_name(new_name: String):
    new_name = new_name.strip_edges()
    if new_name.length() < 3 or new_name.length() > 16:
        show_status("Имя должно содержать 3-16 символов!", Color.RED)
        return
    
    player_data["name"] = new_name
    _save_player_data()
    player_name_changed.emit(new_name)
    show_status("Имя изменено на '%s'" % new_name, Color.GREEN)

func add_funds(amount: int):
    if amount > 0:
        player_data["balance"] += amount
        _save_player_data()
        _update_balance_ui()
        balance_updated.emit(player_data["balance"])
        show_status("+%d$! Новый баланс: %d$" % [amount, player_data["balance"]], Color.GREEN)
#endregion

#region Сервер
func _on_create_server_pressed():
    var server_name = server_name_edit.text.strip_edges()
    var selected_map = map_option.get_item_text(map_option.selected)
    var selected_mode = mode_option.get_item_text(mode_option.selected)
    
    current_server_info = {
        "name": server_name,
        "ip": "127.0.0.1",
        "port": DEFAULT_PORT,
        "map": selected_map,
        "mode": selected_mode,
        "max_players": int(player_limit_slider.value),
        "players": []
    }
    
    _create_network_server()

func _create_network_server():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()
    
    var error = multiplayer_peer.create_server(current_server_info["port"])
    
    if error == OK:
        multiplayer.multiplayer_peer = multiplayer_peer
        is_server = true
        
        var ips = _get_local_ips()
        current_server_info["ip"] = ips[0] if ips.size() > 0 else "127.0.0.1"
        
        ip_label.text = "Server IP: %s:%d" % [current_server_info["ip"], current_server_info["port"]]
        ip_label.visible = true
        copy_ip_button.visible = true
        
        show_status("Server '%s' created successfully!" % current_server_info["name"], Color.GREEN)
        _start_game()
    else:
        show_status("Failed to create server (error %d)" % error, Color.RED)

func _get_local_ips() -> Array:
    var ips = []
    for ip in IP.get_local_addresses():
        if ip.count(":") == 0 and !ip.begins_with("172.") and ip != "127.0.0.1":
            ips.append(ip)
    return ips

func _on_copy_ip_button_pressed():
    var ip_port = ip_label.text.replace("Server IP: ", "")
    DisplayServer.clipboard_set(ip_port)
    show_status("IP copied to clipboard!", Color.WHITE)
#endregion

#region Подключение к серверу
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
        btn.text = "%s:%d - %s" % [server["ip"], server["port"], server.get("name", "Unnamed")]
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
    var ip = ip_edit.text.strip_edges()
    var port = int(port_edit.value)
    
    if ip.is_valid_ip_address():
        var server_info = {
            "ip": ip,
            "port": port,
            "map": current_server_info.get("map", "Dust"),
            "mode": current_server_info.get("mode", "Deathmatch"),
            "name": current_server_info.get("name", "Custom Server"),
            "max_players": current_server_info.get("max_players", 8)
        }
        _connect_to_server(server_info)
    else:
        show_status("Invalid IP address", Color.RED)

func _connect_to_server(server: Dictionary):
    print("Connecting to server:", server)
    
    # Проверяем и приводим типы
    if not server.has("ip") or not server.has("port"):
        show_status("Invalid server data: missing ip or port", Color.RED)
        return
    
    var ip: String = str(server["ip"])
    var port: int = int(server["port"])
    
    if not ip.is_valid_ip_address():
        show_status("Invalid IP address: " + ip, Color.RED)
        return
    
    if port <= 0 or port > 65535:
        show_status("Invalid port number: " + str(port), Color.RED)
        return
    
    # Создаем подключение
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(ip, port)
    
    if error == OK:
        # Обновляем информацию о сервере
        current_server_info = {
            "ip": ip,
            "port": port,
            "map": str(server.get("map", "Dust")),
            "mode": str(server.get("mode", "Deathmatch")),
            "name": str(server.get("name", "Unnamed Server")),
            "max_players": int(server.get("max_players", 8)),
            "players": []
        }
        
        # Добавляем в историю
        if not _server_in_saved(ip, port):
            saved_servers.append(current_server_info)
            save_servers()
            update_server_list()
        
        multiplayer.multiplayer_peer = peer
        is_server = false
        show_status("Connecting to %s..." % ip, Color.WHITE)
        _start_game()
    else:
        show_status("Connection failed with error: %d" % error, Color.RED)

func _server_in_saved(ip: String, port: int) -> bool:
    for server in saved_servers:
        if str(server["ip"]) == ip and int(server["port"]) == port:
            return true
    return false

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    save_servers()
    update_server_list()

func save_servers():
    var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(saved_servers))
    file.close()

func _on_ip_edit_text_changed(new_text):
    join_status_label.visible = false
    ip_edit.modulate = Color.WHITE if new_text.is_valid_ip_address() else Color(1, 0.5, 0.5)
#endregion

#region Игра
func _start_game():
    var game_scene = load(GAME_SCENE_PATH).instantiate()
    game_scene.server_info = current_server_info
    
    var map_path = MAPS.get(current_server_info["map"], "Dust")
    if map_path == "" or not ResourceLoader.exists(map_path):
        show_status("Ошибка: карта не найдена!", Color.RED)
        return
    
    var map_scene = load(map_path).instantiate()
    game_scene.add_child(map_scene)
    
    _setup_game_mode(game_scene)
    
    get_tree().root.add_child(game_scene)
    get_tree().current_scene.queue_free()
    get_tree().current_scene = game_scene
    
    if is_server:
        game_scene.init_host(player_data)
    else:
        game_scene.init_client(player_data)

func _setup_game_mode(game_scene):
    match current_server_info["mode"]:
        "Deathmatch":
            game_scene.setup_deathmatch()
        "Team Deathmatch":
            game_scene.setup_team_deathmatch()
        "ZombieMode":
            game_scene.setup_zombie_mode()
        _:
            game_scene.setup_default_mode()

func _on_player_connected(id: int):
    print("Player connected:", id)
    current_server_info["players"].append(id)
    rpc_id(id, "receive_server_info", current_server_info)

func _on_player_disconnected(id: int):
    print("Player disconnected:", id)
    current_server_info["players"].erase(id)

@rpc("reliable")
func receive_server_info(info: Dictionary):
    current_server_info = info
    print("Received server info:", info)
#endregion

#region Утилиты
func show_status(message: String, color: Color):
    status_label.text = message
    status_label.modulate = color
    status_label.visible = true
    await get_tree().create_timer(3.0).timeout
    status_label.visible = false

func show_error(message: String):
    show_status(message, Color.RED)

func is_valid_server(server: Dictionary) -> bool:
    var required = ["ip", "port", "map", "mode", "name"]
    for key in required:
        if not key in server:
            printerr("Invalid server: missing key", key)
            return false
    return true
#endregion
