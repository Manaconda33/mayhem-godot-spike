extends Node

const ROSTER_PATH := "res://shared/data/roster.json"

var roster: Array = []


func _ready() -> void:
	if not FileAccess.file_exists(ROSTER_PATH):
		push_error("Shared roster file is missing: %s" % ROSTER_PATH)
		return

	var file := FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open shared roster file: %s (error %s)" % [ROSTER_PATH, FileAccess.get_open_error()])
		return

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		push_error("Invalid shared roster JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return

	if typeof(parser.data) != TYPE_ARRAY:
		push_error("Invalid shared roster data: the JSON root must be an array.")
		return

	var parsed_roster: Array = parser.data
	for character in parsed_roster:
		if typeof(character) != TYPE_DICTIONARY:
			push_error("Invalid shared roster data: every character must be an object.")
			return
		if typeof(character.get("id")) != TYPE_STRING or typeof(character.get("name")) != TYPE_STRING or typeof(character.get("modes")) != TYPE_ARRAY:
			push_error("Invalid shared roster data: each character needs string id/name fields and an array of modes.")
			return

	roster = parsed_roster


func character_count() -> int:
	return roster.size()
