# GameModes_API.gd
class_name GameModesAPI
extends Node

## ==== Константы и перечисления ====
enum Team { RED, BLUE, SPECTATOR, ADMINS }
enum PlayerRole { DEFAULT, VIP, ADMIN, OWNER }
enum WeaponState { IDLE, FIRING, RELOADING, SWAPPING }

## ==== Классы данных ====
class PlayerData:
	var id: String
	var nickname: String
	var team: Team = Team.SPECTATOR
	var role: PlayerRole = PlayerRole.DEFAULT
	var health: int = 100
	var max_health: int = 100
	var armor: int = 0
	var kills: int = 0
	var deaths: int = 0
	var score: int = 0
	var position: Vector3
	var rotation: Vector2
	var weapons: Array = []
	var current_weapon: String = ""
	var custom_data: Dictionary = {}
	
	func _to_string() -> String:
		return "[Player %s '%s' T:%s]" % [id, nickname, Team.keys()[team]]

class WeaponData:
	var name: String
	var state: WeaponState = WeaponState.IDLE
	var ammo: int
	var max_ammo: int
	var reserve: int
	var infinite: bool = false
	
	func _init(name: String, max_ammo: int, reserve: int = 0):
		self.name = name
		self.max_ammo = max_ammo
		self.ammo = max_ammo
		self.reserve = reserve

class ZoneData:
	var name: String
	var position: Vector3
	var size: Vector3
	var color: Color
	var enabled: bool = true
	var tags: Array = []
	
	func _init(name: String, pos: Vector3, size: Vector3, color: Color, tags: Array = []):
		self.name = name
		self.position = pos
		self.size = size
		self.color = color
		self.tags = tags

## ==== Сигналы ====
signal player_connected(player_data)
signal player_disconnected(player_data)
signal player_spawned(player_data)
signal player_died(player_data, killer_data)
signal player_damaged(player_data, attacker_data, damage)
signal player_team_changed(player_data, old_team)
signal player_role_changed(player_data, old_role)
signal weapon_fired(player_data, weapon_data)
signal weapon_reloaded(player_data, weapon_data)
signal weapon_swapped(player_data, old_weapon, new_weapon)
signal round_started()
signal round_ended(winner_team)
signal game_started()
signal game_ended(winner_team)
signal chat_message(player_data, message)
signal zone_entered(player_data, zone_data)
signal zone_exited(player_data, zone_data)

## ==== Переменные API ====
var players: Dictionary = {}
var zones: Dictionary = {}
var weapons_config: Dictionary = {}
var current_mode: GameMode = null
var registered_modes: Dictionary = {}
var game_time: float = 0.0
var round_time: float = 0.0
var server_start_time: int = Time.get_unix_time_from_system()
var chat_commands: Dictionary = {}

## ==== Базовый класс режима игры ====
class GameMode:
	var name: String = "Unnamed Mode"
	var description: String = "No description"
	var author: String = "Unknown"
	var version: String = "1.0"
	var max_players: int = 16
	var round_time_limit: int = 300
	var teams: Dictionary = {
		Team.RED: "Red Team",
		Team.BLUE: "Blue Team",
		Team.ADMINS: "Admins"
	}
	
	func _init():
		pass
	
	# Виртуальные методы
	func on_register(api: GameModesAPI) -> void: pass
	func on_unregister() -> void: pass
	func on_game_start() -> void: pass
	func on_game_end(winner_team: Team) -> void: pass
	func on_round_start() -> void: pass
	func on_round_end(winner_team: Team) -> void: pass
	func on_player_connected(player: PlayerData) -> void: pass
	func on_player_disconnected(player: PlayerData) -> void: pass
	func on_player_spawn(player: PlayerData) -> void: pass
	func on_player_death(player: PlayerData, killer: PlayerData) -> void: pass
	func on_player_damage(player: PlayerData, attacker: PlayerData, damage: int) -> void: pass
	func on_player_team_change(player: PlayerData, old_team: Team) -> void: pass
	func on_weapon_fire(player: PlayerData, weapon: WeaponData) -> void: pass
	func on_weapon_reload(player: PlayerData, weapon: WeaponData) -> void: pass
	func on_chat_message(player: PlayerData, message: String) -> void: pass
	func on_chat_command(player: PlayerData, command: String, args: Array) -> void: pass
	func on_zone_enter(player: PlayerData, zone: ZoneData) -> void: pass
	func on_zone_exit(player: PlayerData, zone: ZoneData) -> void: pass

## ==== Инициализация API ====
func _ready() -> void:
	_load_weapons_config()
	_load_game_modes()
	_setup_default_commands()

func _process(delta: float) -> void:
	game_time += delta
	round_time += delta
	_check_zones()

## ==== Методы управления игрой ====
func start_game() -> void:
	game_started.emit()
	if current_mode:
		current_mode.on_game_start()

func end_game(winner_team: Team = Team.SPECTATOR) -> void:
	game_ended.emit(winner_team)
	if current_mode:
		current_mode.on_game_end(winner_team)

func start_round() -> void:
	round_time = 0.0
	round_started.emit()
	if current_mode:
		current_mode.on_round_start()

func end_round(winner_team: Team = Team.SPECTATOR) -> void:
	round_ended.emit(winner_team)
	if current_mode:
		current_mode.on_round_end(winner_team)

## ==== Методы работы с игроками ====
func add_player(player_id: String, nickname: String) -> PlayerData:
	var player = PlayerData.new()
	player.id = player_id
	player.nickname = nickname
	players[player_id] = player
	
	# Дать стандартное оружие
	_give_default_weapons(player)
	
	player_connected.emit(player)
	if current_mode:
		current_mode.on_player_connected(player)
	
	return player

func remove_player(player_id: String) -> void:
	if player_id in players:
		var player = players[player_id]
		player_disconnected.emit(player)
		if current_mode:
			current_mode.on_player_disconnected(player)
		players.erase(player_id)

func spawn_player(player_id: String, position: Vector3 = Vector3.ZERO) -> void:
	if player_id in players:
		var player = players[player_id]
		player.position = position
		player.health = player.max_health
		player_spawned.emit(player)
		if current_mode:
			current_mode.on_player_spawn(player)

## ==== Система оружия ====
func _load_weapons_config() -> void:
	# Пример конфигурации оружия (должен загружаться из JSON)
	weapons_config = {
		"pistol": {
			"max_ammo": 12,
			"reserve": 60,
			"damage": 25,
			"fire_rate": 0.5,
			"reload_time": 1.5
		},
		"rifle": {
			"max_ammo": 30,
			"reserve": 120,
			"damage": 15,
			"fire_rate": 0.1,
			"reload_time": 2.0
		},
		"knife": {
			"damage": 50,
			"range": 1.5,
			"cooldown": 1.0
		}
	}

func _give_default_weapons(player: PlayerData) -> void:
	player.weapons = [
		WeaponData.new("pistol", weapons_config["pistol"]["max_ammo"], weapons_config["pistol"]["reserve"]),
		WeaponData.new("knife", 1, 0)
	]
	player.current_weapon = "pistol"

func give_weapon(player_id: String, weapon_name: String, infinite: bool = false) -> void:
	if player_id in players and weapon_name in weapons_config:
		var player = players[player_id]
		var config = weapons_config[weapon_name]
		var weapon = WeaponData.new(weapon_name, config["max_ammo"], config.get("reserve", 0))
		weapon.infinite = infinite
		player.weapons.append(weapon)

func set_player_weapon(player_id: String, weapon_name: String) -> bool:
	if player_id in players:
		var player = players[player_id]
		for weapon in player.weapons:
			if weapon.name == weapon_name:
				var old_weapon = player.current_weapon
				player.current_weapon = weapon_name
				weapon_swapped.emit(player, old_weapon, weapon_name)
				if current_mode:
					current_mode.on_weapon_swapped(player, old_weapon, weapon_name)
				return true
	return false

## ==== Система зон ====
func create_zone(name: String, position: Vector3, size: Vector3, color: Color, tags: Array = []) -> void:
	zones[name] = ZoneData.new(name, position, size, color, tags)

func remove_zone(name: String) -> void:
	if name in zones:
		zones.erase(name)

func _check_zones() -> void:
	# Здесь должна быть реализация проверки нахождения игроков в зонах
	# Для каждого игрока проверяем пересечение с зонами
	pass

## ==== Система чата и команд ====
func register_chat_command(command: String, callback: String) -> void:
	chat_commands[command] = callback

func handle_chat_message(player_id: String, message: String) -> void:
	if player_id in players:
		var player = players[player_id]
		chat_message.emit(player, message)
		
		if current_mode:
			current_mode.on_chat_message(player, message)
		
		if message.begins_with("/"):
			var parts = message.substr(1).split(" ")
			var command = parts[0].to_lower()
			var args = parts.slice(1) if parts.size() > 1 else []
			
			if chat_commands.has(command):
				call(chat_commands[command], player, args)
			elif current_mode:
				current_mode.on_chat_command(player, command, args)

## ==== Пример реализации режима Zombie ====
class ZombieMode extends GameMode:
	var zombie_health := 150
	var zombie_speed := 1.2
	var wave := 0
	
	func _init():
		name = "Zombie Survival"
		description = "Survive against waves of zombies"
		author = "DepFeggy"
		version = "1.0"
		max_players = 24
		round_time_limit = 600
		
		teams = {
			Team.RED: "Survivors",
			Team.BLUE: "Zombies",
			Team.ADMINS: "Admins"
		}
	
	func on_player_connected(player: PlayerData) -> void:
		player.team = Team.RED
		player.health = 100
		player.max_health = 100
		
		# Дать оружие выжившим
		if player.team == Team.RED:
			give_weapon(player.id, "rifle")
			give_weapon(player.id, "pistol")
			give_weapon(player.id, "knife")
	
	func on_player_death(player: PlayerData, killer: PlayerData) -> void:
		if player.team == Team.RED:
			# Превращение в зомби
			player.team = Team.BLUE
			player.health = zombie_health
			player.custom_data["zombie"] = true
			
			# Проверить конец раунда
			var survivors = get_players_in_team(Team.RED)
			if survivors.size() == 0:
				end_round(Team.BLUE)
	
	func on_round_start() -> void:
		wave += 1
		broadcast_message("Wave %d started! Good luck!" % wave)
		
		# Усиление зомби каждые 3 волны
		if wave % 3 == 0:
			zombie_health += 20
			zombie_speed += 0.1
			broadcast_message("Zombies became stronger!")
		
		# Обновить параметры всех зомби
		for player in get_players_in_team(Team.BLUE):
			player.health = zombie_health
			player.custom_data["speed"] = zombie_speed
	
	func on_chat_command(player: PlayerData, command: String, args: Array) -> void:
		match command:
			"help":
				show_help(player)
			"admin":
				if player.role >= PlayerRole.ADMIN:
					handle_admin_command(player, args)
	
	func show_help(player: PlayerData) -> void:
		var help_text = """
		=== Zombie Survival Help ===
		/help - Show this message
		/stats - Show your stats
		"""
		send_player_message(player.id, help_text)
