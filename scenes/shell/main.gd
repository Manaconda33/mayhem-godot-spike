extends Control

@onready var kart_button: Button = %KartButton
@onready var jam_button: Button = %JamButton
@onready var asset_test_button: Button = %AssetTestButton


func _ready() -> void:
	kart_button.pressed.connect(_on_kart_pressed)
	jam_button.pressed.connect(_on_jam_pressed)
	asset_test_button.pressed.connect(_on_asset_test_pressed)


func _on_kart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/kart/kart_core.tscn")


func _on_jam_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/jam/jam_core.tscn")


func _on_asset_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/jam/asset_test.tscn")
