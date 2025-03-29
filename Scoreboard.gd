extends CanvasLayer

# Настройки стилей
var team_panel_style = {
    "default": StyleBoxFlat.new(),
    "red": StyleBoxFlat.new(),
    "blue": StyleBoxFlat.new(),
    "green": StyleBoxFlat.new(),
    "yellow": StyleBoxFlat.new(),
    "spectator": StyleBoxFlat.new()
}

@onready var teams_container = $ScoreboardPanel/MarginContainer/ScrollContainer/TeamsContainer

func _ready():
    _setup_styles()
    hide_scoreboard()

func _setup_styles():
    # Базовый стиль
    var default_style = team_panel_style["default"]
    default_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
    default_style.border_color = Color(0.3, 0.3, 0.3)
    default_style.border_width_all = 2
    default_style.corner_radius_top_left = 8
    default_style.corner_radius_top_right = 8
    
    # Стили для команд (цвета можно менять в режимах)
    team_panel_style["red"].bg_color = Color(0.4, 0.1, 0.1, 0.9)
    team_panel_style["blue"].bg_color = Color(0.1, 0.1, 0.4, 0.9)
    team_panel_style["green"].bg_color = Color(0.1, 0.4, 0.1, 0.9)
    team_panel_style["yellow"].bg_color = Color(0.4, 0.4, 0.1, 0.9)
    team_panel_style["spectator"].bg_color = Color(0.2, 0.2, 0.2, 0.9)
    
    for style in team_panel_style.values():
        style.border_color = Color(0.5, 0.5, 0.5)
        style.border_width_all = 1
        style.corner_radius_top_left = 8
        style.corner_radius_top_right = 8

func update_scoreboard(teams_data: Dictionary, player_stats: Dictionary):
    # Очищаем предыдущие данные
    for child in teams_container.get_children():
        child.queue_free()
    
    # Создаем панели для каждой команды
    for team_name in teams_data:
        var team = teams_data[team_name]
        var team_panel = _create_team_panel(team_name, team)
        teams_container.add_child(team_panel)
        
        # Добавляем игроков
        for player_id in team["players"]:
            if player_stats.has(player_id):
                var player_row = _create_player_row(player_stats[player_id])
                team_panel.get_node("PlayersContainer").add_child(player_row)
    
    show_scoreboard()

func _create_team_panel(team_name: String, team_data: Dictionary) -> Control:
    var panel = PanelContainer.new()
    panel.name = team_name.capitalize()
    
    # Применяем стиль команды
    var style = team_panel_style.get(team_name, team_panel_style["default"])
    panel.add_theme_stylebox_override("panel", style)
    
    var vbox = VBoxContainer.new()
    vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(vbox)
    
    # Заголовок команды
    var header = HBoxContainer.new()
    var team_label = Label.new()
    team_label.text = team_name.capitalize() + " Team"
    team_label.add_theme_font_size_override("font_size", 18)
    team_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    var score_label = Label.new()
    score_label.text = "Score: %d" % team_data.get("score", 0)
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    
    header.add_child(team_label)
    header.add_child(score_label)
    vbox.add_child(header)
    
    # Разделитель
    var separator = HSeparator.new()
    vbox.add_child(separator)
    
    # Контейнер для игроков
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size.y = 200
    var players_container = VBoxContainer.new()
    players_container.name = "PlayersContainer"
    scroll.add_child(players_container)
    vbox.add_child(scroll)
    
    return panel

func _create_player_row(player_data: Dictionary) -> Control:
    var row = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    # Иконка VIP
    if player_data.get("is_vip", false):
        var vip_icon = TextureRect.new()
        vip_icon.texture = preload("res://assets/icons/vip.png")
        vip_icon.custom_minimum_size = Vector2(20, 20)
        vip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(vip_icon)
    
    # Имя игрока
    var name_label = Label.new()
    name_label.text = player_data.get("name", "Unknown")
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_label)
    
    # Статистика
    var stats = [
        str(player_data.get("kills", 0)),
        str(player_data.get("deaths", 0)),
        str(player_data.get("score", 0)),
        str(player_data.get("ping", 0)) + "ms"
    ]
    
    for stat in stats:
        var stat_label = Label.new()
        stat_label.text = stat
        stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        stat_label.custom_minimum_size.x = 60
        row.add_child(stat_label)
    
    # Подсветка текущего игрока
    if player_data.get("is_local", false):
        row.modulate = Color(1.2, 1.2, 1.2)
    
    return row

func show_scoreboard():
    $ScoreboardPanel.visible = true
    $AnimationPlayer.play("fade_in")

func hide_scoreboard():
    $AnimationPlayer.play_backwards("fade_in")
    await $AnimationPlayer.animation_finished
    $ScoreboardPanel.visible = false
