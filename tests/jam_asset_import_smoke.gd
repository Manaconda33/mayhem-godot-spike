extends SceneTree

const TEST_SCENE := "res://scenes/jam/asset_test.tscn"
const ASSET_ROOT := "res://assets/jam/manaconda/"
const PREVIEW_SCALE := 4.0
const FRAME_HEIGHT := 96.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE) as PackedScene
	assert(packed_scene != null, "Asset test scene must load")
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var sprite := scene.find_child("ManacondaSprite", true, false) as AnimatedSprite2D
	assert(sprite != null, "Asset test must build an AnimatedSprite2D")
	var entries: Dictionary = scene.get("_clip_entries")
	var sprite_frames := sprite.sprite_frames
	assert(entries.size() == 29, "Expected 29 registered Manaconda clips")
	assert(sprite_frames.get_animation_names().size() == 29, "Expected 29 SpriteFrames animations")
	var report_lines: Array[String] = []
	var checked_sheets: Dictionary = {}
	var total_frames := 0
	for clip_name: String in sprite_frames.get_animation_names():
		var layout: Dictionary = entries[clip_name]
		var expected_frames: Array = layout["frames"]
		var actual_count := sprite_frames.get_frame_count(clip_name)
		assert(actual_count == expected_frames.size(), "%s frame count changed" % clip_name)
		var foot_positions: Array[int] = []
		for frame_index in actual_count:
			var expected: Dictionary = expected_frames[frame_index]
			var actual := sprite_frames.get_frame_texture(clip_name, frame_index) as AtlasTexture
			assert(actual != null, "%s frame %d must use an AtlasTexture" % [clip_name, frame_index + 1])
			var expected_region := Rect2(
				float(expected["x"]), float(expected["y"]),
				float(expected["w"]), float(expected["h"])
			)
			assert(actual.region == expected_region, "%s frame %d crop changed" % [clip_name, frame_index + 1])
			var image_region := Rect2i(
				int(expected["x"]), int(expected["y"]),
				int(expected["w"]), int(expected["h"])
			)
			var frame_image := actual.atlas.get_image().get_region(image_region)
			assert(frame_image.get_used_rect().size != Vector2i.ZERO, "%s frame %d is blank" % [clip_name, frame_index + 1])
			var used := frame_image.get_used_rect()
			foot_positions.append(used.position.y + used.size.y)
			var mirror_round_trip := frame_image.duplicate()
			mirror_round_trip.flip_x()
			mirror_round_trip.flip_x()
			assert(mirror_round_trip.get_data() == frame_image.get_data(), "%s frame %d flip changed pixels" % [clip_name, frame_index + 1])
			var sheet_path: String = ASSET_ROOT + String(layout["src"]).get_file()
			if not checked_sheets.has(sheet_path):
				var source_image := Image.new()
				var source_error := source_image.load_webp_from_buffer(FileAccess.get_file_as_bytes(sheet_path))
				assert(source_error == OK, "%s source WebP must decode" % clip_name)
				var imported_image := actual.atlas.get_image()
				assert(source_image.get_size() == imported_image.get_size(), "%s imported dimensions changed" % clip_name)
				var source_bytes := source_image.get_data()
				var imported_bytes := imported_image.get_data()
				for pixel_offset in range(0, source_bytes.size(), 4):
					for channel in 4:
						if source_bytes[pixel_offset + channel] != imported_bytes[pixel_offset + channel]:
							var pixel_index := pixel_offset / 4
							print("PIXEL_MISMATCH %s formats=%s/%s at (%d,%d) rgba=%s/%s" % [sheet_path.get_file(), source_image.get_format(), imported_image.get_format(), pixel_index % source_image.get_width(), pixel_index / source_image.get_width(), [source_bytes[pixel_index * 4], source_bytes[pixel_index * 4 + 1], source_bytes[pixel_index * 4 + 2], source_bytes[pixel_index * 4 + 3]], [imported_bytes[pixel_index * 4], imported_bytes[pixel_index * 4 + 1], imported_bytes[pixel_index * 4 + 2], imported_bytes[pixel_index * 4 + 3]]])
							quit(1)
							return
				checked_sheets[sheet_path] = true
		sprite.animation = clip_name
		sprite.frame = 0
		sprite.scale.x = -1.0
		assert(sprite.scale.x == -1.0, "%s flip state must use negative X scale" % clip_name)
		sprite.scale.x = 1.0
		assert(foot_positions.min() == foot_positions.max(), "%s foot baseline drifted across frames" % clip_name)
		scene.call("_select_clip", clip_name)
		var pivot := scene.get("_sprite_pivot") as Node2D
		var ground_line := scene.get("_ground_line") as ColorRect
		var projected_foot_y := pivot.position.y + (float(foot_positions[0]) - FRAME_HEIGHT * 0.5) * PREVIEW_SCALE
		assert(is_equal_approx(projected_foot_y, ground_line.position.y), "%s foot does not sit on the ground line" % clip_name)
		total_frames += actual_count
		report_lines.append("PASS %-18s %2d/%2d frames · foot baseline %d px" % [clip_name, actual_count, expected_frames.size(), foot_positions[0]])
	for line in report_lines:
		print(line)
	print("ASSET_IMPORT_SMOKE_OK %d clips / %d frames / %d lossless sheets" % [entries.size(), total_frames, checked_sheets.size()])
	quit()
