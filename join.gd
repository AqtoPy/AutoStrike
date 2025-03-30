extends Control

const SAVED_SERVERS_PATH = "user://saved_servers.json"
var saved_servers = []

@onready var ip_input = $Panel/VBoxContainer/HBoxContainer/IPEdit
@onready var port_input = $Panel/VBoxContainer/HBoxContainer/PortSpinBox
@onready var server_list = $Panel/VBoxContainer/ScrollContainer/ServerList

func _ready():
    load_servers()
    update_server_list()
    # Установка значений по умолчанию
    port_input.value = 9050
    ip_input.placeholder_text = "127.0.0.1"

func load_servers():
    if FileAccess.file_exists(SAVED_SERVERS_PATH):
        var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.READ)
        var data = JSON.parse_string(file.get_as_text())
        if data is Array:
            saved_servers = data
        file.close()

func save_servers():
    var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(saved_servers))
    file.close()

func update_server_list():
    # Очищаем список
    for child in server_list.get_children():
        child.queue_free()
    
    # Добавляем серверы из истории
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
        server_list.add_child(hbox)

func _connect_to_server(server: Dictionary):
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(server["ip"], server["port"])
    
    if error == OK:
        # Добавляем в историю (если еще нет)
        if not server in saved_servers:
            saved_servers.append(server)
            save_servers()
            update_server_list()
        
        multiplayer.multiplayer_peer = peer
        status_label.text = "Успешное подключение!"
        get_tree().change_scene_to_file("res://game_scene.tscn")
    else:
        status_label.text = "Ошибка подключения (код %d)" % error
        status_label.modulate = Color.RED

func _on_connect_button_pressed():
    var ip = ip_input.text.strip_edges()
    var port = int(port_input.value)
    
    if ip.is_valid_ip_address():
        _connect_to_server({"ip": ip, "port": port})
    else:
        status_label.text = "Неверный IP-адрес"
        status_label.modulate = Color.RED

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    save_servers()
    update_server_list()

func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://main_menu.tscn")
