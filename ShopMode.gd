class_name CustomBattleMode
extends GameModeAPI.GameMode

## === Конфигурация режима === ##
func _init():
    name = "Покупки"
    description = "Покупки"
    team_based = true
    starting_currency = 500
    default_teams = [
        {"name": "СИНИЕ", "color": Color(0.2, 0.3, 0.8)},
        {"name": "КРАСНЫЕ", "color": Color(0.8, 0.2, 0.2)}
    ]
    
    # Специальные настройки UI в стиле изображения
    custom_ui_settings = {
        "score_display": "🔴 {score} 🔵",  # Формат счета
        "timer_display": "{minutes}/{seconds}",
        "main_color": Color(0.1, 0.1, 0.3),  # Темно-синий
        "secondary_color": Color(0.5, 0.1, 0.1),  # Темно-красный
        "text_style": {
            "font": "bold",
            "size": 22,
            "outline": true,
            "outline_color": Color(0, 0, 0, 0.7),
            "shadow": true,
            "shadow_offset": Vector2(2, 2),
            "shadow_color": Color(0.3, 0, 0.5, 0.7)
        },
        "effects_color": Color(1, 0.9, 0.3)  # Желтый для спецэффектов
    }

## === Инициализация режима === ##
func setup(api: GameModeAPI) -> void:
    super.setup(api)
    
    # Кастомные форматы счетчиков для команд
    update_score_display(api, "СИНИЕ", "СИНИЕ: {score}+")
    update_score_display(api, "КРАСНЫЕ", "КРАСНЫЕ: {score}")
    
    add_special_effect(api, "Покупки", 4.0)
    
    # Настройка магазина
    _setup_shop_items()
    
    # Персонализация UI для игроков
    for player_id in api.player_data:
        set_player_ui_element(api, player_id, "status", "Игрок")
        set_player_ui_element(api, player_id, "weapon", "Предмет")

## === Магазин предметов === ##
func _setup_shop_items():
    # VIP предмет как на изображении
    var vip_item = ShopItemData.new(
        "vip_status",
        "VIP ПАКЕТ",
        "Особые возможности на 1 матч",
        1000
    )
    vip_item.icon = "res://assets/icons/vip_star.png"
    shop_items[vip_item.id] = vip_item
    
    # Другие предметы
    var items = [
        {
            "id": "ammo_pack", 
            "name": "ПАК ПАТРОНОВ", 
            "desc": "100 патронов для вашего оружия", 
            "price": 250,
            "icon": "res://assets/icons/ammo.png"
        },
        {
            "id": "tactical_vest", 
            "name": "ТАКТИЧЕСКИЙ ЖИЛЕТ", 
            "desc": "+50% к защите", 
            "price": 750,
            "icon": "res://assets/icons/vest.png"
        },
        {
            "id": "dsr1", 
            "name": "DSR-1 ТАКТИЧЕСКАЯ", 
            "desc": "Снайперская винтовка", 
            "price": 2000,
            "icon": "res://assets/icons/sniper.png"
        }
    ]
    
    for item_data in items:
        var item = ShopItemData.new(
            item_data["id"],
            item_data["name"],
            item_data["desc"],
            item_data["price"]
        )
        item.icon = item_data["icon"]
        shop_items[item.id] = item

## === Окно магазина === ##
func create_shop_window(api: GameModeAPI) -> WindowData:
    var window = WindowData.new("tactical_shop", "ТАКТИЧЕСКИЙ МАГАЗИН", "")
    window.size = Vector2(650, 550)
    window.style = {
        "background_color": Color(0.12, 0.12, 0.25, 0.96),
        "border_color": Color(0.4, 0.2, 0.6),
        "border_width": 2,
        "text_color": Color(1, 1, 1),
        "highlight_color": Color(0.8, 0.5, 1.0),
        "title_color": Color(1, 0.8, 0.3)
    }
    
    # Формируем содержимое с предметами
    var content = ""
    for item_id in shop_items:
        var item = shop_items[item_id]
        content += "[img=%s]  [color=#FFFF00]%s[/color] - [color=#00FF00]%d$[/color]\n%s\n\n" % [
            item.icon if item.icon else "res://assets/icons/default.png",
            item.name,
            item.price,
            item.description
        ]
    
    window.content = content
    window.buttons = [
        {
            "text": "КУПИТЬ ВЫБРАННОЕ", 
            "action": "purchase_selected", 
            "args": {},
            "color": Color(0.3, 0.8, 0.3)
        },
        {
            "text": "ЗАКРЫТЬ", 
            "action": "close", 
            "args": {},
            "color": Color(0.8, 0.3, 0.3)
        }
    ]
    
    return window

## === Обработка действий === ##
func handle_window_action(api: GameModeAPI, window_id: String, action: String, args: Dictionary) -> void:
    match action:
        "purchase_selected":
            if args.has("item_id"):
                var player_id = window_id.split("_")[-1]
                if api.purchase_item(player_id, args["item_id"]):
                    api.show_info_window("УСПЕШНАЯ ПОКУПКА: " + shop_items[args["item_id"]].name, player_id)
                else:
                    api.show_info_window("НЕДОСТАТОЧНО СРЕДСТВ!", player_id)
        
        "close":
            api.close_window(window_id)
        
        "update_ui":
            # Пример изменения элемента UI
            if args.has("player_status"):
                set_player_ui_element(api, args["player_id"], "status", args["player_status"])

## === Игровые события === ##
func on_player_kill(api: GameModeAPI, killer_id: String, victim_id: String):
    # При убийстве добавляем деньги и обновляем статус
    api.add_currency_to_player(killer_id, 100)
    
    var killer_team = api.player_data[killer_id].team
    if api.teams.has(killer_team):
        api.update_team_score(killer_team, 1)
    
    # Устанавливаем кастомный статус убийцы
    set_player_ui_element(api, killer_id, "status", "Уничтожил врага! +100$")
    
    # Спецэффект при 5 убийствах подряд
    if api.player_data[killer_id].stats.get("kill_streak", 0) % 5 == 0:
        add_special_effect(api, "Покупки", 3.0)

func on_player_death(api: GameModeAPI, player_id: String):
    set_player_ui_element(api, player_id, "status", "Покупки")

## === Таймер игры === ##
var game_timer: Timer

func start_game_timer(api: GameModeAPI, duration: float):
    game_timer = Timer.new()
    api.add_child(game_timer)
    game_timer.wait_time = duration
    game_timer.timeout.connect(_on_game_timer_end.bind(api))
    game_timer.start()
    
    # Обновляем таймер каждую секунду
    var update_timer = Timer.new()
    api.add_child(update_timer)
    update_timer.wait_time = 1.0
    update_timer.timeout.connect(_update_timer_display.bind(api))
    update_timer.start()

func _update_timer_display(api: GameModeAPI):
    var time_left = int(game_timer.time_left)
    api.ui_element_updated.emit("timer", api.get_formatted_timer(time_left))

func _on_game_timer_end(api: GameModeAPI):
    api.show_info_window("ВРЕМЯ ВЫШЛО! ИГРА ЗАВЕРШЕНА.")
    game_timer.queue_free()
