extends Control

# ... предыдущие константы и переменные ...

# Новые элементы для вкладки Join
@onready var join_ip_input = $TabContainer/Join/HBoxContainer/IPEdit
@onready var join_port_input = $TabContainer/Join/HBoxContainer/PortSpinBox
@onready var join_server_list = $TabContainer/Join/ScrollContainer/ServerList
@onready var join_status_label = $TabContainer/Join/StatusLabel

func _ready():
    # ... существующая инициализация ...
    _setup_join_tab()
    load_servers()

func _setup_join_tab():
    join_port_input.value = SERVER_PORT
    join_ip_input.placeholder_text = "127.0.0.1"
    join_status_label.visible = false

func load_servers():
    if FileAccess.file_exists(SAVED_SERVERS_PATH):
        var file = FileAccess.open(SAVED_SERVERS_PATH, FileAccess.READ)
        saved_servers = JSON.parse_string(file.get_as_text()) or []
        file.close()
    update_server_list()

func update_server_list():
    for child in join_server_list.get_children():
        child.queue_free()
    
    for server in saved_servers:
        var hbox = HBoxContainer.new()
        
        var btn = Button.new()
        btn.text = "%s:%d" % [server["ip"], server["port"]]
        btn.pressed.connect(_connect_to_server.bind(server))
        
        var del_btn = Button.new()
        del_btn.text = "X"
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
        join_status_label.text = "Неверный IP-адрес"
        join_status_label.modulate = Color.RED
        join_status_label.visible = true

func _connect_to_server(server: Dictionary):
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(server["ip"], server["port"])
    
    if error == OK:
        # Сохраняем в историю
        if not server in saved_servers:
            saved_servers.append(server)
            FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)\
                .store_string(JSON.stringify(saved_servers))
        
        multiplayer.multiplayer_peer = peer
        _start_game()
    else:
        join_status_label.text = "Ошибка подключения (код %d)" % error
        join_status_label.modulate = Color.RED
        join_status_label.visible = true

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    FileAccess.open(SAVED_SERVERS_PATH, FileAccess.WRITE)\
        .store_string(JSON.stringify(saved_servers))
    update_server_list()

# ... остальные существующие функции ...
