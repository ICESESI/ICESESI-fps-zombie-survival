extends Node3D

const PLAYER_SPEED := 5.5
const LOOK_SENSITIVITY := 0.004
const RELOAD_SECONDS := 1.15
const MAX_WAVES := 3

var player: CharacterBody3D
var camera: Camera3D
var gun: MeshInstance3D
var zombies: Array[CharacterBody3D] = []
var hp := 100
var ammo := 12
var reserve_ammo := 96
var coins := 0
var score := 0
var wave := 1
var damage := 50
var weapon_tier := 0
var fire_rate := 0.28
var magazine_size := 12
var fire_cooldown := 0.0
var reload_timer := 0.0
var game_over := false
var victory := false
var boss_spawned := false
var look_touch := -1
var move_touch := -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var touch_look_last := Vector2.ZERO
var pitch := 0.0
var rng := RandomNumberGenerator.new()
var hud_label: Label
var message_label: Label
var chapter_label: Label
var joystick_base: Panel
var joystick_knob: Panel
var fire_button: Button
var reload_button: Button
var shop_button: Button
var restart_button: Button
var shop_panel: Panel
var upgrade_button: Button
var smg_button: Button
var rifle_button: Button
var shop_open := false
var damage_level := 0
var jump_button: Button
var heal_button: Button
var bomb_button: Button
var heal_charges := 3
var bomb_charges := 2
var jump_velocity := 8.0
var muzzle_flash: MeshInstance3D
var loot_pickups: Array[Node3D] = []
var loot_hold_time := 0.0
var loot_target: Node3D

# Persistent player progression stored in Android app-private user:// storage.
const SAVE_PATH := "user://fps_zombie_progress.cfg"
var persistent_level := 0
var best_score := 0
var started := false
var start_layer: CanvasLayer
var start_level_label: Label
var start_button: Button
var debug_layer: CanvasLayer
var debug_panel: Panel
var debug_label: Label
var debug_button: Button
var debug_lines: Array[String] = []
const DEBUG_LOG_PATH := "user://fps_zombie_debug.log"

func _ready() -> void:
	_debug_log("BOOT: _ready entered")
	_build_debug_overlay()
	_debug_log("BOOT: debug overlay created")
	rng.randomize()
	_load_progress()
	_debug_log("BOOT: progress loaded")
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		_debug_log("BOOT: landscape requested")
	_debug_log("BOOT: building world")
	_build_world()
	_debug_log("BOOT: world built")
	_build_player()
	_debug_log("BOOT: player/camera built")
	_build_hud()
	_debug_log("BOOT: HUD built")
	_build_start_screen()
	_debug_log("BOOT: start screen built")
	_update_hud()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_debug_log("BOOT: ready complete")

func _debug_log(line: String) -> void:
	var stamp := Time.get_datetime_string_from_system()
	var entry := "%s | %s" % [stamp, line]
	debug_lines.append(entry)
	if debug_lines.size() > 18:
		debug_lines.pop_front()
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(entry)
		f.close()
	if is_instance_valid(debug_label):
		var first := maxi(0, debug_lines.size() - 9)
		debug_label.text = "FPS ZOMBIE DEBUG\\n" + "\\n".join(debug_lines.slice(first, debug_lines.size()))

func _build_debug_overlay() -> void:
	debug_layer = CanvasLayer.new()
	debug_layer.name = "RuntimeDebug"
	debug_layer.layer = 100
	add_child(debug_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	debug_layer.add_child(root)
	debug_button = Button.new()
	debug_button.text = "DEBUG"
	debug_button.position = Vector2(12, 90)
	debug_button.size = Vector2(92, 42)
	debug_button.z_index = 100
	debug_button.pressed.connect(_toggle_debug_panel)
	root.add_child(debug_button)
	debug_panel = Panel.new()
	debug_panel.position = Vector2(12, 138)
	debug_panel.size = Vector2(560, 300)
	debug_panel.visible = false
	debug_panel.z_index = 100
	root.add_child(debug_panel)
	debug_label = Label.new()
	debug_label.position = Vector2(10, 8)
	debug_label.size = Vector2(540, 282)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_panel.add_child(debug_label)
	_debug_log("DEBUG: overlay ready")

func _toggle_debug_panel() -> void:
	if is_instance_valid(debug_panel):
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_debug_log("DEBUG: panel opened")

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		persistent_level = maxi(0, int(cfg.get_value("progress", "level", 0)))
		coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
		best_score = maxi(0, int(cfg.get_value("progress", "best_score", 0)))
		damage_level = maxi(0, int(cfg.get_value("progress", "damage_level", 0)))
		weapon_tier = clampi(int(cfg.get_value("progress", "weapon_tier", 0)), 0, 2)
		damage = 50 + damage_level * 15
		if weapon_tier == 1:
			damage = maxi(damage, 38)
			fire_rate = 0.12
			magazine_size = 30
			reserve_ammo = 120
		elif weapon_tier == 2:
			damage = maxi(damage, 100)
			fire_rate = 0.42
			magazine_size = 8
			reserve_ammo = 48
		ammo = magazine_size

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", persistent_level)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "damage_level", damage_level)
	cfg.set_value("progress", "weapon_tier", weapon_tier)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Progress save failed: %s" % error_string(err))

func _build_start_screen() -> void:
	start_layer = CanvasLayer.new()
	start_layer.name = "StartScreen"
	start_layer.layer = 10
	add_child(start_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.03, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -205
	panel.offset_bottom = 205
	root.add_child(panel)
	var title := Label.new()
	title.text = "FPS ZOMBIE SURVIVAL"
	title.position = Vector2(20, 22)
	title.size = Vector2(480, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(1.0, 0.28, 0.18))
	panel.add_child(title)
	start_level_label = Label.new()
	start_level_label.position = Vector2(28, 90)
	start_level_label.size = Vector2(464, 110)
	start_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_level_label.add_theme_font_size_override("font_size", 21)
	start_level_label.add_theme_color_override("font_color", Color(0.93, 0.96, 0.9))
	panel.add_child(start_level_label)
	start_button = Button.new()
	start_button.text = "MULA BERMAIN"
	start_button.position = Vector2(75, 225)
	start_button.size = Vector2(370, 58)
	start_button.mouse_filter = Control.MOUSE_FILTER_STOP
	start_button.add_theme_font_size_override("font_size", 23)
	start_button.pressed.connect(_start_game)
	panel.add_child(start_button)
	var note := Label.new()
	note.text = "Kawal dengan joystick kiri • Lihat dengan seret kanan\nBunuh zombie untuk dapat koin dan upgrade senjata"
	note.position = Vector2(20, 300)
	note.size = Vector2(480, 70)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.75, 0.82, 0.8))
	panel.add_child(note)
	_refresh_start_screen()

func _refresh_start_screen() -> void:
	if is_instance_valid(start_level_label):
		start_level_label.text = "LEVEL %d\nKoin tersimpan: %d\nRekod terbaik: %d\n\nSetiap level menambah jumlah, HP dan kelajuan zombie." % [persistent_level + 1, coins, best_score]

func _start_game() -> void:
	_debug_log("GAME: start pressed")
	if started:
		return
	# Each new run advances the saved level and permanently raises difficulty.
	persistent_level += 1
	started = true
	start_layer.visible = false
	_spawn_wave()
	_debug_log("GAME: first wave spawned, zombie_count=%d" % zombies.size())
	_save_progress()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.75, 0.78)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.25
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(100, 1, 100)
	ground_mesh.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.19, 0.23, 0.18)
	ground_mat.roughness = 1.0
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = plane.size
	ground_col.shape = ground_shape
	ground.add_child(ground_col)
	ground.position.y = -0.5
	add_child(ground)

	# Simple perimeter walls and visible crates give the player clear landmarks.
	for i in range(4):
		var wall := StaticBody3D.new()
		var wall_mesh := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		wall_box.size = Vector3(64, 3.5, 0.7) if i < 2 else Vector3(0.7, 3.5, 64)
		wall_mesh.mesh = wall_box
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.13, 0.16, 0.17)
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)
		var wall_col := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()
		wall_shape.size = wall_box.size
		wall_col.shape = wall_shape
		wall.add_child(wall_col)
		if i == 0:
			wall.position = Vector3(0, 1.75, -32)
		elif i == 1:
			wall.position = Vector3(0, 1.75, 32)
		elif i == 2:
			wall.position = Vector3(-32, 1.75, 0)
		else:
			wall.position = Vector3(32, 1.75, 0)
		add_child(wall)

	for i in range(14):
		var x := rng.randf_range(-23.0, 23.0)
		var z := rng.randf_range(-23.0, 23.0)
		if Vector2(x, z).length() < 8.0:
			continue
		var prop := StaticBody3D.new()
		var mesh_node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(1.5, 3.2), rng.randf_range(1.0, 2.4), rng.randf_range(1.5, 3.2))
		mesh_node.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.22, 0.17) if i % 2 == 0 else Color(0.17, 0.21, 0.22)
		mesh_node.material_override = mat
		prop.add_child(mesh_node)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		prop.add_child(col)
		prop.position = Vector3(x, box.size.y * 0.5, z)
		prop.rotation.y = rng.randf_range(-0.5, 0.5)
		add_child(prop)


	# Low-cost trees and small ruined buildings make the arena feel less empty.
	for i in range(10):
		var x := rng.randf_range(-26.0, 26.0)
		var z := rng.randf_range(-26.0, 26.0)
		if Vector2(x, z).length() < 9.0:
			continue
		var tree := Node3D.new()
		tree.position = Vector3(x, 0, z)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.22
		trunk_mesh.bottom_radius = 0.34
		trunk_mesh.height = 2.2
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.1
		trunk.material_override = _make_mat(Color(0.24, 0.14, 0.08))
		tree.add_child(trunk)
		var leaves := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 1.15
		leaf_mesh.height = 2.2
		leaves.mesh = leaf_mesh
		leaves.position.y = 2.65
		leaves.material_override = _make_mat(Color(0.12, 0.28 + rng.randf() * 0.12, 0.13))
		tree.add_child(leaves)
		add_child(tree)
	for i in range(4):
		var house := StaticBody3D.new()
		var building := MeshInstance3D.new()
		var building_mesh := BoxMesh.new()
		building_mesh.size = Vector3(4.5, 3.2, 4.0)
		building.mesh = building_mesh
		building.material_override = _make_mat(Color(0.27, 0.25, 0.22))
		building.position.y = 1.6
		house.add_child(building)
		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(5.0, 0.35, 4.5)
		roof.mesh = roof_mesh
		roof.material_override = _make_mat(Color(0.16, 0.17, 0.18))
		roof.position.y = 3.35
		house.add_child(roof)
		var house_col := CollisionShape3D.new()
		var house_shape := BoxShape3D.new()
		house_shape.size = Vector3(4.5, 3.2, 4.0)
		house_col.shape = house_shape
		house_col.position.y = 1.6
		house.add_child(house_col)
		house.position = Vector3([-22.0, 22.0, -22.0, 22.0][i], 0, [-20.0, -20.0, 20.0, 20.0][i])
		add_child(house)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.0, 10)
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	player.add_child(capsule)

	camera = Camera3D.new()
	camera.position = Vector3(0, 0.58, 0)
	camera.fov = 78
	camera.current = true
	player.add_child(camera)

	gun = MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.20, 0.16, 0.62)
	gun.mesh = gun_mesh
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.07, 0.08, 0.09)
	gun.material_override = gun_mat
	gun.position = Vector3(0.34, -0.30, -0.68)
	camera.add_child(gun)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.09, 0.09, 0.34)
	barrel.mesh = barrel_mesh
	barrel.material_override = gun_mat
	barrel.position = Vector3(0.0, 0.04, -0.43)
	gun.add_child(barrel)
	add_child(player)

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat

func _spawn_zombie(at_position: Vector3, is_boss := false) -> void:
	var zombie := CharacterBody3D.new()
	zombie.name = "HilmiJrProZombie" if is_boss else "Zombie"
	zombie.position = at_position
	var difficulty := 1.0 + float(persistent_level - 1) * 0.22
	var zombie_hp := int((1400 if is_boss else 100) * difficulty)
	zombie.set_meta("hp", zombie_hp)
	zombie.set_meta("max_hp", zombie_hp)
	zombie.set_meta("attack_timer", 0.7)
	zombie.set_meta("boss", is_boss)
	zombie.set_meta("speed", (1.0 if is_boss else rng.randf_range(1.25, 1.8)) * (1.0 + float(persistent_level - 1) * 0.06))

	var body := MeshInstance3D.new()
	if is_boss:
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.82
		body_mesh.height = 1.65
		body.mesh = body_mesh
		body.scale = Vector3(1.35, 1.05, 1.1)
		body.material_override = _make_mat(Color(0.42, 0.20, 0.16))
		body.position.y = 0.95
	else:
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.38
		capsule_mesh.height = 1.55
		body.mesh = capsule_mesh
		body.material_override = _make_mat(Color(0.25, 0.43, 0.24))
		body.position.y = 0.82
	zombie.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28 if is_boss else 0.25
	head_mesh.height = 0.5 if is_boss else 0.45
	head.mesh = head_mesh
	head.material_override = _make_mat(Color(0.47, 0.55, 0.31) if not is_boss else Color(0.52, 0.34, 0.27))
	head.position = Vector3(0, 1.83 if is_boss else 1.68, 0)
	zombie.add_child(head)

	var eye_mat := _make_mat(Color(1.0, 0.04, 0.015))
	for eye_x in [-0.10, 0.10]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 1.72 if is_boss else 1.70, -0.22)
		zombie.add_child(eye)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72 if is_boss else 0.38
	shape.height = 2.05 if is_boss else 1.65
	collision.shape = shape
	collision.position.y = 0.95 if is_boss else 0.82
	zombie.add_child(collision)
	var hp_tag := Label3D.new()
	hp_tag.name = "HPTag"
	hp_tag.text = "BOSS %d HP" % zombie_hp if is_boss else "%d HP" % zombie_hp
	hp_tag.position = Vector3(0, 2.35 if is_boss else 2.05, 0)
	hp_tag.font_size = 48
	hp_tag.pixel_size = 0.008
	hp_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_tag.modulate = Color(1.0, 0.25, 0.2)
	zombie.add_child(hp_tag)

	add_child(zombie)
	zombies.append(zombie)

func _spawn_random_loot(at_position: Vector3) -> void:
	var roll := rng.randi_range(0, 99)
	var kind := "ammo" if roll < 50 else ("heal" if roll < 80 else "bomb")
	var pickup := Node3D.new()
	pickup.name = "Loot_" + kind
	pickup.position = at_position + Vector3(rng.randf_range(-1.0, 1.0), -0.8, rng.randf_range(-1.0, 1.0))
	pickup.set_meta("loot_kind", kind)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.45, 0.55)
	mesh.mesh = box
	var color := Color(0.2, 0.65, 1.0) if kind == "ammo" else (Color(0.2, 1.0, 0.35) if kind == "heal" else Color(1.0, 0.35, 0.08))
	mesh.material_override = _make_mat(color)
	mesh.position.y = 0.3
	pickup.add_child(mesh)
	var tag := Label3D.new()
	tag.text = "PELURU" if kind == "ammo" else ("HEAL" if kind == "heal" else "BOM")
	tag.position.y = 1.0
	tag.font_size = 32
	tag.pixel_size = 0.009
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup.add_child(tag)
	add_child(pickup)
	loot_pickups.append(pickup)

func _update_loot_pickups(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var nearest: Node3D = null
	var nearest_distance := 9999.0
	for item in loot_pickups.duplicate():
		if not is_instance_valid(item):
			loot_pickups.erase(item)
			continue
		item.rotate_y(delta * 0.8)
		var d := player.global_position.distance_to(item.global_position)
		if d < 2.0 and d < nearest_distance:
			nearest = item
			nearest_distance = d
	if nearest != loot_target:
		loot_target = nearest
		loot_hold_time = 0.0
	if is_instance_valid(loot_target):
		loot_hold_time += delta
		message_label.text = "AMBIL %s... %.1f/1.0s" % [str(loot_target.get_meta("loot_kind", "ITEM")).to_upper(), minf(loot_hold_time, 1.0)]
		if loot_hold_time >= 1.0:
			var kind := str(loot_target.get_meta("loot_kind", "ammo"))
			if kind == "ammo":
				reserve_ammo += 24
				message_label.text = "+24 PELURU"
			elif kind == "heal":
				heal_charges += 1
				heal_button.text = "HEAL x%d" % heal_charges
				message_label.text = "+1 HEAL"
			else:
				bomb_charges += 1
				bomb_button.text = "BOM x%d" % bomb_charges
				message_label.text = "+1 BOM"
			loot_pickups.erase(loot_target)
			loot_target.queue_free()
			loot_target = null
			loot_hold_time = 0.0
			_update_hud()
	else:
		loot_hold_time = 0.0

func _spawn_wave() -> void:
	boss_spawned = false
	if wave >= 3:
		boss_spawned = true
		chapter_label.text = "BABAK 3: BOSS HILMI JR PRO ZOMBIE"
		_spawn_zombie(player.global_position + Vector3(0, 0, -17), true)
		for i in range(mini(3 + int((persistent_level - 1) / 3), 8)):
			var angle := TAU * float(i) / float(mini(3 + int((persistent_level - 1) / 3), 8))
			_spawn_zombie(player.global_position + Vector3(cos(angle) * 12.0, 0, sin(angle) * 12.0), false)
	else:
		chapter_label.text = "BABAK %d: %s" % [wave, "KUBURAN TERBIAR" if wave == 1 else "GUDANG ZOMBIE"]
		var count := 5 + wave * 2 + mini(persistent_level - 1, 20)
		for i in range(count):
			var angle := TAU * float(i) / float(count)
			var radius := rng.randf_range(12.0, 19.0)
			_spawn_zombie(Vector3(cos(angle) * radius, 0, sin(angle) * radius), false)
	message_label.text = "BERTAHAN HIDUP! KALAHKAN SEMUA ZOMBIE"
	_update_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	chapter_label = Label.new()
	chapter_label.position = Vector2(22, 12)
	chapter_label.add_theme_font_size_override("font_size", 22)
	chapter_label.add_theme_color_override("font_color", Color(1.0, 0.73, 0.26))
	root.add_child(chapter_label)

	hud_label = Label.new()
	hud_label.position = Vector2(22, 42)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.91))
	root.add_child(hud_label)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 0.15
	message_label.anchor_bottom = 0.15
	message_label.offset_left = -300
	message_label.offset_right = 300
	message_label.offset_top = 0
	message_label.offset_bottom = 55
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 23)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	root.add_child(message_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -14
	crosshair.offset_right = 14
	crosshair.offset_top = -22
	crosshair.offset_bottom = 22
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 36)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	root.add_child(crosshair)

	joystick_base = Panel.new()
	joystick_base.modulate = Color(0.7, 0.8, 0.85, 0.72)
	joystick_base.size = Vector2(138, 138)
	joystick_base.position = Vector2(32, -160)
	joystick_base.anchor_top = 1
	joystick_base.anchor_bottom = 1
	root.add_child(joystick_base)
	joystick_knob = Panel.new()
	joystick_knob.modulate = Color(0.95, 0.98, 1.0, 0.9)
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.position = Vector2(40, 40)
	joystick_base.add_child(joystick_knob)

	fire_button = _make_button(root, "TEMBAK", Vector2(116, 70), Vector2(-135, -90))
	fire_button.pressed.connect(_shoot)
	reload_button = _make_button(root, "RELOAD", Vector2(104, 52), Vector2(-250, -76))
	reload_button.pressed.connect(_reload)
	shop_button = _make_button(root, "KEDAI", Vector2(110, 52), Vector2(-135, -160))
	shop_button.pressed.connect(_toggle_shop)
	jump_button = _make_button(root, "LOMPAT", Vector2(104, 48), Vector2(-260, -145))
	jump_button.pressed.connect(_jump)
	heal_button = _make_button(root, "HEAL x3", Vector2(104, 48), Vector2(-380, -145))
	heal_button.pressed.connect(_use_heal)
	bomb_button = _make_button(root, "BOM x2", Vector2(104, 48), Vector2(-380, -85))
	bomb_button.pressed.connect(_throw_bomb)

	restart_button = _make_button(root, "MAIN SEMULA", Vector2(200, 62), Vector2(-100, 0))
	restart_button.anchor_left = 0.5
	restart_button.anchor_right = 0.5
	restart_button.anchor_top = 0.58
	restart_button.anchor_bottom = 0.58
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)

	shop_panel = Panel.new()
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -235
	shop_panel.offset_right = 235
	shop_panel.offset_top = -180
	shop_panel.offset_bottom = 180
	shop_panel.visible = false
	shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shop_panel)

	var shop_title := Label.new()
	shop_title.text = "KEDAI SENJATA"
	shop_title.position = Vector2(20, 12)
	shop_title.add_theme_font_size_override("font_size", 25)
	shop_panel.add_child(shop_title)

	upgrade_button = Button.new()
	upgrade_button.text = "UPGRADE DAMAGE"
	upgrade_button.position = Vector2(20, 58)
	upgrade_button.size = Vector2(420, 46)
	upgrade_button.pressed.connect(_upgrade_damage)
	shop_panel.add_child(upgrade_button)

	smg_button = Button.new()
	smg_button.text = "BELI SMG — 250 KOIN"
	smg_button.position = Vector2(20, 112)
	smg_button.size = Vector2(420, 46)
	smg_button.pressed.connect(_buy_smg)
	shop_panel.add_child(smg_button)

	rifle_button = Button.new()
	rifle_button.text = "BELI RIFLE — 500 KOIN"
	rifle_button.position = Vector2(20, 166)
	rifle_button.size = Vector2(420, 46)
	rifle_button.pressed.connect(_buy_rifle)
	shop_panel.add_child(rifle_button)

	var close_button := Button.new()
	close_button.name = "ShopCloseButton"
	close_button.text = "TUTUP"
	close_button.position = Vector2(340, 8)
	close_button.size = Vector2(100, 38)
	close_button.pressed.connect(_toggle_shop)
	shop_panel.add_child(close_button)
	_refresh_shop()

func _make_button(parent: Control, text_value: String, button_size: Vector2, offset: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.size = button_size
	b.position = offset
	b.anchor_left = 1
	b.anchor_right = 1
	b.anchor_top = 1
	b.anchor_bottom = 1
	b.add_theme_font_size_override("font_size", 17)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(b)
	return b

func _process(delta: float) -> void:
	if not started or game_over or victory:
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if is_instance_valid(gun):
		gun.position.z = move_toward(gun.position.z, -0.68, delta * 1.8)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			var needed := magazine_size - ammo
			var loaded := mini(needed, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			message_label.text = "RELOAD SELESAI" if loaded > 0 else "TIADA PELURU SIMPANAN"
			_update_hud()
	_update_loot_pickups(delta)
	_update_zombies(delta)
	_update_hud()

func _physics_process(delta: float) -> void:
	if not started or game_over or victory or shop_open:
		player.velocity = Vector3.ZERO
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := player.global_transform.basis.x * keyboard.x - player.global_transform.basis.z * keyboard.y
	direction += player.global_transform.basis.x * move_vector.x + player.global_transform.basis.z * move_vector.y
	direction.y = 0
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0
	player.move_and_slide()


func _jump() -> void:
	if not started or game_over or victory or shop_open:
		return
	if player.is_on_floor():
		player.velocity.y = jump_velocity
		message_label.text = "LOMPAT!"

func _use_heal() -> void:
	if not started or game_over or victory or shop_open:
		return
	if heal_charges <= 0:
		message_label.text = "HEAL HABIS!"
		return
	if hp >= 100:
		message_label.text = "HP MASIH PENUH"
		return
	heal_charges -= 1
	hp = mini(100, hp + 40)
	heal_button.text = "HEAL x%d" % heal_charges
	message_label.text = "+40 HP"
	_update_hud()

func _throw_bomb() -> void:
	if not started or game_over or victory or shop_open:
		return
	if bomb_charges <= 0:
		message_label.text = "BOM HABIS!"
		return
	bomb_charges -= 1
	bomb_button.text = "BOM x%d" % bomb_charges
	var blast_center := player.global_position + (-camera.global_transform.basis.z * 7.0)
	_spawn_blast(blast_center)
	for zombie in zombies.duplicate():
		if is_instance_valid(zombie) and zombie.global_position.distance_to(blast_center) <= 7.0:
			var remaining := int(zombie.get_meta("hp", 100)) - 180
			zombie.set_meta("hp", remaining)
			if remaining <= 0:
				_kill_zombie(zombie)
			else:
				message_label.text = "LETUPAN! HP ZOMBIE: %d" % remaining
	_update_hud()

func _spawn_blast(at_position: Vector3) -> void:
	var blast := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	blast.mesh = sphere
	blast.position = at_position + Vector3(0, 0.8, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.32, 0.04, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = mat
	add_child(blast)
	var tween := create_tween()
	tween.tween_property(blast, "scale", Vector3(8, 8, 8), 0.32)
	tween.tween_callback(blast.queue_free)

func _spawn_hit_effect(at_position: Vector3, color := Color(1.0, 0.18, 0.06)) -> void:
	var effect := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	effect.mesh = mesh
	effect.position = at_position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	effect.material_override = mat
	add_child(effect)
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3(2.5, 2.5, 2.5), 0.18)
	tween.tween_callback(effect.queue_free)

func _kill_zombie(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var is_boss := bool(target.get_meta("boss", false))
	var death_pos: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	_spawn_hit_effect(death_pos, Color(0.9, 0.05, 0.02))
	score += 500 if is_boss else 100
	coins += 500 if is_boss else 25
	_spawn_random_loot(death_pos)
	best_score = maxi(best_score, score)
	_save_progress()
	zombies.erase(target as CharacterBody3D)
	target.queue_free()
	if is_boss:
		victory = true
		message_label.text = "BOSS TUMBANG! MISI SELESAI! +500 KOIN"
		restart_button.visible = true
	elif zombies.is_empty():
		if wave < MAX_WAVES:
			wave += 1
			_spawn_wave()
		else:
			victory = true
			message_label.text = "SEMUA BABAK SELESAI!"
			restart_button.visible = true
	else:
		message_label.text = "ZOMBIE TUMBANG! +25 KOIN"

func _update_zombies(delta: float) -> void:
	for zombie in zombies.duplicate():
		if not is_instance_valid(zombie):
			zombies.erase(zombie)
			continue
		var to_player: Vector3 = player.global_position - zombie.global_position
		to_player.y = 0
		var distance: float = to_player.length()
		var is_boss := bool(zombie.get_meta("boss", false))
		if distance > (1.75 if is_boss else 1.25):
			var direction: Vector3 = to_player.normalized()
			var speed := float(zombie.get_meta("speed", 1.5))
			zombie.velocity.x = direction.x * speed
			zombie.velocity.z = direction.z * speed
			zombie.look_at(Vector3(player.global_position.x, zombie.global_position.y, player.global_position.z), Vector3.UP)
		else:
			zombie.velocity.x = 0
			zombie.velocity.z = 0
			var attack_timer := float(zombie.get_meta("attack_timer", 0.7)) - delta
			if attack_timer <= 0.0:
				hp -= 22 if is_boss else 8
				attack_timer = 1.0 if is_boss else 1.2
				message_label.text = "HILMI JR PRO ZOMBIE MENYERANG!" if is_boss else "ZOMBIE MENYERANG!"
			zombie.set_meta("attack_timer", attack_timer)
		if not zombie.is_on_floor():
			zombie.velocity.y -= 20.0 * delta
		else:
			zombie.velocity.y = 0
		zombie.move_and_slide()
	if hp <= 0:
		_end_game()

func _shoot() -> void:
	if not started or game_over or victory or shop_open or fire_cooldown > 0.0 or reload_timer > 0.0:
		return
	if ammo <= 0:
		message_label.text = "PELURU HABIS — TEKAN RELOAD"
		return
	ammo -= 1
	fire_cooldown = fire_rate
	if is_instance_valid(gun):
		gun.position.z = -0.48
		_spawn_hit_effect(camera.global_position + (-camera.global_transform.basis.z * 1.15) + camera.global_transform.basis.x * 0.34 + Vector3(0, -0.28, 0), Color(1.0, 0.68, 0.12))
	var from_pos := camera.global_position
	var to_pos := from_pos + (-camera.global_transform.basis.z * 60.0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit := result.get("collider") as Node
		var target: Node = hit
		while target != null and not target.has_meta("hp"):
			target = target.get_parent()
		if target != null and target.has_meta("hp"):
			var remaining := int(target.get_meta("hp")) - damage
			target.set_meta("hp", remaining)
			var hp_tag := target.get_node_or_null("HPTag") as Label3D
			if is_instance_valid(hp_tag):
				hp_tag.text = "%d/%d HP" % [maxi(remaining, 0), int(target.get_meta("max_hp", 100))]
			_spawn_hit_effect(result.get("position", target.global_position), Color(1.0, 0.25, 0.05))
			if remaining <= 0:
				_kill_zombie(target)
			else:
				message_label.text = "KENA! HP ZOMBIE: %d/%d" % [remaining, int(target.get_meta("max_hp", 100))]
	else:
		message_label.text = ""
	_update_hud()

func _reload() -> void:
	if not started or game_over or victory or reload_timer > 0.0 or ammo >= magazine_size or reserve_ammo <= 0:
		return
	reload_timer = RELOAD_SECONDS
	message_label.text = "SEDANG RELOAD..."

func _toggle_shop() -> void:
	if not started or game_over or victory:
		return
	shop_open = not shop_open
	shop_panel.visible = shop_open
	_refresh_shop()

func _upgrade_damage() -> void:
	var cost := 100 + damage_level * 100
	if coins < cost:
		message_label.text = "KOIN TAK CUKUP! PERLU %d" % cost
		return
	coins -= cost
	damage_level += 1
	damage += 15
	_save_progress()
	_refresh_shop()
	message_label.text = "DAMAGE NAIK KE %d!" % damage
	_update_hud()

func _buy_smg() -> void:
	if weapon_tier >= 1:
		message_label.text = "SMG SUDAH DIMILIKI"
		return
	if coins < 250:
		message_label.text = "PERLU 250 KOIN UNTUK SMG"
		return
	coins -= 250
	weapon_tier = 1
	damage = maxi(damage, 38)
	fire_rate = 0.12
	magazine_size = 30
	ammo = magazine_size
	reserve_ammo += 120
	_save_progress()
	_refresh_gun()
	_refresh_shop()
	_update_hud()
	message_label.text = "SMG DIBELI!"

func _buy_rifle() -> void:
	if weapon_tier >= 2:
		message_label.text = "RIFLE SUDAH DIMILIKI"
		return
	if coins < 500:
		message_label.text = "PERLU 500 KOIN UNTUK RIFLE"
		return
	coins -= 500
	weapon_tier = 2
	damage = maxi(damage, 100)
	fire_rate = 0.42
	magazine_size = 8
	ammo = magazine_size
	reserve_ammo += 48
	_save_progress()
	_refresh_gun()
	_refresh_shop()
	_update_hud()
	message_label.text = "RIFLE DIBELI!"

func _refresh_gun() -> void:
	if not is_instance_valid(gun):
		return
	var mesh := BoxMesh.new()
	if weapon_tier == 1:
		mesh.size = Vector3(0.22, 0.19, 0.76)
	elif weapon_tier == 2:
		mesh.size = Vector3(0.25, 0.22, 0.98)
	else:
		mesh.size = Vector3(0.20, 0.16, 0.62)
	gun.mesh = mesh
	var mat := _make_mat(Color(0.11, 0.16, 0.13) if weapon_tier == 1 else (Color(0.20, 0.20, 0.22) if weapon_tier == 2 else Color(0.07, 0.08, 0.09)))
	gun.material_override = mat

func _refresh_shop() -> void:
	if not is_instance_valid(upgrade_button):
		return
	upgrade_button.text = "UPGRADE DAMAGE +15 — %d KOIN" % (100 + damage_level * 100)
	smg_button.text = "SMG: DIMILIKI" if weapon_tier >= 1 else "BELI SMG — 250 KOIN"
	rifle_button.text = "RIFLE: DIMILIKI" if weapon_tier >= 2 else "BELI RIFLE — 500 KOIN"
	upgrade_button.disabled = coins < (100 + damage_level * 100)
	smg_button.disabled = weapon_tier >= 1 or coins < 250
	rifle_button.disabled = weapon_tier >= 2 or coins < 500

func _update_hud() -> void:
	if is_instance_valid(hud_label):
		var weapon_name := "PISTOL" if weapon_tier == 0 else ("SMG" if weapon_tier == 1 else "RIFLE")
		hud_label.text = "HP %d   |   %s   |   PELURU %d/%d   |   KOIN %d   |   SKOR %d   |   WAVE %d   |   HEAL %d BOM %d" % [maxi(hp, 0), weapon_name, ammo, reserve_ammo, coins, score, wave, heal_charges, bomb_charges]
	_refresh_shop()

func _end_game() -> void:
	_debug_log("GAME: game over; score=%d coins=%d" % [score, coins])
	game_over = true
	shop_open = false
	if is_instance_valid(shop_panel):
		shop_panel.visible = false
	best_score = maxi(best_score, score)
	_save_progress()
	hp = 0
	message_label.text = "GAME OVER\nSkor: %d  |  Koin: %d" % [score, coins]
	restart_button.visible = true
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _touch_hits_ui(pos: Vector2) -> bool:
    var controls: Array[Control] = [
        fire_button, reload_button, shop_button,
        jump_button, heal_button, bomb_button,
        restart_button, shop_panel, start_button,
        debug_button
    ]
    for control in controls:
        if is_instance_valid(control) and control.is_visible_in_tree():
            if control.get_global_rect().has_point(pos):
                return true
    return false

func _dispatch_mobile_ui_touch(pos: Vector2) -> bool:
	var buttons: Array[Button] = [
		fire_button, reload_button, shop_button, jump_button,
		heal_button, bomb_button, restart_button,
		upgrade_button, smg_button, rifle_button
	]
	if is_instance_valid(shop_panel):
		for child in shop_panel.get_children():
			if child is Button and child.name == "ShopCloseButton":
				buttons.append(child as Button)
	for button in buttons:
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
			continue
		if button.get_global_rect().has_point(pos):
			if button == fire_button:
				_shoot()
			elif button == reload_button:
				_reload()
			elif button == shop_button:
				_toggle_shop()
			elif button == jump_button:
				_jump()
			elif button == heal_button:
				_use_heal()
			elif button == bomb_button:
				_throw_bomb()
			elif button == restart_button:
				_restart_game()
			elif button == upgrade_button:
				_upgrade_damage()
			elif button == smg_button:
				_buy_smg()
			elif button == rifle_button:
				_buy_rifle()
			else:
				_toggle_shop()
			return true
	return false

func _input(event: InputEvent) -> void:
	# Android fallback: start game when the screen is touched inside the visible Start button.
	if not started and event is InputEventScreenTouch and event.pressed:
		if is_instance_valid(start_button) and start_button.visible:
			var button_rect: Rect2 = start_button.get_global_rect()
			if button_rect.has_point(event.position):
				get_viewport().set_input_as_handled()
				_start_game()
				return
	if event is InputEventScreenTouch and event.pressed:
		if _dispatch_mobile_ui_touch(event.position):
			get_viewport().set_input_as_handled()
			return
	if not started:
		return
	if event is InputEventMouseMotion and not OS.has_feature("mobile") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game_over:
		_rotate_view(event.relative)
	elif event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size
		if event.pressed:
			# Biarkan butang UI menerima sentuhan; jangan anggap ia kawalan kamera.
			if _touch_hits_ui(event.position):
				return
			if event.position.x < screen.x * 0.43 and move_touch == -1 and event.position.y > screen.y * 0.2:
				move_touch = event.index
				move_origin = event.position
				move_vector = Vector2.ZERO
				joystick_base.position = event.position - Vector2(69, 69)
				joystick_base.anchor_top = 0
				joystick_base.anchor_bottom = 0
				joystick_knob.position = Vector2(40, 40)
			elif event.position.x >= screen.x * 0.43 and event.position.y < screen.y * 0.78 and look_touch == -1:
				look_touch = event.index
				touch_look_last = event.position
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vector = Vector2.ZERO
				joystick_base.anchor_top = 1
				joystick_base.anchor_bottom = 1
				joystick_base.position = Vector2(32, -160)
				joystick_knob.position = Vector2(40, 40)
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var offset: Vector2 = event.position - move_origin
			var radius := 52.0
			move_vector = Vector2(clampf(offset.x / radius, -1.0, 1.0), clampf(offset.y / radius, -1.0, 1.0))
			joystick_knob.position = Vector2(40, 40) + Vector2(move_vector.x, move_vector.y) * 35.0
		elif event.index == look_touch and not game_over and not shop_open:
			_rotate_view(event.relative)

func _rotate_view(relative: Vector2) -> void:
	player.rotate_y(-relative.x * LOOK_SENSITIVITY)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY, deg_to_rad(-72), deg_to_rad(72))
	camera.rotation.x = pitch
