class_name CoinCollectorMode
extends GameModeAPI.GameMode

# Конфигурация режима
func _init():
    name = "Coin Collector"
    description = "Собирайте монеты и покупайте улучшения"
    team_based = false
    scoreboard_stats = ["coins", "kills", "deaths", "upgrades"]
    default_teams = [] # Не используем команды

# Магазин - теперь как Tab в UI
var shop_items = {
    "health": {
        "name": "Доп. здоровье",
        "cost": 50,
        "icon": "res://icons/health.png",
        "description": "+25 к максимальному здоровью"
    },
    "speed": {
        "name": "Ускорение",
        "cost": 75,
        "icon": "res://icons/speed.png",
        "description": "+10% к скорости движения"
    },
    "damage": {
        "name": "Урон",
        "cost": 100,
        "icon": "res://icons/damage.png",
        "description": "+15% к урону"
    }
}

# Инициализация режима
func setup(api: GameModeAPI) -> void:
    super.setup(api)
    
    # Настройка UI
    api.register_shop_tab("Улучшения", shop_items)
    api.connect("shop_item_purchased", _on_item_purchased)
    
    # Создаем зоны с монетами
    api.create_zone("coin_spawn_1", $Map/CoinZone1, 10)
    api.create_zone("coin_spawn_2", $Map/CoinZone2, 15)
    
    # Стартовые значения
    for player_id in api.player_data:
        api.player_data[player_id].stats = {
            "coins": 0,
            "kills": 0,
            "deaths": 0,
            "upgrades": 0,
            "health": 100,
            "speed": 1.0,
            "damage": 1.0
        }

# Обработка покупок
func _on_item_purchased(player_id: String, item_id: String):
    if not shop_items.has(item_id): return
    
    var player = api.player_data.get(player_id)
    if not player or player.stats.coins < shop_items[item_id].cost: 
        api.display_text("Недостаточно монет!", 2.0)
        return
    
    # Применяем улучшение
    match item_id:
        "health":
            player.stats.health += 25
            api.update_player_stat(player_id, "health", player.stats.health)
        "speed":
            player.stats.speed *= 1.1
        "damage":
            player.stats.damage *= 1.15
    
    player.stats.coins -= shop_items[item_id].cost
    player.stats.upgrades += 1
    api.update_player_stat(player_id, "coins", player.stats.coins)
    api.update_player_stat(player_id, "upgrades", player.stats.upgrades)
    
    api.display_text("%s купил %s!" % [player_id, shop_items[item_id].name], 3.0)

# Обновляем scoreboard
func get_scoreboard_data(player_stats: Dictionary) -> Dictionary:
    var data = {}
    for player_id in player_stats:
        data[player_id] = {
            "name": player_stats[player_id].get("name", "Player"),
            "coins": player_stats[player_id].get("coins", 0),
            "upgrades": player_stats[player_id].get("upgrades", 0),
            "kills": player_stats[player_id].get("kills", 0),
            "deaths": player_stats[player_id].get("deaths", 0)
        }
    return data
