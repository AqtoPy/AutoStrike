class_name TeamDeathmatchMode
extends GameModeAPI.GameMode

## Настройки режима ##
var score_to_win: int = 50
var respawn_time: float = 3.0
var team_colors: Dictionary = {
    "red": Color(0.8, 0.2, 0.2),
    "blue": Color(0.2, 0.2, 0.8)
}

func _init():
    name = "Team Deathmatch"
    description = "Командный бой до достижения лимита убийств"
    team_based = true
    default_teams = [
        {"name": "red", "color": team_colors.red},
        {"name": "blue", "color": team_colors.blue}
    ]
    scoreboard_stats = ["kills", "deaths", "score", "kd", "ping"]
    default_lives = -1 # Бесконечные жизни (используем respawn)
    allow_damage = true

## Переопределенные методы ##
func setup(api: GameModeAPI) -> void:
    super.setup(api)
    
    # Дополнительные настройки для TDM
    api.set_timer_visible(true)
    api.set_custom_stats(scoreboard_stats)
    
    # Устанавливаем кастомный текст для команд (можно менять динамически)
    for team_name in team_colors:
        api.set_team_custom_text(team_name, "0 kills")

func get_team_color(team_name: String) -> Color:
    return team_colors.get(team_name, Color.WHITE)

func get_scoreboard_data(player_stats: Dictionary) -> Dictionary:
    var data = super.get_scoreboard_data(player_stats)
    
    # Добавляем KD ratio для каждого игрока
    for player_id in data:
        var kills = player_stats[player_id].get("kills", 0)
        var deaths = player_stats[player_id].get("deaths", 1) # Чтобы избежать деления на 0
        data[player_id]["kd"] = "%.2f" % (float(kills) / float(deaths))
    
    return data

## Методы обработки событий (будут вызываться API) ##
func on_player_join(api: GameModeAPI, player_id: String) -> void:
    # Распределяем игроков по командам равномерно
    var team_count = {"red": 0, "blue": 0}
    
    for pid in api.player_data:
        var team = api.player_data[pid].team
        if team in team_count:
            team_count[team] += 1
    
    # Выбираем команду с меньшим количеством игроков
    var target_team = "red" if team_count.red <= team_count.blue else "blue"
    api.set_player_team(player_id, target_team)
    
    # Инициализируем статистику
    api.update_player_stat(player_id, "kills", 0)
    api.update_player_stat(player_id, "deaths", 0)
    api.update_player_stat(player_id, "score", 0)

func on_player_death(api: GameModeAPI, player_id: String, killer_id: String) -> void:
    if killer_id != "" and killer_id != player_id: # Не самоубийство
        # Обновляем статистику убийцы
        var killer_stats = api.player_data[killer_id].stats
        var new_kills = killer_stats.get("kills", 0) + 1
        api.update_player_stat(killer_id, "kills", new_kills)
        api.update_player_stat(killer_id, "score", new_kills * 10)
        
        # Обновляем счет команды убийцы
        var killer_team = api.player_data[killer_id].team
        if api.teams.has(killer_team):
            api.teams[killer_team].score = new_kills
            api.set_team_custom_text(killer_team, "%d kills" % new_kills)
    
    # Обновляем статистику умершего
    var deaths = api.player_data[player_id].stats.get("deaths", 0) + 1
    api.update_player_stat(player_id, "deaths", deaths)
    
    # Проверяем условия победы
    check_win_condition(api)

func on_player_respawn(api: GameModeAPI, player_id: String) -> void:
    # Можно добавить эффекты при возрождении
    pass

## Внутренние методы ##
func check_win_condition(api: GameModeAPI) -> void:
    var scores = {}
    for team_name in api.teams:
        scores[team_name] = api.teams[team_name].score
    
    # Проверяем, достиг ли кто-то лимита
    for team_name in scores:
        if scores[team_name] >= score_to_win:
            end_match(api, team_name)
            return

func end_match(api: GameModeAPI, winning_team: String) -> void:
    # Устанавливаем состояние пост-игры
    api.mode_state = 3 # POSTGAME
    
    # Можно добавить анонс победителя и другие действия
    print("Team %s wins with %d kills!" % [winning_team, api.teams[winning_team].score])
    
    # Запланировать возвращение в лобби через 10 секунд
    await api.get_tree().create_timer(10.0).timeout
    api.mode_state = 0 # LOBBY
    reset_match(api)

func reset_match(api: GameModeAPI) -> void:
    # Сбрасываем статистику для новой игры
    for team_name in api.teams:
        api.teams[team_name].score = 0
        api.set_team_custom_text(team_name, "0 kills")
    
    for player_id in api.player_data:
        api.update_player_stat(player_id, "kills", 0)
        api.update_player_stat(player_id, "deaths", 0)
        api.update_player_stat(player_id, "score", 0)
