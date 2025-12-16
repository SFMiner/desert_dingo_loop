# creature_manager.gd
# Manages spawning and tracking of animated creatures in the desert
# Creatures are visual representations of organisms in the ecosystem

extends Node2D
class_name CreatureManager

# === SIGNALS ===

signal creature_spawned(creature: Creature)
signal creature_removed(creature: Creature)

# === PRELOADS ===

var CreatureScene: PackedScene = preload("res://scenes/Creature.tscn")

# === STATE ===

var creatures: Dictionary = {}  # instance_id -> Creature
var sprite_sheets: Dictionary = {}  # species -> Texture2D

# Species that are animals (not plants)
const ANIMAL_SPECIES: Array = [
	"dingo", "kangaroo", "ant", "termite", "bilby", 
	"sf_mouse", "thorny_devil", "eagle", "honeyeater"
]

# Mapping from organism_id to species string
var ORGANISM_TO_SPECIES: Dictionary = {}

# === LIFECYCLE ===

func _ready() -> void:
	_setup_organism_mapping()
#	_load_sprite_sheets()
	
	# Connect to ecosystem state
	EcosystemState.organism_added.connect(_on_organism_added)
	EcosystemState.organism_removed.connect(_on_organism_removed)
	EcosystemState.simulation_complete.connect(_on_simulation_complete)


func _setup_organism_mapping() -> void:
	"""Map organism IDs to species strings for creature spawning."""
	ORGANISM_TO_SPECIES = {
		EcosystemConstants.OrganismID.DINGO: "dingo",
		EcosystemConstants.OrganismID.RED_KANGAROO: "kangaroo",
		EcosystemConstants.OrganismID.ANT: "ant",
		EcosystemConstants.OrganismID.TERMITE: "termite",
		EcosystemConstants.OrganismID.BILBY: "bilby",
		EcosystemConstants.OrganismID.SPINIFEX_MOUSE: "sf_mouse",
		EcosystemConstants.OrganismID.THORNY_DEVIL: "thorny_devil",
		EcosystemConstants.OrganismID.WEDGE_TAILED_EAGLE: "eagle",
		EcosystemConstants.OrganismID.HONEYEATER: "honeyeater"
	}


#func _load_sprite_sheets() -> void:
#	"""Load sprite sheets for each species (if they exist)."""
#	for species in ANIMAL_SPECIES:
#		var path: String = "res://assets/sprites/%s.png" % species
#		if ResourceLoader.exists(path):
#			sprite_sheets[species] = load(path)
#		else:
			# Will use placeholder
#			sprite_sheets[species] = null


# === SPAWNING ===


func spawn_creature_for_organism(instance_id: int) -> Creature:
	"""Spawn an animated creature for an organism instance."""
	var org_data: Dictionary = EcosystemState.get_organism_instance(instance_id)
	if org_data.is_empty():
		return null
	
	var organism_id: int = org_data.get("organism_id", -1)
	
	# Check if this is an animal (not a plant)
	if not ORGANISM_TO_SPECIES.has(organism_id):
		return null  # Plants don't get creatures
	
	var species: String = ORGANISM_TO_SPECIES[organism_id]
		
	var slot_index: int = org_data.get("slot_index", -1)
	
	# Calculate spawn position from slot
	var spawn_pos: Vector2 = _get_position_from_slot(slot_index)
	
	# Create creature
	var creature: Creature = CreatureScene.instantiate()
	#print("Spawning creature: " + str(creature.get_property_list()))
	
	add_child(creature)
	creature.setup(species, spawn_pos)
	
	# Setup sprite sheet if available
	#_setup_creature_sprite(creature, species)
	
	creatures[instance_id] = creature
	creature_spawned.emit(creature)
	
	return creature


func _setup_creature_sprite(creature: Creature, species: String) -> void:
	"""Configure creature's sprite with the appropriate sprite sheet."""
	if sprite_sheets.has(species) and sprite_sheets[species] != null:
		creature.sprite.texture = sprite_sheets[species]
		_setup_sprite_frames(creature, species)
	else:
		# Use placeholder colored rectangle
		_setup_placeholder_sprite(creature, species)


func _setup_sprite_frames(creature: Creature, species: String) -> void:
	"""Setup sprite sheet frames based on species."""
	# These values should match your actual sprite sheets
	# Adjust hframes/vframes based on your sprite sheet layout
	match species:
		"dingo":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		"kangaroo":
			creature.sprite.hframes = 6
			creature.sprite.vframes = 2
		"ant", "termite":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 1
		"bilby":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		"sf_mouse":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		"thorny_devil":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		"eagle":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		"honeyeater":
			creature.sprite.hframes = 4
			creature.sprite.vframes = 2
		_:
			creature.sprite.hframes = 1
			creature.sprite.vframes = 1


func _setup_placeholder_sprite(creature: Creature, species: String) -> void:
	"""Create a placeholder colored sprite for species without sprite sheets."""
	# Get color from constants
	var org_id: int = -1
	for id in ORGANISM_TO_SPECIES.keys():
		if ORGANISM_TO_SPECIES[id] == species:
			org_id = id
			break
	
	var color: Color = Color.WHITE
	if org_id >= 0:
		var org_data: Dictionary = EcosystemConstants.get_organism_data(org_id)
		color = org_data.get("color", Color.WHITE)
	
	# Create a simple colored texture
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	creature.sprite.texture = texture


func _get_position_from_slot(slot_index: int) -> Vector2:
	"""Convert slot index to a world position for creature spawning."""
	# Grid is 5 columns x 4 rows
	# Grid starts at x=140 (centered) and y=120
	var col: int = slot_index % 10
	var row: int = slot_index / 10
	
	# Map to screen coordinates - match the slot grid positioning in desert_room.gd
	var grid_width: float = 5 * 100.0  # SLOT_COLS * SLOT_SPACING
	var base_x: float = (1280.0 - grid_width) / 2.0
	var base_y: float = 120.0
	var spacing_x: float = 100.0
	var spacing_y: float = 100.0
	
	var pos: Vector2 = Vector2(
		base_x + col * spacing_x + 45.0 + randf_range(-20, 20),  # 45 = half slot width
		base_y + row * spacing_y + 45.0 + randf_range(-20, 20)   # Center in slot
	)
	
	return pos


# === REMOVAL ===

func remove_creature(instance_id: int) -> void:
	"""Remove a creature from the scene."""
	if creatures.has(instance_id):
		var creature: Creature = creatures[instance_id]
		creature_removed.emit(creature)
		creature.queue_free()
		creatures.erase(instance_id)


func remove_all_creatures() -> void:
	"""Remove all creatures."""
	for instance_id in creatures.keys():
		remove_creature(instance_id)


# === EVENT HANDLERS ===

func _on_organism_added(instance_id: int) -> void:
	"""Handle organism added to ecosystem."""
	# Small delay to let the UI settle
	await get_tree().create_timer(0.2).timeout
	spawn_creature_for_organism(instance_id)


func _on_organism_removed(instance_id: int) -> void:
	"""Handle organism removed from ecosystem."""
	if creatures.has(instance_id):
		var creature: Creature = creatures[instance_id]
		# Play death animation before removing
		_play_creature_death(creature)
		await get_tree().create_timer(0.5).timeout
		remove_creature(instance_id)


func _on_simulation_complete(results: Dictionary) -> void:
	"""Handle simulation completion - animate reactions."""
	var healthy: Array = results.get("healthy", [])
	var dead: Array = results.get("dead", [])
	
	# Make healthy creatures do a happy animation
	for instance_id in healthy:
		if creatures.has(instance_id):
			_play_creature_happy(creatures[instance_id])
	
	# Dead creatures handled by _on_organism_removed


func _play_creature_death(creature: Creature) -> void:
	"""Play death/poof animation on creature."""
	creature.force_idle()
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(creature, "modulate:a", 0.0, 0.4)
	tween.tween_property(creature, "scale", Vector2(0.5, 0.5), 0.4)


func _play_creature_happy(creature: Creature) -> void:
	"""Play happy animation on creature."""
	var original_scale: Vector2 = creature.scale
	
	var tween: Tween = create_tween()
	tween.tween_property(creature, "scale", original_scale * 1.2, 0.15)
	tween.tween_property(creature, "scale", original_scale, 0.15)


# === UTILITIES ===

func get_creature_for_instance(instance_id: int) -> Creature:
	"""Get creature by organism instance ID."""
	return creatures.get(instance_id, null)


func get_all_creatures() -> Array:
	"""Get all active creatures."""
	return creatures.values()


func sync_with_ecosystem() -> void:
	"""Sync creatures with current ecosystem state."""
	# Remove creatures for organisms that no longer exist
	var to_remove: Array = []
	for instance_id in creatures.keys():
		if EcosystemState.get_organism_instance(instance_id).is_empty():
			to_remove.append(instance_id)
	
	for instance_id in to_remove:
		remove_creature(instance_id)
	
	# Add creatures for organisms that don't have them
	for org in EcosystemState.get_all_organisms():
		var instance_id: int = org.get("instance_id", -1)
		var organism_id: int = org.get("organism_id", -1)
		
		if instance_id >= 0 and not creatures.has(instance_id):
			if ORGANISM_TO_SPECIES.has(organism_id):
				spawn_creature_for_organism(instance_id)
