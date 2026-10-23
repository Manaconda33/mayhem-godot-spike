extends Control
class_name JamAssetImportTest

const ASSET_ROOT := "res://assets/jam/manaconda/"
const LAYOUT_ROOT := ASSET_ROOT + "layouts/"
const PREVIEW_SCALE := 4.0
const FRAME_HEIGHT := 96.0
const PREVIEW_FPS := 8.0
const CLIP_ORDER: Array[String] = [
	"idle", "idle-ball", "dribble", "run", "dribble-run",
	"shoot", "pass", "pass-overhead", "pass-behind", "receive", "pickup",
	"layup", "layup-reverse", "block", "steal", "push", "rebound", "fall", "celebrate",
	"dunk-power", "dunk-windmill", "dunk-reverse", "dunk-360", "dunk-tomahawk",
	"dunk-double", "dunk-clutch", "dunk-scythe", "alley-oop-power", "alley-oop-reverse"
]
const LAYOUT_FILES: Array[String] = [
	"manaconda-layouts.json",
	"manaconda-shoot10-layouts.json",
	"manaconda-dunk-36015-layouts.json",
	"manaconda-dunk-clutch15-layouts.json",
	"manaconda-dunk-double15-layouts.json",
	"manaconda-dunk-power15-layouts.json",
	"manaconda-dunk-reverse15-layouts.json",
	"manaconda-dunk-scythe15-layouts.json",
	"manaconda-dunk-tomahawk15-layouts.json",
	"manaconda-dunk-windmill15-layouts.json",
	"manaconda-alley-oop-power15-layouts.json",
	"manaconda-alley-oop-reverse15-layouts.json",
	"manaconda-layups16-layout-layouts.json",
	"manaconda-pass6-layouts.json",
	"manaconda-passes12-layout-layouts.json",
	"manaconda-block-steal12-layout-layouts.json",
	"manaconda-catch-pickup9-layouts.json",
	"manaconda-push-rebound16-layout-layouts.json",
	"manaconda-recovery20-layout-layouts.json",
]

var _sprite: AnimatedSprite2D
var _sprite_pivot: Node2D
var _preview_stage: Control
var _ground_line: ColorRect
var _clip_title: Label
var _frame_count_label: Label
var _play_button: Button
var _frame_status: Label
var _clip_entries: Dictionary = {}
var _ground_baseline := 0.0
var _sprite_foot_y := FRAME_HEIGHT


func _ready() -> void:
	var sprite_frames := _build_sprite_frames()
	if sprite_frames == null:
		return
	_build_ui(sprite_frames)
	_select_clip("idle")


func _process(_delta: float) -> void:
	if _sprite == null or _frame_status == null:
		return
	var count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	_frame_status.text = "Frame %d / %d" % [_sprite.frame + 1, count]


func _build_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	for layout_file in LAYOUT_FILES:
		var full_path := LAYOUT_ROOT + layout_file
		if not FileAccess.file_exists(full_path):
			push_error("Missing Manaconda layout file: %s" % full_path)
			return null
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full_path))
		if parsed == null:
			push_error("Invalid JSON in Manaconda layout file: %s" % full_path)
			return null
		var layouts: Array = parsed if parsed is Array else [parsed]
		for layout: Dictionary in layouts:
			if layout.get("athlete", "") != "manaconda" or layout.get("direction", "") != "right":
				continue
			var clip_name: String = layout.get("clip", "")
			if clip_name.is_empty() or _clip_entries.has(clip_name):
				push_error("Missing or duplicate Manaconda clip in layout: %s" % full_path)
				return null
			var sheet_path := ASSET_ROOT + String(layout["src"]).get_file()
			var sheet := load(sheet_path) as Texture2D
			if sheet == null:
				push_error("Unable to import Manaconda sheet: %s" % sheet_path)
				return null
			sprite_frames.add_animation(clip_name)
			sprite_frames.set_animation_speed(clip_name, PREVIEW_FPS)
			sprite_frames.set_animation_loop(clip_name, true)
			for frame: Dictionary in layout.get("frames", []):
				var atlas_frame := AtlasTexture.new()
				atlas_frame.atlas = sheet
				atlas_frame.region = Rect2(
					float(frame["x"]), float(frame["y"]),
					float(frame["w"]), float(frame["h"])
				)
				atlas_frame.filter_clip = true
				sprite_frames.add_frame(clip_name, atlas_frame)
			_clip_entries[clip_name] = layout
	for clip_name in CLIP_ORDER:
		if not _clip_entries.has(clip_name):
			push_error("No Manaconda layout loaded for clip: %s" % clip_name)
			return null
	if _clip_entries.size() != CLIP_ORDER.size():
		push_error("Expected %d registered clips, loaded %d" % [CLIP_ORDER.size(), _clip_entries.size()])
		return null
	return sprite_frames


func _build_ui(sprite_frames: SpriteFrames) -> void:
	var background := ColorRect.new()
	background.color = Color("101522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	page.add_child(header)
	var heading := _label("MANACONDA — SPRITE IMPORT TEST", 28)
	header.add_child(heading)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var back_button := _button("BACK TO HUB", Vector2(172, 52), 18)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/shell/main.tscn"))
	header.add_child(back_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 264
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color("1a2233")))
	content.add_child(sidebar)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var clip_list := VBoxContainer.new()
	clip_list.add_theme_constant_override("separation", 5)
	scroll.add_child(clip_list)
	for clip_name in CLIP_ORDER:
		var clip_button := _button(clip_name, Vector2(230, 38), 16)
		clip_button.pressed.connect(_select_clip.bind(clip_name))
		clip_list.add_child(clip_button)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color("1a2233")))
	content.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 10)
	preview_panel.add_child(preview_column)

	var clip_info := HBoxContainer.new()
	preview_column.add_child(clip_info)
	_clip_title = _label("", 28)
	clip_info.add_child(_clip_title)
	var info_spacer := Control.new()
	info_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_info.add_child(info_spacer)
	_frame_count_label = _label("", 18)
	clip_info.add_child(_frame_count_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	preview_column.add_child(controls)
	_play_button = _button("PAUSE", Vector2(136, 48), 18)
	_play_button.pressed.connect(_toggle_playback)
	controls.add_child(_play_button)
	var flip_button := _button("FLIP", Vector2(112, 48), 18)
	flip_button.toggle_mode = true
	flip_button.toggled.connect(_on_flip_toggled)
	controls.add_child(flip_button)
	_frame_status = _label("Frame 1 / 1", 18)
	controls.add_child(_frame_status)
	var facing_hint := _label("Right-facing source  ·  FLIP mirrors left", 15)
	facing_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facing_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(facing_hint)

	_preview_stage = Control.new()
	_preview_stage.name = "PreviewStage"
	_preview_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_stage.custom_minimum_size.y = 360
	preview_column.add_child(_preview_stage)
	var stage_background := ColorRect.new()
	stage_background.color = Color("0c111c")
	stage_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_stage.add_child(stage_background)
	_ground_line = ColorRect.new()
	_ground_line.color = Color("d3bd83")
	_ground_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_stage.add_child(_ground_line)
	_sprite_pivot = Node2D.new()
	_sprite_pivot.name = "SpritePivot"
	_sprite_pivot.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview_stage.add_child(_sprite_pivot)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ManacondaSprite"
	_sprite.sprite_frames = sprite_frames
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	_sprite_pivot.add_child(_sprite)
	_preview_stage.resized.connect(_layout_preview)
	_layout_preview()


func _layout_preview() -> void:
	if _preview_stage == null or _sprite_pivot == null or _ground_line == null:
		return
	_ground_baseline = floorf(_preview_stage.size.y * 0.82)
	_ground_line.position = Vector2(20, _ground_baseline)
	_ground_line.size = Vector2(maxf(0.0, _preview_stage.size.x - 40), 2)
	_position_sprite_pivot()


func _select_clip(clip_name: String) -> void:
	if _sprite == null or not _clip_entries.has(clip_name):
		return
	_sprite.animation = clip_name
	_sprite.frame = 0
	_sprite.play()
	_play_button.text = "PAUSE"
	_clip_title.text = clip_name.replace("-", " ").capitalize()
	_frame_count_label.text = "%d FRAMES" % _sprite.sprite_frames.get_frame_count(clip_name)
	var first_frame := _sprite.sprite_frames.get_frame_texture(clip_name, 0) as AtlasTexture
	var frame_image := first_frame.atlas.get_image().get_region(Rect2i(first_frame.region))
	var used := frame_image.get_used_rect()
	_sprite_foot_y = float(used.position.y + used.size.y)
	_position_sprite_pivot()


func _position_sprite_pivot() -> void:
	if _preview_stage == null or _sprite_pivot == null:
		return
	_sprite_pivot.position = Vector2(
		floorf(_preview_stage.size.x * 0.54),
		_ground_baseline - (_sprite_foot_y - FRAME_HEIGHT * 0.5) * PREVIEW_SCALE
	)


func _toggle_playback() -> void:
	if _sprite.is_playing():
		_sprite.pause()
		_play_button.text = "PLAY"
	else:
		_sprite.play()
		_play_button.text = "PAUSE"


func _on_flip_toggled(is_flipped: bool) -> void:
	_sprite.scale.x = -1.0 if is_flipped else 1.0


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4f6fb"))
	return label


func _button(text: String, minimum_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	return style
