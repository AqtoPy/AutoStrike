extends Node

# Принимаем данные сервера
var server_info: Dictionary

# Инициализация для хоста
func init_host(player_data: Dictionary):
    print("Инициализация хоста")
    # Здесь создаем карту, спавним игрока и т.д.
    spawn_player(player_data)

# Инициализация для клиента
func init_client(player_data: Dictionary):
    print("Инициализация клиента")
    spawn_player(player_data)

func spawn_player(player_data: Dictionary):
    # Здесь логика создания игрока
    print("Создаем игрока:", player_data["name"])
    
    # Пример создания игрока (замените на свою реализацию)
    var player_scene = load("res://player.tscn").instantiate()
    player_scene.player_name = player_data["name"]
    player_scene.is_vip = player_data["is_vip"]
    add_child(player_scene)

# Функции для режимов игры
func setup_deathmatch():
    print("Настройка режима Deathmatch")
    # Конфигурация для Deathmatch

func setup_team_deathmatch():
    print("Настройка режима Team Deathmatch")
    # Конфигурация для Team Deathmatch

func setup_zombie_mode():
    print("Настройка режима ZombieMode")
    # Конфигурация для ZombieMode

func setup_default_mode():
    print("Настройка стандартного режима")
