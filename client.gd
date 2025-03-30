extends Control

const SAVED_SERVERS_PATH = "user://saved_servers.json"
var saved_servers = []

@onready var ip_input = $Panel/VBoxContainer/HBoxContainer/IPEdit
@onready var port_input = $Panel/VBoxContainer/HBoxContainer/PortSpinBox
@onready var server_list = $Panel/VBoxContainer/ScrollContainer/ServerList

func _ready():
    load_servers()
    update_server_list()

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
    
    # Добавляем серверы
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
        multiplayer.multiplayer_peer = peer
        print("Успешное подключение к серверу")
        # Здесь можно перейти к игровой сцене
    else:
        printerr("Ошибка подключения (код %d)" % error)

func _remove_server(server: Dictionary):
    saved_servers.erase(server)
    save_servers()
    update_server_list()

func _on_add_button_pressed():
    var ip = ip_input.text.strip_edges()
    var port = port_input.value
    
    if ip.is_valid_ip_address():
        var new_server = {"ip": ip, "port": int(port)}
        
        if not new_server in saved_servers:
            saved_servers.append(new_server)
            save_servers()
            update_server_list()
            ip_input.text = ""
    else:
        print("Неверный IP-адрес")

func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://main_menu.tscn")  # Вернуться в меню
