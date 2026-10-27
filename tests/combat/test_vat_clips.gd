extends GutTest

var _clips: VatClips


func before_each() -> void:
	_clips = VatClips.new()
	_clips.fps = 24.0
	_clips.names = PackedStringArray(["walk", "attack"])
	_clips.start_row = PackedInt32Array([0, 24])
	_clips.frames = PackedInt32Array([24, 18])
	_clips.loops = PackedInt32Array([1, 0])
	_clips.stride = PackedFloat32Array([1.3, 0.0])


func test_loop_clip_wraps_by_cycle() -> void:
	assert_eq(_clips.rows_at(0, 0.0), Vector3(0, 1, 0))
	assert_almost_eq(_clips.rows_at(0, 0.5).x, 12.0, 0.001)
	var end: Vector3 = _clips.rows_at(0, 23.5 / 24.0)
	assert_eq(int(end.x), 23)
	assert_eq(int(end.y), 0, "the last frame blends back into the first")
	assert_almost_eq(end.z, 0.5, 0.001)
	assert_eq(_clips.rows_at(0, 1.25), _clips.rows_at(0, 0.25))


func test_one_shot_clip_runs_by_time_and_holds_last_frame() -> void:
	var mid: Vector3 = _clips.rows_at(1, 0.25)  # 6 frames in
	assert_eq(int(mid.x), 24 + 6)
	var held: Vector3 = _clips.rows_at(1, 10.0)
	assert_eq(int(held.x), 24 + 17)
	assert_eq(int(held.y), 24 + 17)


func test_index_and_duration() -> void:
	assert_eq(_clips.index_of("attack"), 1)
	assert_eq(_clips.index_of("dance"), -1)
	assert_almost_eq(_clips.duration(1), 0.75, 0.001)
