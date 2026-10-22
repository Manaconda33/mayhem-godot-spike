extends Control

@onready var kart_button: Button = %KartButton
@onready var jam_button: Button = %JamButton


func _ready() -> void:
	kart_button.pressed.connect(_on_kart_pressed)
	jam_button.pressed.connect(_on_jam_pressed)


func _on_kart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/kart/kart_stub.tscn")


func _on_jam_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/jam/jam_stub.tscn")
