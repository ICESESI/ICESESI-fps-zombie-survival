extends Node3D

const ZOMBIE_COUNT := 7
const PLAYER_SPEED := 5.2
const LOOK_SENSITIVITY := 0.004
const MAGAZINE_SIZE := 12
const RELOAD_SECONDS := 1.25

var player: CharacterBody3D
var camera: Camera3D
var gun: MeshInstance3D
var zombies: Array[CharacterBody3D] = []
var hp := 100
var ammo := MAGAZINE_SIZE
var reserve_ammo := 72
var score := 0
var wave := 1
var fire_cooldown := 0.0
var reload_timer := 0.0
var game_over := false
var look_touch := -1
var move_touch := -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var hud_label: Label
var message_label: Label
var joystick_base: ColorRect
var joystick_knob: ColorRect
var fire_button: Button
var reload_button: Button
var restart_button: Button
var touch_look_last := Vector2.ZERO
var pitch := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_zombies()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.05, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.15
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(70, 1, 70)
	ground_mesh.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.17, 0.21, 0.17)
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

	# Low-cost abandoned-yard props, created procedurally.
	for i in range(18):
		var x := rng.randf_range(-25, 25)
		var z := rng.randf_range(-25, 25)
		if Vector2(x, z).length() < 7.0:
			continue
		var prop := StaticBody3D.new()
		var mesh_node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(1.2, 3.8), rng.randf_range(1.5, 4.0))
		mesh_node.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.18, 0.19) if i % 2 == 0 else Color(0.22, 0.19, 0.15)
		mat.roughness = 1.0
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

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.0, 8)
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

	# Simple first-person weapon model visible at lower-right.
	gun = MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.18, 0.16, 0.62)
	gun.mesh = gun_mesh
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.08, 0.09, 0.10)
	gun.material_override = gun_mat
	gun.position = Vector3(0.32, -0.28, -0.62)
	camera.add_child(gun)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.09, 0.09, 0.34)
	barrel.mesh = barrel_mesh
	barrel.material_override = gun_mat
	barrel.position = Vector3(0.0, 0.04, -0.43)
	gun.add_child(barrel)
	add_child(player)

func _make_zombie_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.42, 0.24)
	mat.roughness = 1.0
	return mat

func _spawn_zombie(at_position: Vector3) -> void:
	var zombie := CharacterBody3D.new()
	zombie.name = "Zombie"
	zombie.position = at_position
	zombie.set_meta("hp", 100)
	zombie.set_meta("attack_timer", rng.randf_range(0.3, 1.0))
	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.38
	capsule_mesh.height = 1.55
	body.mesh = capsule_mesh
	body.material_override = _make_zombie_material()
	body.position.y = 0.82
	zombie.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.38, 0.52, 0.30)
	head.material_override = head_mat
	head.position = Vector3(0, 1.72, 0)
	zombie.add_child(head)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.8, 0.05, 0.025)
	for eye_x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 1.76, -0.215)
		zombie.add_child(eye)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.65
	collision.shape = shape
	zombie.add_child(collision)
	add_child(zombie)
	zombies.append(zombie)

func _build_zombies() -> void:
	for i in range(ZOMBIE_COUNT):
		var angle := TAU * float(i) / float(ZOMBIE_COUNT)
		var radius := rng.randf_range(11.0, 19.0)
		_spawn_zombie(Vector3(cos(angle) * radius, 0, sin(angle) * radius))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud_label = Label.new()
	hud_label.position = Vector2(22, 18)
	hud_label.add_theme_font_size_override("font_size", 23)
	hud_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.88))
	root.add_child(hud_label)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 0.22
	message_label.anchor_bottom = 0.22
	message_label.offset_left = -250
	message_label.offset_right = 250
	message_label.offset_top = -30
	message_label.offset_bottom = 40
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	root.add_child(message_label)

	# Crosshair
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -20
	crosshair.offset_bottom = 20
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 34)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	root.add_child(crosshair)

	joystick_base = ColorRect.new()
	joystick_base.color = Color(0.65, 0.75, 0.8, 0.22)
	joystick_base.size = Vector2(132, 132)
	joystick_base.position = Vector2(34, -166)
	joystick_base.anchor_top = 1
	joystick_base.anchor_bottom = 1
	root.add_child(joystick_base)

	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(0.85, 0.92, 0.96, 0.55)
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.position = Vector2(37, 37)
	joystick_base.add_child(joystick_knob)

	fire_button = Button.new()
	fire_button.text = "TEMBAK"
	fire_button.size = Vector2(112, 72)
	fire_button.position = Vector2(-145, -112)
	fire_button.anchor_left = 1
	fire_button.anchor_right = 1
	fire_button.anchor_top = 1
	fire_button.anchor_bottom = 1
	fire_button.add_theme_font_size_override("font_size", 19)
	fire_button.pressed.connect(_shoot)
	root.add_child(fire_button)

	reload_button = Button.new()
	reload_button.text = "RELOAD"
	reload_button.size = Vector2(100, 52)
	reload_button.position = Vector2(-158, -194)
	reload_button.anchor_left = 1
	reload_button.anchor_right = 1
	reload_button.anchor_top = 1
	reload_button.anchor_bottom = 1
	reload_button.pressed.connect(_reload)
	root.add_child(reload_button)

	restart_button = Button.new()
	restart_button.text = "MAIN SEMULA"
	restart_button.size = Vector2(200, 62)
	restart_button.anchor_left = 0.5
	restart_button.anchor_right = 0.5
	restart_button.anchor_top = 0.58
	restart_button.anchor_bottom = 0.58
	restart_button.offset_left = -100
	restart_button.offset_right = 100
	restart_button.offset_top = 0
	restart_button.offset_bottom = 62
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)
	root.add_child(restart_button)

func _process(delta: float) -> void:
	if game_over:
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			var needed := MAGAZINE_SIZE - ammo
			var loaded := mini(needed, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			message_label.text = ""
	_update_hud()
	_update_zombies(delta)

func _physics_process(delta: float) -> void:
	if game_over:
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3.ZERO
	direction += player.global_transform.basis.z * keyboard.y
	direction += player.global_transform.basis.x * keyboard.x
	direction += player.global_transform.basis.z * move_vector.y
	direction += player.global_transform.basis.x * move_vector.x
	direction.y = 0
	if direction.length() > 1:
		direction = direction.normalized()
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()

func _update_zombies(delta: float) -> void:
	for zombie in zombies.duplicate():
		if not is_instance_valid(zombie):
			zombies.erase(zombie)
			continue
		var to_player := player.global_position - zombie.global_position
		to_player.y = 0
		var distance := to_player.length()
		if distance > 1.35:
			var direction := to_player.normalized()
			zombie.velocity.x = direction.x * (1.45 + minf(float(score) * 0.015, 1.0))
			zombie.velocity.z = direction.z * (1.45 + minf(float(score) * 0.015, 1.0))
			zombie.look_at(Vector3(player.global_position.x, zombie.global_position.y, player.global_position.z), Vector3.UP)
		else:
			zombie.velocity.x = 0
			zombie.velocity.z = 0
			var attack_timer := float(zombie.get_meta("attack_timer")) - delta
			if attack_timer <= 0.0:
				hp -= 8
				attack_timer = 1.0
				message_label.text = "ZOMBIE MENYERANG!"
			zombie.set_meta("attack_timer", attack_timer)
		if not zombie.is_on_floor():
			zombie.velocity.y -= 20.0 * delta
		else:
			zombie.velocity.y = 0
		zombie.move_and_slide()
	if hp <= 0:
		_end_game()

func _shoot() -> void:
	if game_over or fire_cooldown > 0.0 or reload_timer > 0.0:
		return
	if ammo <= 0:
		message_label.text = "PELURU HABIS — TEKAN RELOAD"
		return
	ammo -= 1
	fire_cooldown = 0.22
	gun.position.z = -0.48
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 45.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit := result.get("collider") as Node
		var zombie := hit
		while zombie != null and not zombie.has_meta("hp"):
			zombie = zombie.get_parent()
		if zombie != null and zombie.has_meta("hp"):
			var remaining := int(zombie.get_meta("hp")) - 50
			zombie.set_meta("hp", remaining)
			if remaining <= 0:
				score += 100
				zombies.erase(zombie)
				zombie.queue_free()
				if zombies.is_empty():
					wave += 1
					for i in range(mini(5 + wave * 2, 18)):
						var angle := rng.randf_range(0, TAU)
						var radius := rng.randf_range(12, 22)
						_spawn_zombie(player.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius))
					message_label.text = "WAVE %d — ZOMBIE BAHARU!" % wave
				else:
					message_label.text = "ZOMBIE TUMBANG! +100"
			else:
				message_label.text = "KENA! TEMBAK LAGI"
	else:
		message_label.text = ""
	_update_hud()

func _reload() -> void:
	if game_over or reload_timer > 0.0 or ammo == MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	reload_timer = RELOAD_SECONDS
	message_label.text = "SEDANG RELOAD..."

func _update_hud() -> void:
	if hud_label:
		hud_label.text = "HP %d   |   PELURU %d/%d   |   SKOR %d   |   WAVE %d" % [maxi(hp, 0), ammo, reserve_ammo, score, wave]

func _end_game() -> void:
	game_over = true
	hp = 0
	message_label.text = "GAME OVER\nSkor: %d" % score
	restart_button.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game_over:
		_rotate_view(event.relative)
	elif event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size
		if event.pressed:
			if event.position.x < screen.x * 0.45 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				move_vector = Vector2.ZERO
				joystick_base.position = event.position - Vector2(66, 66)
				joystick_base.anchor_top = 0
				joystick_base.anchor_bottom = 0
				joystick_knob.position = Vector2(37, 37)
			elif event.position.x >= screen.x * 0.45:
				look_touch = event.index
				touch_look_last = event.position
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vector = Vector2.ZERO
				joystick_base.anchor_top = 1
				joystick_base.anchor_bottom = 1
				joystick_base.position = Vector2(34, -166)
				joystick_knob.position = Vector2(37, 37)
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var offset := event.position - move_origin
			var max_radius := 48.0
			move_vector = Vector2(clampf(offset.x / max_radius, -1, 1), clampf(offset.y / max_radius, -1, 1))
			joystick_knob.position = Vector2(37, 37) + Vector2(move_vector.x, move_vector.y) * 34.0
		elif event.index == look_touch and not game_over:
			_rotate_view(event.relative)

func _rotate_view(relative: Vector2) -> void:
	player.rotate_y(-relative.x * LOOK_SENSITIVITY)
	pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY, deg_to_rad(-75), deg_to_rad(75))
	camera.rotation.x = pitch
