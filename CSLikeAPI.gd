# GameModes_API.gd - Расширенный API для создания пользовательских игровых режимов
extends Node

#region Константы и перечисления
enum GameState {
    LOBBY,
    PRE_GAME,
    IN_PROGRESS,
    POST_GAME,
    PAUSED
}

enum Team {
    NONE,
    T,  # Террористы
    CT, # Контр-террористы
    SPECTATOR
}

enum PlayerConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    READY
}

enum DamageType {
    BULLET,
    EXPLOSION,
    FALL,
    FIRE,
    MELEE,
    ENVIRONMENT
}

enum WeaponType {
    PISTOL,
    RIFLE,
    SMG,
    SNIPER,
    SHOTGUN,
    GRENADE,
    KNIFE
}

const DEFAULT_TEAM_COLORS = {
    Team.T: Color(0.8, 0.4, 0.0),  # Оранжевый
    Team.CT: Color(0.0, 0.4, 0.8),  # Синий
    Team.SPECTATOR: Color(0.5, 0.5, 0.5)
}

const DEFAULT_RESPAWN_TIME = 5.0
const DEFAULT_ROUND_TIME = 120  # 2 минуты на раунд
const DEFAULT_BUY_TIME = 30     # 30 секунд на покупку
const DEFAULT_MAP_SIZE = Vector3(2000, 500, 2000)  # Размер карты в юнитах
#endregion

#region Сигналы
signal game_state_changed(new_state)
signal player_joined(player_id, player_data)
signal player_left(player_id)
signal player_team_changed(player_id, new_team, old_team)
signal player_spawned(player_id, position)
signal player_died(player_id, killer_id, damage_type, is_headshot)
signal player_respawn_timer_started(player_id, respawn_time)
signal player_respawned(player_id)
signal player_score_changed(player_id, new_score, delta)
signal player_kills_changed(player_id, new_kills)
signal player_deaths_changed(player_id, new_deaths)
signal team_score_changed(team, new_score, delta)
signal match_time_updated(time_remaining)
signal round_started(round_number)
signal round_ended(round_number, winning_team)
signal match_ended(winning_team)
signal chat_message_received(player_id, message, is_team_chat)
signal player_weapon_changed(player_id, weapon_type, weapon_name)
signal player_health_changed(player_id, new_health, old_health)
signal player_ammo_changed(player_id, weapon_type, new_ammo, old_ammo)
signal player_armor_changed(player_id, new_armor)
signal player_money_changed(player_id, new_money)
signal player_bought_item(player_id, item_type, item_name, cost)
signal player_planted_bomb(player_id, position)
signal player_defused_bomb(player_id)
signal bomb_exploded(position)
signal bomb_planted(position)
signal bomb_defused(position)
signal round_buy_time_started(time_left)
signal round_buy_time_ended
signal player_dropped_weapon(player_id, weapon_type, position)
signal player_picked_up_weapon(player_id, weapon_type)
signal player_reloaded(player_id, weapon_type)
signal player_used_grenade(player_id, grenade_type, position)
signal player_flashed(player_id, attacker_id, duration)
signal player_smoked(player_id, position)
signal player_burned(player_id, position)
signal player_connected(player_id)
signal player_disconnected(player_id)
signal player_ready_state_changed(player_id, is_ready)
signal player_vip_state_changed(player_id, is_vip)
signal player_ping_changed(player_id, new_ping)
signal player_admin_state_changed(player_id, is_admin)
signal player_rank_changed(player_id, new_rank)
signal player_level_changed(player_id, new_level)
signal player_xp_changed(player_id, new_xp, delta)
signal player_killstreak_changed(player_id, killstreak)
signal player_round_kills_changed(player_id, kills)
signal player_round_damage_changed(player_id, damage)
signal player_round_assists_changed(player_id, assists)
signal player_round_headshots_changed(player_id, headshots)
signal player_round_mvp_changed(player_id, is_mvp)
#endregion

#region Публичные переменные
var current_game_state = GameState.LOBBY setget _set_game_state
var match_duration = 1800.0  # 30 минут по умолчанию
var round_time = DEFAULT_ROUND_TIME
var buy_time = DEFAULT_BUY_TIME
var current_round = 0
var time_remaining = 0.0
var buy_time_remaining = 0.0
var winning_team = Team.NONE
var is_ranked = false
var is_private = false
var match_id = ""
var map_name = ""
var map_size = DEFAULT_MAP_SIZE
var game_version = "1.0"
var max_players = 16
var min_players_to_start = 2
var allow_team_switching = true
var friendly_fire = false
var respawn_enabled = false  # В CS-подобных режимах респаун обычно отключен
var score_to_win = 16        # Матч до 16 раундов
var kill_reward = 300        # Деньги за убийство
var headshot_bonus = 100     # Бонус за хедшот
var bomb_defuse_reward = 300 # Награда за разминирование
var bomb_plant_reward = 300  # Награда за установку бомбы
var round_win_reward = 3250  # Награда за выигранный раунд
var round_lose_reward = 1400 # Награда за проигранный раунд
var starting_money = 800     # Стартовые деньги
var vip_starting_money = 1200 # Стартовые деньги для VIP
var max_money = 16000        # Максимум денег
var bomb_plant_time = 3.0    # Время установки бомбы
var bomb_defuse_time = 5.0   # Время разминирования бомбы
var bomb_explode_time = 45.0 # Время до взрыва бомбы
var bomb_site_a = Vector3.ZERO # Позиция точки A
var bomb_site_b = Vector3.ZERO # Позиция точки B
var is_bomb_planted = false
var bomb_position = Vector3.ZERO
var bomb_defuser = -1
var bomb_planter = -1
var ct_spawns = []
var t_spawns = []
var weapon_spawns = []
var buy_zones = []
#endregion

#region Приватные переменные
var _players = {}
var _teams = {}
var _player_scores = {}
var _player_kills = {}
var _player_deaths = {}
var _player_money = {}
var _player_armor = {}
var _player_killstreaks = {}
var _player_round_stats = {}
var _player_ranks = {}
var _player_levels = {}
var _player_xp = {}
var _player_vip_status = {}
var _player_admin_status = {}
var _player_loadouts = {}
var _player_weapons = {}
var _player_ready_status = {}
var _game_timer = Timer.new()
var _round_timer = Timer.new()
var _buy_timer = Timer.new()
var _bomb_timer = Timer.new()
var _spawn_points = {Team.T: [], Team.CT: []}
var _weapons_on_ground = {}
var _match_history = []
var _chat_history = []
var _initialized = false
#endregion

#region Основные функции
func _ready():
    _initialize_api()

func _initialize_api():
    if _initialized:
        return
    
    # Инициализация таймеров
    add_child(_game_timer)
    _game_timer.connect("timeout", self, "_on_game_timer_timeout")
    
    add_child(_round_timer)
    _round_timer.connect("timeout", self, "_on_round_timer_timeout")
    
    add_child(_buy_timer)
    _buy_timer.connect("timeout", self, "_on_buy_timer_timeout")
    
    add_child(_bomb_timer)
    _bomb_timer.connect("timeout", self, "_on_bomb_timer_timeout")
    
    # Инициализация команд
    _initialize_teams()
    
    # Генерация ID матча
    match_id = _generate_match_id()
    
    _initialized = true

func _initialize_teams():
    _teams.clear()
    _teams[Team.T] = []
    _teams[Team.CT] = []
    _team_scores = {Team.T: 0, Team.CT: 0}

func _generate_match_id():
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var id = ""
    for i in range(8):
        id += chars[randi() % chars.length()]
    return id

func start_match():
    if current_game_state != GameState.LOBBY:
        return
    
    if _players.size() < min_players_to_start:
        print("Недостаточно игроков для начала матча")
        return
    
    current_round = 1
    _start_round()

func _start_round():
    self.current_game_state = GameState.PRE_GAME
    
    # Сброс таймеров и состояний
    _round_timer.start(round_time)
    time_remaining = round_time
    
    # Старт времени покупок
    _buy_timer.start(buy_time)
    buy_time_remaining = buy_time
    
    # Оповещение о начале раунда
    emit_signal("round_started", current_round)
    emit_signal("round_buy_time_started", buy_time)
    
    # Выдача стартовых денег
    _give_starting_money()
    
    # Спавн игроков
    for player_id in _players:
        spawn_player(player_id)
    
    # Старт основного таймера игры
    _game_timer.start(1.0)
    
    self.current_game_state = GameState.IN_PROGRESS

func _give_starting_money():
    for player_id in _players:
        var is_vip = _player_vip_status.get(player_id, false)
        var base_money = vip_starting_money if is_vip else starting_money
        
        # Дополнительные бонусы за победы/поражения
        if current_round > 1:
            var player_team = _players[player_id]["team"]
            if _team_scores[player_team] > _team_scores[_get_enemy_team(player_team)]:
                base_money += round_win_reward
            else:
                base_money += round_lose_reward
        
        _player_money[player_id] = min(base_money, max_money)
        emit_signal("player_money_changed", player_id, _player_money[player_id])

func end_round(winning_team = Team.NONE):
    if current_game_state != GameState.IN_PROGRESS:
        return
    
    _round_timer.stop()
    _buy_timer.stop()
    self.current_game_state = GameState.POST_GAME
    
    # Оповещение о конце раунда
    emit_signal("round_ended", current_round, winning_team)
    
    # Обновление счета команды
    if winning_team != Team.NONE:
        _team_scores[winning_team] += 1
        emit_signal("team_score_changed", winning_team, _team_scores[winning_team], 1)
    
    # Сброс бомбы
    if is_bomb_planted:
        _reset_bomb()
    
    # Проверка на конец матча
    for team in _team_scores:
        if _team_scores[team] >= score_to_win:
            end_match(team)
            return
    
    # Переход к следующему раунду через 10 секунд
    yield(get_tree().create_timer(10.0), "timeout")
    current_round += 1
    _start_round()

func end_match(winning_team = Team.NONE):
    _game_timer.stop()
    _round_timer.stop()
    _buy_timer.stop()
    self.current_game_state = GameState.POST_GAME
    
    # Оповещение о конце матча
    emit_signal("match_ended", winning_team)
    
    # Начисление XP и обновление ранков
    _calculate_match_rewards(winning_team)
    
    # Запись в историю матчей
    var match_result = {
        "match_id": match_id,
        "timestamp": OS.get_unix_time(),
        "duration": match_duration - time_remaining,
        "winning_team": winning_team,
        "player_count": _players.size(),
        "scores": _team_scores.duplicate(),
        "mvp": _get_mvp_player()
    }
    _match_history.append(match_result)
    
    # Возврат в лобби через 30 секунд
    yield(get_tree().create_timer(30.0), "timeout"
    reset_match()

func _calculate_match_rewards(winning_team):
    for player_id in _players:
        var player_team = _players[player_id]["team"]
        var is_winner = player_team == winning_team
        
        # Базовый XP за матч
        var xp_gain = 100
        
        # Бонус за победу
        if is_winner:
            xp_gain += 50
        
        # Бонус за MVP
        if player_id == _get_mvp_player():
            xp_gain += 50
        
        # Бонус за киллы
        xp_gain += _player_kills.get(player_id, 0) * 10
        
        # Добавление XP
        add_player_xp(player_id, xp_gain)
        
        # Обновление ранка (если нужно)
        _update_player_rank(player_id)

func _get_mvp_player():
    var mvp_id = -1
    var max_kills = 0
    
    for player_id in _player_kills:
        if _player_kills[player_id] > max_kills:
            max_kills = _player_kills[player_id]
            mvp_id = player_id
    
    return mvp_id

func _update_player_rank(player_id):
    if player_id in _player_xp and player_id in _player_levels:
        var current_level = _player_levels[player_id]
        var xp_needed = _get_xp_for_level(current_level + 1)
        
        if _player_xp[player_id] >= xp_needed:
            _player_levels[player_id] = current_level + 1
            emit_signal("player_level_changed", player_id, current_level + 1)
            
            # Каждые 5 уровней повышаем ранг
            if current_level % 5 == 0:
                var new_rank = _player_ranks.get(player_id, 0) + 1
                _player_ranks[player_id] = new_rank
                emit_signal("player_rank_changed", player_id, new_rank)

func _get_xp_for_level(level):
    return pow(level, 2) * 100

func reset_match():
    self.current_game_state = GameState.LOBBY
    
    # Сброс игроков
    for player_id in _players:
        _players[player_id]["team"] = Team.NONE
        emit_signal("player_team_changed", player_id, Team.NONE, _players[player_id]["team"])
    
    # Сброс счетов
    _player_scores.clear()
    _player_kills.clear()
    _player_deaths.clear()
    _player_round_stats.clear()
    _team_scores = {Team.T: 0, Team.CT: 0}
    
    # Сброс таймеров
    time_remaining = match_duration
    
    # Генерация нового ID матча
    match_id = _generate_match_id()

func _on_game_timer_timeout():
    time_remaining -= 1.0
    emit_signal("match_time_updated", time_remaining)
    
    if time_remaining <= 0:
        end_round()

func _on_round_timer_timeout():
    # Время раунда вышло
    if is_bomb_planted:
        # Если бомба установлена, побеждают террористы
        end_round(Team.T)
    else:
        # Иначе побеждают контр-террористы
        end_round(Team.CT)

func _on_buy_timer_timeout():
    buy_time_remaining -= 1.0
    emit_signal("round_buy_time_started", buy_time_remaining)
    
    if buy_time_remaining <= 0:
        emit_signal("round_buy_time_ended")
        _buy_timer.stop()

func _on_bomb_timer_timeout():
    if is_bomb_planted:
        # Взрыв бомбы
        bomb_explode()
    else:
        # Бомба разминирована
        bomb_defuse_success()
#endregion

#region Управление игроками
func register_player(player_id, player_data = {}):
    if player_id in _players:
        return false
    
    _players[player_id] = {
        "name": player_data.get("name", "Player_" + str(player_id)),
        "team": Team.NONE,
        "is_ready": false,
        "is_alive": false,
        "health": 100,
        "max_health": 100,
        "armor": 0,
        "has_helmet": false,
        "position": Vector3.ZERO,
        "rotation": Vector3.ZERO,
        "connection_state": PlayerConnectionState.CONNECTED,
        "ping": 0,
        "is_vip": player_data.get("is_vip", false),
        "is_admin": player_data.get("is_admin", false),
        "custom_data": {}
    }
    
    _player_scores[player_id] = 0
    _player_kills[player_id] = 0
    _player_deaths[player_id] = 0
    _player_money[player_id] = starting_money
    _player_armor[player_id] = 0
    _player_killstreaks[player_id] = 0
    _player_round_stats[player_id] = {
        "kills": 0,
        "damage": 0,
        "assists": 0,
        "headshots": 0
    }
    _player_ranks[player_id] = 0
    _player_levels[player_id] = 1
    _player_xp[player_id] = 0
    _player_vip_status[player_id] = _players[player_id]["is_vip"]
    _player_admin_status[player_id] = _players[player_id]["is_admin"]
    _player_ready_status[player_id] = false
    
    # Стандартный набор оружия
    _player_weapons[player_id] = {
        "primary": null,
        "secondary": null,
        "knife": "knife",
        "grenades": [],
        "bomb": false
    }
    
    emit_signal("player_joined", player_id, _players[player_id])
    emit_signal("player_connected", player_id)
    emit_signal("player_score_changed", player_id, 0, 0)
    emit_signal("player_kills_changed", player_id, 0)
    emit_signal("player_deaths_changed", player_id, 0)
    emit_signal("player_money_changed", player_id, _player_money[player_id])
    emit_signal("player_armor_changed", player_id, 0)
    emit_signal("player_vip_state_changed", player_id, _players[player_id]["is_vip"])
    emit_signal("player_admin_state_changed", player_id, _players[player_id]["is_admin"])
    emit_signal("player_rank_changed", player_id, 0)
    emit_signal("player_level_changed", player_id, 1)
    emit_signal("player_xp_changed", player_id, 0, 0)
    
    return true

func unregister_player(player_id):
    if player_id not in _players:
        return
    
    var player_data = _players[player_id]
    var team = player_data["team"]
    
    if team != Team.NONE and team in _teams:
        _teams[team].erase(player_id)
    
    _players.erase(player_id)
    _player_scores.erase(player_id)
    _player_kills.erase(player_id)
    _player_deaths.erase(player_id)
    _player_money.erase(player_id)
    _player_armor.erase(player_id)
    _player_killstreaks.erase(player_id)
    _player_round_stats.erase(player_id)
    _player_ranks.erase(player_id)
    _player_levels.erase(player_id)
    _player_xp.erase(player_id)
    _player_vip_status.erase(player_id)
    _player_admin_status.erase(player_id)
    _player_ready_status.erase(player_id)
    _player_weapons.erase(player_id)
    
    emit_signal("player_left", player_id)
    emit_signal("player_disconnected", player_id)

func set_player_team(player_id, new_team):
    if player_id not in _players:
        return false
    
    var player_data = _players[player_id]
    var old_team = player_data["team"]
    
    if old_team == new_team:
        return false
    
    # Удаление из старой команды
    if old_team != Team.NONE and old_team in _teams:
        _teams[old_team].erase(player_id)
    
    # Добавление в новую команду
    if new_team != Team.NONE:
        if new_team in _teams:
            # Балансировка команд
            if _teams[new_team].size() - _teams[_get_enemy_team(new_team)].size() >= 2:
                return false
                
            _teams[new_team].append(player_id)
        else:
            return false
    
    player_data["team"] = new_team
    emit_signal("player_team_changed", player_id, new_team, old_team)
    
    return true

func _get_enemy_team(team):
    return Team.CT if team == Team.T else Team.T

func spawn_player(player_id):
    if player_id not in _players:
        return false
    
    var player_data = _players[player_id]
    
    if player_data["is_alive"]:
        return false
    
    if player_data["team"] == Team.NONE or player_data["team"] == Team.SPECTATOR:
        return false
    
    # Получение позиции спавна
    var spawn_position = _get_spawn_position(player_data["team"])
    player_data["position"] = spawn_position
    player_data["rotation"] = Vector3.ZERO
    
    # Сброс здоровья и брони
    player_data["health"] = player_data["max_health"]
    player_data["is_alive"] = true
    
    # Выдача стандартного оружия
    _give_default_weapons(player_id)
    
    emit_signal("player_spawned", player_id, spawn_position)
    emit_signal("player_health_changed", player_id, player_data["health"], player_data["max_health"])
    
    return true

func _give_default_weapons(player_id):
    if player_id not in _player_weapons:
        return
    
    var team = _players[player_id]["team"]
    var weapons = _player_weapons[player_id]
    
    # Очистка текущего оружия
    weapons["primary"] = null
    weapons["secondary"] = null
    weapons["grenades"] = []
    weapons["bomb"] = false
    
    # Выдача стандартн��го оружия в зависимости от команды
    if team == Team.T:
        weapons["secondary"] = "glock"
        # Случайный террорист получает бомбу
        if _teams[Team.T].size() > 0 and player_id == _teams[Team.T][randi() % _teams[Team.T].size()]:
            weapons["bomb"] = true
            emit_signal("player_weapon_changed", player_id, WeaponType.GRENADE, "c4")
    else:
        weapons["secondary"] = "usp"
    
    # Оповещение об изменении оружия
    emit_signal("player_weapon_changed", player_id, WeaponType.PISTOL, weapons["secondary"])
    emit_signal("player_weapon_changed", player_id, WeaponType.KNIFE, weapons["knife"])

func kill_player(player_id, killer_id = -1, damage_type = DamageType.BULLET, is_headshot = false):
    if player_id not in _players:
        return false
    
    var player_data = _players[player_id]
    
    if not player_data["is_alive"]:
        return false
    
    player_data["is_alive"] = false
    player_data["deaths"] += 1
    _player_deaths[player_id] = player_data["deaths"]
    
    # Обновление статистики раунда
    _player_round_stats[player_id]["deaths"] += 1
    
    # Обновление киллстрика
    _player_killstreaks[player_id] = 0
    emit_signal("player_killstreak_ch
