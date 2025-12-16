# creature.gd
# Animated creature that moves around the desert with species-specific behaviors
# Each species has its own movement style, speed, and animation

extends CharacterBody2D
class_name Creature

# === ENUMS ===

enum MoveStyle {
	WANDER,        # Dingo, Kangaroo - steady movement, occasional turns
	SCURRY_HIDE,   # Spinifex Mouse - sit still, rush to plant bases
	SCURRY_BASK,   # Thorny Devil - sit still, rush to sunny spots
	SOAR,          # Eagle - glide in sky, land in trees
	FLUTTER,       # Honeyeater - short bursts between plants/trees
	AMBLE          # Bilby - small wander with frequent stops to sniff
}

enum CreatureState {
	IDLE,
	MOVING,
	STOPPING,    # Transitioning to idle
	RESTING,     # Paused at destination (for scurry/flutter types)
	SNIFFING     # Bilby-specific nibbling/sniffing behavior
}

# === CONSTANTS ===

const GROUND_Y_MIN: float = 300.0   # Minimum Y for ground creatures
const GROUND_Y_MAX: float = 650.0   # Maximum Y for ground creatures
const SKY_Y_MIN: float = 100.0      # Minimum Y for flying creatures (high)
const SKY_Y_MAX: float = 280.0      # Maximum Y for flying creatures (low sky)
const TREE_Y_RANGE: Vector2 = Vector2(200.0, 350.0)  # Y range for tree perching

const SCREEN_MARGIN: float = 50.0
const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0

# === EXPORTS ===

@export var species: String = ""

# === NODE REFERENCES ===

@onready var sprite: Sprite2D = $Sprite2D
@onready var ap: AnimationPlayer = $AnimationPlayer
@onready var aud : AudioStreamPlayer = $AudioStreamPlayer
# === STATE ===

var speed: float = 100.0
var flying: bool = false
var movement_style: MoveStyle = MoveStyle.WANDER
var current_state: CreatureState = CreatureState.IDLE

var target_position: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var idle_duration: float = 0.0
var move_duration: float = 0.0

# For altitude management (flying creatures)
var current_altitude: float = 0.0  # 0 = ground, 1 = sky
var target_altitude: float = 0.0

# Reference to plants/trees for hide/flutter behaviors
var nearby_plants: Array = []

# === LIFECYCLE ===

func _ready() -> void:
	_setup_species()
	_pick_new_behavior()
	# aud.stream = load("res://assets/audio/" + species + ".ogg")
	
#	aud.play()

func _physics_process(delta: float) -> void:
	state_timer -= delta
	z_index = position.y
	match movement_style:
		MoveStyle.WANDER:
			_process_wander(delta)
		MoveStyle.SCURRY_HIDE:
			_process_scurry_hide(delta)
		MoveStyle.SCURRY_BASK:
			_process_scurry_bask(delta)
		MoveStyle.SOAR:
			_process_soar(delta)
		MoveStyle.FLUTTER:
			_process_flutter(delta)
		MoveStyle.AMBLE:
			_process_amble(delta)
	
	_update_animation()
	move_and_slide()


# === SETUP ===

func setup(org_species: String, pos: Vector2) -> void:
	"""Initialize creature with species and position."""
	species = org_species
	position = pos
	$Label.text = species
	_setup_species()


func _setup_species() -> void:
	"""Configure creature based on species."""
	match species:
		"dingo":
			speed = 80.0
			movement_style = MoveStyle.WANDER
			flying = false
		"kangaroo":
			speed = 120.0
			movement_style = MoveStyle.WANDER
			flying = false
		"ant":
			speed = 20.0
			movement_style = MoveStyle.WANDER
			flying = false
		"termite":
			speed = 20.0
			movement_style = MoveStyle.WANDER
			flying = false
		"bilby":
			speed = 50.0
			movement_style = MoveStyle.AMBLE
			flying = false
		"sf_mouse":
			speed = 150.0  # Fast when moving
			movement_style = MoveStyle.SCURRY_HIDE
			flying = false
		"thorny_devil":
			speed = 60.0
			movement_style = MoveStyle.SCURRY_BASK
			flying = false
		"eagle":
			speed = 100.0
			movement_style = MoveStyle.SOAR
			flying = true
			current_altitude = 1.0  # Start in sky
		"honeyeater":
			speed = 80.0
			movement_style = MoveStyle.FLUTTER
			flying = true
			current_altitude = 0.5  # Start mid-height


# === MOVEMENT PROCESSORS ===

func _process_wander(delta: float) -> void:
	"""
	WANDER: Steady movement across screen with occasional direction changes.
	Used by: Dingo, Kangaroo, Ant, Termite
	"""
	match current_state:
		CreatureState.IDLE:
			# Occasionally start moving
			if state_timer <= 0:
				_start_wander_move()
		
		CreatureState.MOVING:
			# Move toward target
			var to_target: Vector2 = target_position - position
			
			if to_target.length() < 10.0 or state_timer <= 0:
				# Reached target or timeout - maybe turn or stop briefly
				if randf() < 0.3:
					_enter_idle(randf_range(0.5, 2.0))
				else:
					_start_wander_move()
			else:
				velocity = move_direction * speed
				_keep_in_bounds()


func _process_scurry_hide(delta: float) -> void:
	"""
	SCURRY_HIDE: Sit still, then rush to plant bases.
	Used by: Spinifex Mouse
	"""
	match current_state:
		CreatureState.IDLE, CreatureState.RESTING:
			velocity = Vector2.ZERO
			_keep_in_bounds() 
			if state_timer <= 0:
				# Time to scurry to a new hiding spot
				_start_scurry_to_plant()
		
		CreatureState.MOVING:
			var to_target: Vector2 = target_position - position
			
			if to_target.length() < 15.0:
				# Reached hiding spot - rest for a while
				velocity = Vector2.ZERO

				current_state = CreatureState.RESTING
				state_timer = randf_range(3.0, 8.0)  # Rest longer at plants
			else:
				velocity = move_direction * speed
				_keep_in_bounds() 


func _process_scurry_bask(delta: float) -> void:
	"""
	SCURRY_BASK: Like scurry, but stop in sunny open spots instead of plants.
	Used by: Thorny Devil
	"""
	match current_state:
		CreatureState.IDLE, CreatureState.RESTING:
			velocity = Vector2.ZERO
			_keep_in_bounds() 

			if state_timer <= 0:
				# Time to scurry to a new basking spot
				_start_scurry_to_sun()
		
		CreatureState.MOVING:
			var to_target: Vector2 = target_position - position
			
			if to_target.length() < 15.0:
				# Reached basking spot - bask for a while
				velocity = Vector2.ZERO
				current_state = CreatureState.RESTING
				state_timer = randf_range(4.0, 10.0)  # Bask in the sun
			else:
				velocity = move_direction * speed


func _process_soar(delta: float) -> void:
	"""
	SOAR: Glide through the sky, occasionally land in trees.
	Used by: Eagle
	"""
	match current_state:
		CreatureState.IDLE:
			# Perched in tree, wait then take off
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_start_soar()
		
		CreatureState.MOVING:
			var to_target: Vector2 = target_position - position
			
			# Smoothly adjust altitude
			var target_y: float = lerp(GROUND_Y_MIN, SKY_Y_MIN, target_altitude)
			position.y = lerp(position.y, target_y, delta * 2.0)
			
			if to_target.length() < 30.0 or state_timer <= 0:
				if target_altitude < 0.3:
					# Landing in tree
					current_state = CreatureState.IDLE
					state_timer = randf_range(3.0, 8.0)
					velocity = Vector2.ZERO
				else:
					# Continue soaring, pick new direction
					_start_soar()
			else:
				velocity = move_direction * speed
				_keep_in_bounds_flying()


func _process_flutter(delta: float) -> void:
	"""
	FLUTTER: Short bursts between plants and tree branches.
	Used by: Honeyeater
	"""
	match current_state:
		CreatureState.IDLE, CreatureState.RESTING:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_start_flutter()
		
		CreatureState.MOVING:
			var to_target: Vector2 = target_position - position
			
			# Smoothly adjust height
			var target_y: float = target_position.y
			position.y = lerp(position.y, target_y, delta * 3.0)
			
			if to_target.length() < 20.0:
				# Reached perch - rest briefly
				velocity = Vector2.ZERO
				_keep_in_bounds_flying() 
				current_state = CreatureState.RESTING
				state_timer = randf_range(1.0, 4.0)
			else:
				velocity = move_direction * speed


func _process_amble(delta: float) -> void:
	"""
	AMBLE: Small wandering with frequent stops to sniff and nibble.
	Used by: Bilby
	"""
	match current_state:
		CreatureState.IDLE:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				_start_amble_move()
		
		CreatureState.SNIFFING:
			# Stopped to sniff/nibble
			velocity = Vector2.ZERO
			if state_timer <= 0:
				# Done sniffing, change direction and move again
				_start_amble_move()
		
		CreatureState.MOVING:
			var to_target: Vector2 = target_position - position
			
			if to_target.length() < 10.0 or state_timer <= 0:
				# Reached spot - stop to sniff
				_enter_sniffing()
			else:
				velocity = move_direction * speed
				_keep_in_bounds()


# === BEHAVIOR STARTERS ===

func _pick_new_behavior() -> void:
	"""Initialize first behavior based on movement style."""
	match movement_style:
		MoveStyle.WANDER:
			_start_wander_move()
		MoveStyle.SCURRY_HIDE:
			current_state = CreatureState.RESTING
			state_timer = randf_range(1.0, 3.0)
		MoveStyle.SCURRY_BASK:
			current_state = CreatureState.RESTING
			state_timer = randf_range(2.0, 5.0)
		MoveStyle.SOAR:
			_start_soar()
		MoveStyle.FLUTTER:
			current_state = CreatureState.RESTING
			state_timer = randf_range(0.5, 2.0)
		MoveStyle.AMBLE:
			_enter_sniffing()


func _start_wander_move() -> void:
	"""Start a wander movement toward a random point."""
	current_state = CreatureState.MOVING
	
	# Pick a point ahead in roughly the current direction, with some randomness
	var wander_distance: float = randf_range(100.0, 300.0)
	
	# Ants and termites have smaller wander range
	if species in ["ant", "termite"]:
		wander_distance = randf_range(30.0, 80.0)
	
	# Random angle, biased slightly toward current direction
	var angle: float = randf_range(-PI, PI)
	if move_direction != Vector2.ZERO:
		var current_angle: float = move_direction.angle()
		angle = current_angle + randf_range(-PI/3, PI/3)
	
	target_position = position + Vector2(cos(angle), sin(angle)) * wander_distance
	target_position = _clamp_to_ground_bounds(target_position)
	
	move_direction = (target_position - position).normalized()
	state_timer = wander_distance / speed + 1.0  # Timeout


func _start_scurry_to_plant() -> void:
	"""Rush to a plant base for hiding."""
	current_state = CreatureState.MOVING
	
	# Find a random target - ideally near a plant, but random if none
	var plant_positions: Array = _get_plant_positions()
	
	if plant_positions.size() > 0 and randf() < 0.7:
		# Go to a plant base
		var plant_pos: Vector2 = plant_positions[randi() % plant_positions.size()]
		target_position = plant_pos + Vector2(randf_range(-20, 20), randf_range(10, 30))
	else:
		# Random scurry
		var scurry_distance: float = randf_range(80.0, 200.0)
		var angle: float = randf_range(-PI, PI)
		target_position = position + Vector2(cos(angle), sin(angle)) * scurry_distance
	
	target_position = _clamp_to_ground_bounds(target_position)
	move_direction = (target_position - position).normalized()
	state_timer = 3.0  # Quick movement


func _start_scurry_to_sun() -> void:
	"""Rush to an open sunny spot for basking."""
	current_state = CreatureState.MOVING
	
	# Pick a random open spot (avoid plants for basking)
	var scurry_distance: float = randf_range(60.0, 150.0)
	var angle: float = randf_range(-PI, PI)
	target_position = position + Vector2(cos(angle), sin(angle)) * scurry_distance
	target_position = _clamp_to_ground_bounds(target_position)
	
	move_direction = (target_position - position).normalized()
	state_timer = 3.0


func _start_soar() -> void:
	"""Start soaring through the sky."""
	current_state = CreatureState.MOVING
	
	# Decide if staying in sky or landing
	if randf() < 0.2 and current_altitude > 0.5:
		# Land in a tree
		target_altitude = 0.0
		var tree_positions: Array = _get_tree_positions()
		if tree_positions.size() > 0:
			target_position = tree_positions[randi() % tree_positions.size()]
			target_position.y = randf_range(TREE_Y_RANGE.x, TREE_Y_RANGE.y)
		else:
			target_position = Vector2(
				randf_range(SCREEN_MARGIN, SCREEN_WIDTH - SCREEN_MARGIN),
				randf_range(TREE_Y_RANGE.x, TREE_Y_RANGE.y)
			)
	else:
		# Continue soaring
		target_altitude = randf_range(0.6, 1.0)
		var soar_distance: float = randf_range(200.0, 500.0)
		var angle: float = randf_range(-PI/4, PI/4)  # Mostly horizontal
		if move_direction != Vector2.ZERO:
			angle += move_direction.angle()
		target_position = position + Vector2(cos(angle), sin(angle)) * soar_distance
		target_position.y = lerp(GROUND_Y_MIN, SKY_Y_MIN, target_altitude)
	
	target_position.x = clamp(target_position.x, SCREEN_MARGIN, SCREEN_WIDTH - SCREEN_MARGIN)
	move_direction = (target_position - position).normalized()
	state_timer = 8.0


func _start_flutter() -> void:
	"""Start a short flutter to a new perch."""
	current_state = CreatureState.MOVING
	
	# Pick a nearby perch - plant, tree branch, or ground
	var choice: float = randf()
	
	if choice < 0.4:
		# Flutter to a plant
		var plant_positions: Array = _get_plant_positions()
		if plant_positions.size() > 0:
			target_position = plant_positions[randi() % plant_positions.size()]
			target_position += Vector2(randf_range(-30, 30), randf_range(-50, 0))
		else:
			target_position = _random_flutter_target()
	elif choice < 0.7:
		# Flutter to a tree branch
		var tree_positions: Array = _get_tree_positions()
		if tree_positions.size() > 0:
			target_position = tree_positions[randi() % tree_positions.size()]
			target_position.y = randf_range(TREE_Y_RANGE.x, TREE_Y_RANGE.y)
		else:
			target_position = _random_flutter_target()
	else:
		# Flutter to ground
		target_position = _random_flutter_target()
		target_position.y = randf_range(GROUND_Y_MIN + 100, GROUND_Y_MAX)
	
	target_position = _clamp_to_screen(target_position)
	move_direction = (target_position - position).normalized()
	state_timer = 2.0


func _start_amble_move() -> void:
	"""Start a short ambling walk."""
	current_state = CreatureState.MOVING
	
	# Short distance, random direction (but often changing from previous)
	var amble_distance: float = randf_range(40.0, 100.0)
	var angle: float = randf_range(-PI, PI)
	
	target_position = position + Vector2(cos(angle), sin(angle)) * amble_distance
	target_position = _clamp_to_ground_bounds(target_position)
	
	move_direction = (target_position - position).normalized()
	state_timer = amble_distance / speed + 0.5


func _enter_idle(duration: float) -> void:
	"""Enter idle state for a duration."""
	current_state = CreatureState.IDLE
	state_timer = duration
	velocity = Vector2.ZERO


func _enter_sniffing() -> void:
	"""Enter sniffing state (bilby-specific)."""
	current_state = CreatureState.SNIFFING
	state_timer = randf_range(1.0, 3.0)
	velocity = Vector2.ZERO


# === HELPER FUNCTIONS ===

func _random_flutter_target() -> Vector2:
	"""Get a random position for fluttering."""
	return Vector2(
		position.x + randf_range(-100, 100),
		randf_range(SKY_Y_MAX, GROUND_Y_MAX - 50)
	)


func _clamp_to_ground_bounds(pos: Vector2) -> Vector2:
	"""Clamp position to ground creature bounds."""
	pos.x = clamp(pos.x, SCREEN_MARGIN, SCREEN_WIDTH - SCREEN_MARGIN)
	pos.y = clamp(pos.y, GROUND_Y_MIN, GROUND_Y_MAX)
	return pos


func _clamp_to_screen(pos: Vector2) -> Vector2:
	"""Clamp position to screen bounds."""
	pos.x = clamp(pos.x, SCREEN_MARGIN, SCREEN_WIDTH - SCREEN_MARGIN)
	pos.y = clamp(pos.y, SKY_Y_MIN, GROUND_Y_MAX)
	return pos


func _keep_in_bounds() -> void:
	"""Keep ground creature within bounds, turning if needed."""
	if position.x < SCREEN_MARGIN:
		position.x = SCREEN_MARGIN
		move_direction.x = abs(move_direction.x)
		_update_target_from_direction()
	elif position.x > SCREEN_WIDTH - SCREEN_MARGIN:
		position.x = SCREEN_WIDTH - SCREEN_MARGIN
		move_direction.x = -abs(move_direction.x)
		_update_target_from_direction()
	
	if position.y < GROUND_Y_MIN:
		position.y = GROUND_Y_MIN
		move_direction.y = abs(move_direction.y)
		_update_target_from_direction()
	elif position.y > GROUND_Y_MAX:
		position.y = GROUND_Y_MAX
		move_direction.y = -abs(move_direction.y)
		_update_target_from_direction()


func _keep_in_bounds_flying() -> void:
	"""Keep flying creature within bounds."""
	if position.x < SCREEN_MARGIN:
		position.x = SCREEN_MARGIN
		move_direction.x = abs(move_direction.x)
	elif position.x > SCREEN_WIDTH - SCREEN_MARGIN:
		position.x = SCREEN_WIDTH - SCREEN_MARGIN
		move_direction.x = -abs(move_direction.x)


func _update_target_from_direction() -> void:
	"""Update target position based on current direction."""
	target_position = position + move_direction * 100.0


func _get_plant_positions() -> Array:
	"""Get positions of plants in the ecosystem."""
	var positions: Array = []
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		positions.append(plant.global_position)
	
	# If no plants found, return some default positions
	if positions.is_empty():
		positions = [
			Vector2(200, 500),
			Vector2(500, 450),
			Vector2(800, 550),
			Vector2(1000, 480)
		]
	
	return positions


func _get_tree_positions() -> Array:
	"""Get positions of trees in the ecosystem."""
	var positions: Array = []
	var trees = get_tree().get_nodes_in_group("trees")
	for tree in trees:
		positions.append(tree.global_position)
	
	# If no trees found, return some default positions
	if positions.is_empty():
		positions = [
			Vector2(150, 350),
			Vector2(600, 320),
			Vector2(1100, 380)
		]
	
	return positions


# === ANIMATION ===

func _update_animation() -> void:
	"""Update sprite animation and facing direction."""
#	if velocity == Vector2.ZERO or current_state in [CreatureState.IDLE, CreatureState.RESTING, CreatureState.SNIFFING]:
#		if ap.has_animation(species + "_idle"):
#			if ap.current_animation != species + "_idle":
#				ap.play(species + "_idle")
#		else:
#			ap.stop()
#	else:
#		if ap.has_animation(species):
#			if ap.current_animation != species:
#				ap.play(species)
#	if ap.has_animation(species):
#		print("animation " + species + " found.")
#	else:
#		print("animation " + species + " not found.")

	ap.play(species)
	# Flip sprite based on movement direction
	if velocity.x < -0.1:
		sprite.flip_h = true
	elif velocity.x > 0.1:
		sprite.flip_h = false


# === PUBLIC API ===

func set_nearby_plants(plants: Array) -> void:
	"""Update reference to nearby plants for hide/flutter behaviors."""
	nearby_plants = plants


func force_idle(duration: float = 2.0) -> void:
	"""Force creature into idle state."""
	_enter_idle(duration)


func is_moving() -> bool:
	"""Check if creature is currently moving."""
	return current_state == CreatureState.MOVING
