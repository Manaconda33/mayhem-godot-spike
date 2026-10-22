extends Control

@onready var roster_label: Label = %RosterLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var character_names := PackedStringArray()
	for character in App.roster:
		character_names.append(str(character.get("name", "Unknown")))
	roster_label.text = "Shared roster (%d): %s" % [App.character_count(), ", ".join(character_names)]
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shell/main.tscn")
