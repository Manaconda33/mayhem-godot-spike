extends Node3D
class_name KartTrack

var path: Path3D
var curve: Curve3D
var track_length := 0.0


func _ready() -> void:
	_build_track()


func get_closest_offset(world_position: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_position))


func get_position_at_offset(offset: float) -> Vector3:
	return to_global(curve.sample_baked(fposmod(offset, track_length)))


func get_forward_at_offset(offset: float) -> Vector3:
	var sample_step := KartTuning.TRACK_TANGENT_SAMPLE
	var before := curve.sample_baked(fposmod(offset - sample_step, track_length))
	var after := curve.sample_baked(fposmod(offset + sample_step, track_length))
	return (after - before).normalized()


func get_gate_offset(gate_index: int) -> float:
	return track_length * float(KartTuning.TRACK_GATE_FRACTIONS[gate_index])


func is_on_road(world_position: Vector3) -> bool:
	var offset := get_closest_offset(world_position)
	var center := get_position_at_offset(offset)
	var forward := get_forward_at_offset(offset)
	var right := Vector3(-forward.z, 0.0, forward.x)
	var side_distance := absf((world_position - center).dot(right))
	return side_distance <= KartTuning.TRACK_HALF_WIDTH


func get_gate_pose(gate_index: int, offset_after_gate: float = 0.0) -> Dictionary:
	var gate_offset := fposmod(get_gate_offset(gate_index) + offset_after_gate, track_length)
	return {"position": get_position_at_offset(gate_offset), "forward": get_forward_at_offset(gate_offset)}


func _build_track() -> void:
	path = Path3D.new()
	path.name = "Path"
	curve = Curve3D.new()
	curve.closed = true
	var point_count := KartTuning.TRACK_POINTS.size()
	for index in point_count:
		var point: Vector3 = KartTuning.TRACK_POINTS[index]
		var previous: Vector3 = KartTuning.TRACK_POINTS[(index - 1 + point_count) % point_count]
		var following: Vector3 = KartTuning.TRACK_POINTS[(index + 1) % point_count]
		var tangent := (following - previous).normalized()
		var handle_length := minf(point.distance_to(previous), point.distance_to(following)) * KartTuning.TRACK_CONTROL_HANDLE_FRACTION
		curve.add_point(point, -tangent * handle_length, tangent * handle_length)
	path.curve = curve
	add_child(path)
	track_length = curve.get_baked_length()
	_build_ground()
	_build_road()
	_build_gates()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "FlatGround"
	var plane := PlaneMesh.new()
	plane.size = KartTuning.GROUND_SIZE
	ground.mesh = plane
	ground.position = KartTuning.GROUND_CENTER
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#224735")
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _build_road() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(1, ceili(track_length / KartTuning.TRACK_SEGMENT_LENGTH))
	for index in segments:
		var offset_a := track_length * float(index) / float(segments)
		var offset_b := track_length * float(index + 1) / float(segments)
		var center_a := curve.sample_baked(offset_a)
		var center_b := curve.sample_baked(fposmod(offset_b, track_length))
		var forward_a := _local_forward_at_offset(offset_a)
		var forward_b := _local_forward_at_offset(offset_b)
		var right_a := Vector3(-forward_a.z, 0.0, forward_a.x)
		var right_b := Vector3(-forward_b.z, 0.0, forward_b.x)
		var half_width := KartTuning.TRACK_HALF_WIDTH
		var left_a := center_a - right_a * half_width
		var right_a_edge := center_a + right_a * half_width
		var left_b := center_b - right_b * half_width
		var right_b_edge := center_b + right_b * half_width
		surface.set_normal(Vector3.UP)
		surface.add_vertex(left_a)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(right_a_edge)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(left_b)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(right_a_edge)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(right_b_edge)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(left_b)
	var road := MeshInstance3D.new()
	road.name = "RoadRibbon"
	road.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#46525d")
	material.roughness = 0.92
	road.material_override = material
	add_child(road)


func _build_gates() -> void:
	for gate_index in KartTuning.TRACK_GATE_COUNT:
		var pose := get_gate_pose(gate_index)
		var position: Vector3 = pose["position"]
		var forward: Vector3 = pose["forward"]
		var right := Vector3(-forward.z, 0.0, forward.x)
		var basis := Basis(right, Vector3.UP, -forward)
		var marking := MeshInstance3D.new()
		marking.name = "GateMarking" + str(gate_index)
		var marking_mesh := BoxMesh.new()
		marking_mesh.size = Vector3(KartTuning.TRACK_HALF_WIDTH * 2.0, KartTuning.TRACK_GATE_MARKING_HEIGHT, KartTuning.TRACK_GATE_MARKING_DEPTH)
		marking.mesh = marking_mesh
		marking.transform = Transform3D(basis, position + Vector3.UP * KartTuning.TRACK_GATE_MARKING_HEIGHT)
		var marking_material := StandardMaterial3D.new()
		marking_material.albedo_color = Color("#f6dc7b") if gate_index == 0 else Color("#d6e0e4")
		marking_material.roughness = 0.82
		marking.material_override = marking_material
		add_child(marking)
		for side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.name = "Gate%dPost%s" % [gate_index, "L" if side < 0.0 else "R"]
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(KartTuning.TRACK_GATE_POST_WIDTH, KartTuning.TRACK_GATE_HEIGHT, KartTuning.TRACK_GATE_POST_WIDTH)
			post.mesh = post_mesh
			post.position = position + right * side * KartTuning.TRACK_HALF_WIDTH + Vector3.UP * KartTuning.TRACK_GATE_HEIGHT * 0.5
			var post_material := StandardMaterial3D.new()
			post_material.albedo_color = Color("#ec7047") if gate_index == 0 else Color("#a7bac6")
			post.material_override = post_material
			add_child(post)


func _local_forward_at_offset(offset: float) -> Vector3:
	var sample_step := KartTuning.TRACK_TANGENT_SAMPLE
	var before := curve.sample_baked(fposmod(offset - sample_step, track_length))
	var after := curve.sample_baked(fposmod(offset + sample_step, track_length))
	return (after - before).normalized()
