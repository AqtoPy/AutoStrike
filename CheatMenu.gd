extends PopupPanel

@onready var god_mode_check = $VBoxContainer/GodModeCheck
@onready var speed_edit = $VBoxContainer/SpeedHBox/SpeedEdit
@onready var jump_edit = $VBoxContainer/JumpHBox/JumpEdit
@onready var gravity_edit = $VBoxContainer/GravityHBox/GravityEdit
@onready var noclip_check = $VBoxContainer/NoclipCheck
@onready var wallhack_check = $VBoxContainer/WallhackCheck
@onready var aimbot_check = $VBoxContainer/AimbotHBox/AimbotCheck
@onready var aimbot_strength = $VBoxContainer/AimbotHBox/AimbotStrength
@onready var infinite_ammo_check = $VBoxContainer/InfiniteAmmoCheck

var player: CharacterBody3D
var wallhack_material = preload("res://materials/wallhack.tres")

func _ready():
    visible = false
    wallhack_material.set_shader_parameter("alpha", 0.3)

func setup(p: CharacterBody3D):
    player = p
    _load_current_values()

func _load_current_values():
    god_mode_check.button_pressed = player.god_mode
    speed_edit.value = player.walk_speed
    jump_edit.value = player.jump_velocity
    gravity_edit.value = player.gravity
    noclip_check.button_pressed = player.noclip
    wallhack_check.button_pressed = player.wallhack_enabled
    aimbot_check.button_pressed = player.aimbot_enabled
    aimbot_strength.value = player.aimbot_strength
    infinite_ammo_check.button_pressed = player.infinite_ammo

func _on_GodModeCheck_toggled(button_pressed):
    player.set_god_mode(button_pressed)

func _on_SpeedEdit_value_changed(value):
    player.set_movement_speed(value)

func _on_JumpEdit_value_changed(value):
    player.jump_velocity = value

func _on_GravityEdit_value_changed(value):
    player.gravity = value

func _on_NoclipCheck_toggled(button_pressed):
    player.set_noclip(button_pressed)

func _on_WallhackCheck_toggled(button_pressed):
    player.set_wallhack(button_pressed)

func _on_AimbotCheck_toggled(button_pressed):
    player.set_aimbot(button_pressed)

func _on_AimbotStrength_value_changed(value):
    player.aimbot_strength = value

func _on_InfiniteAmmoCheck_toggled(button_pressed):
    player.infinite_ammo = button_pressed

func _on_TeleportButton_pressed():
    player.teleport_to(player.global_transform.origin + Vector3(0, 5, 0))

func _on_CloseButton_pressed():
    hide()
