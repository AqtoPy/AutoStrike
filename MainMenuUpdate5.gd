extends Control

# ... [предыдущие константы и переменные] ...

# Новые переменные для магазина
var weapon_shop_data = {
    "pistol": {"price": 0, "unlocked": true},
    "rifle": {"price": 500, "unlocked": false},
    "shotgun": {"price": 700, "unlocked": false}
}

var skin_shop_data = {
    "pistol": {
        "default": {"price": 0, "unlocked": true},
        "gold": {"price": 300, "unlocked": false}
    },
    "rifle": {
        "default": {"price": 0, "unlocked": false},
        "camo": {"price": 400, "unlocked": false}
    }
}

var character_shop_data = {
    "soldier": {"price": 0, "unlocked": true},
    "ninja": {"price": 1000, "unlocked": false},
    "robot": {"price": 1500, "unlocked": false}
}

var player_level: int = 1
var player_xp: int = 0
var promo_codes = {
    "FREESKIN": {"used": false, "reward": {"type": "skin", "weapon": "pistol", "skin": "gold"}},
    "START1000": {"used": false, "reward": {"type": "currency", "amount": 1000}}
}

# Новые ноды интерфейса
@onready var promo_code_edit = $Shop/PromoCodeEdit
@onready var shop_tab = $TabContainer/Shop
@onready var weapon_shop_list = $TabContainer/Shop/WeaponShopList
@onready var skin_shop_list = $TabContainer/Shop/SkinShopList
@onready var character_shop_list = $TabContainer/Shop/CharacterShopList
@onready var level_label = $PlayerInfo/LevelLabel
@onready var xp_bar = $PlayerInfo/XPBar

func _ready():
    # ... [предыдущий код _ready] ...
    _setup_shop_ui()
    _update_level_ui()

func _setup_shop_ui():
    # Заполняем списки магазина
    for weapon in weapon_shop_data:
        var btn = Button.new()
        btn.text = "%s (%d$)" % [weapon.capitalize(), weapon_shop_data[weapon]["price"]]
        btn.disabled = weapon_shop_data[weapon]["unlocked"]
        btn.pressed.connect(_on_weapon_purchased.bind(weapon))
        weapon_shop_list.add_child(btn)
    
    for weapon in skin_shop_data:
        for skin in skin_shop_data[weapon]:
            var btn = Button.new()
            btn.text = "%s %s (%d$)" % [weapon.capitalize(), skin.capitalize(), skin_shop_data[weapon][skin]["price"]]
            btn.disabled = skin_shop_data[weapon][skin]["unlocked"]
            btn.pressed.connect(_on_skin_purchased.bind(weapon, skin))
            skin_shop_list.add_child(btn)
    
    for character in character_shop_data:
        var btn = Button.new()
        btn.text = "%s (%d$)" % [character.capitalize(), character_shop_data[character]["price"]]
        btn.disabled = character_shop_data[character]["unlocked"]
        btn.pressed.connect(_on_character_purchased.bind(character))
        character_shop_list.add_child(btn)

func _update_level_ui():
    level_label.text = "Уровень: %d" % player_level
    xp_bar.value = player_xp
    xp_bar.max_value = _get_xp_for_level(player_level + 1)

func _get_xp_for_level(level: int) -> int:
    return level * 1000  # Простая формула для XP

func _on_promo_code_submitted():
    var code = promo_code_edit.text.strip_edges().to_upper()
    if promo_codes.has(code) and not promo_codes[code]["used"]:
        promo_codes[code]["used"] = true
        var reward = promo_codes[code]["reward"]
        
        match reward["type"]:
            "currency":
                add_funds(reward["amount"])
                show_status("Промокод активирован! Получено %d$" % reward["amount"], Color.GREEN)
            "skin":
                skin_shop_data[reward["weapon"]][reward["skin"]]["unlocked"] = true
                show_status("Промокод активирован! Получен скин %s для %s" % [reward["skin"], reward["weapon"]], Color.GREEN)
        
        _save_player_data()
    else:
        show_status("Неверный или уже использованный промокод", Color.RED)

func _on_weapon_purchased(weapon: String):
    if player_data["balance"] >= weapon_shop_data[weapon]["price"]:
        player_data["balance"] -= weapon_shop_data[weapon]["price"]
        weapon_shop_data[weapon]["unlocked"] = true
        _save_player_data()
        _update_balance_ui()
        show_status("%s куплен!" % weapon.capitalize(), Color.GREEN)
    else:
        show_status("Недостаточно средств", Color.RED)

func _on_skin_purchased(weapon: String, skin: String):
    if player_data["balance"] >= skin_shop_data[weapon][skin]["price"]:
        player_data["balance"] -= skin_shop_data[weapon][skin]["price"]
        skin_shop_data[weapon][skin]["unlocked"] = true
        _save_player_data()
        _update_balance_ui()
        show_status("Скин %s для %s куплен!" % [skin.capitalize(), weapon.capitalize()], Color.GREEN)
    else:
        show_status("Недостаточно средств", Color.RED)

func _on_character_purchased(character: String):
    if player_data["balance"] >= character_shop_data[character]["price"]:
        player_data["balance"] -= character_shop_data[character]["price"]
        character_shop_data[character]["unlocked"] = true
        _save_player_data()
        _update_balance_ui()
        show_status("Персонаж %s куплен!" % character.capitalize(), Color.GREEN)
    else:
        show_status("Недостаточно средств", Color.RED)

func _save_player_data():
    var save_data = {
        "player_data": player_data,
        "weapon_shop": weapon_shop_data,
        "skin_shop": skin_shop_data,
        "character_shop": character_shop_data,
        "promo_codes": promo_codes,
        "level": player_level,
        "xp": player_xp
    }
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(save_data)
    file.close()

func _load_player_data():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        var save_data = file.get_var()
        file.close()
        
        player_data = save_data.get("player_data", player_data)
        weapon_shop_data = save_data.get("weapon_shop", weapon_shop_data)
        skin_shop_data = save_data.get("skin_shop", skin_shop_data)
        character_shop_data = save_data.get("character_shop", character_shop_data)
        promo_codes = save_data.get("promo_codes", promo_codes)
        player_level = save_data.get("level", 1)
        player_xp = save_data.get("xp", 0)
