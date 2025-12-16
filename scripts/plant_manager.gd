# plant_manager.gd
# Manages spawning and tracking of static plant sprites in the desert
# Plants are visual representations of producer organisms in the ecosystem

extends Node2D
class_name PlantManager

# === SIGNALS ===

signal plant_spawned(plant: Plant)
signal plant_removed(plant: Plant)

# === PRELOADS ===

var PlantScene: PackedScene = preload("res://scenes/Plant.tscn")

# === STATE ===

var plants: Dictionary = {}  # instance_id -> Plant

# Mapping from organism_id to species string
var ORGANISM_TO_SPECIES: Dictionary = {}

# === LIFECYCLE ===

func _ready() -> void:
	_setup_organism_mapping()

	# Connect to ecosystem state
	EcosystemState.organism_added.connect(_on_organism_added)
	EcosystemState.organism_removed.connect(_on_organism_removed)
	EcosystemState.simulation_complete.connect(_on_simulation_complete)


func _setup_organism_mapping() -> void:
	"""Map organism IDs to species strings for plant spawning."""
	ORGANISM_TO_SPECIES = {
		EcosystemConstants.OrganismID.SPINIFEX_GRASS: "spinifex",
		EcosystemConstants.OrganismID.NEVERFAIL_GRASS: "neverfail",
		EcosystemConstants.OrganismID.STURTS_DESERT_PEA: "desert_pea",
		EcosystemConstants.OrganismID.MULGA_TREE: "mulga",
		EcosystemConstants.OrganismID.BLOODWOOD_TREE: "bloodwood"
	}


# === SPAWNING ===

func spawn_plant_for_organism(instance_id: int) -> Plant:
	"""Spawn a static plant sprite for an organism instance."""
	var org_data: Dictionary = EcosystemState.get_organism_instance(instance_id)
	if org_data.is_empty():
		return null

	var organism_id: int = org_data.get("organism_id", -1)

	# Check if this is a plant (producer)
	if not ORGANISM_TO_SPECIES.has(organism_id):
		return null  # Not a plant

	var species: String = ORGANISM_TO_SPECIES[organism_id]
	var slot_index: int = org_data.get("slot_index", -1)

	# Calculate spawn position from slot
	var spawn_pos: Vector2 = _get_position_from_slot(slot_index)

	# Create plant
	var plant: Plant = PlantScene.instantiate()
	add_child(plant)
	plant.setup(species, organism_id, instance_id, spawn_pos)

	plants[instance_id] = plant
	plant_spawned.emit(plant)

	return plant


func _get_position_from_slot(slot_index: int) -> Vector2:
	"""Convert slot index to a world position for plant spawning."""
	# Grid is 10 columns x 5 rows
	var col: int = slot_index % 10
	var row: int = slot_index / 10

	# Map to screen coordinates - match the slot grid positioning in desert_room.gd
	var grid_width: float = 10 * 100.0  # SLOT_COLS * SLOT_SPACING
	var base_x: float = (1120.0 - grid_width) / 2.0  # Use full screen width
	var base_y: float = 130.0
	var spacing_x: float = 100.0
	var spacing_y: float = 100.0

	var pos: Vector2 = Vector2(
		base_x + col * spacing_x + 45.0 + randf_range(-15, 15),  # 45 = half slot width, small random offset
		base_y + row * spacing_y + 45.0 + randf_range(-15, 15)   # Center in slot
	)

	return pos


# === REMOVAL ===

func remove_plant(instance_id: int) -> void:
	"""Remove a plant from the scene."""
	if plants.has(instance_id):
		var plant: Plant = plants[instance_id]
		plant_removed.emit(plant)
		plant.queue_free()
		plants.erase(instance_id)


func remove_all_plants() -> void:
	"""Remove all plants."""
	for instance_id in plants.keys():
		remove_plant(instance_id)


# === EVENT HANDLERS ===

func _on_organism_added(instance_id: int) -> void:
	"""Handle organism added to ecosystem."""
	# Small delay to let the UI settle
	await get_tree().create_timer(0.2).timeout
	spawn_plant_for_organism(instance_id)


func _on_organism_removed(instance_id: int) -> void:
	"""Handle organism removed from ecosystem."""
	if plants.has(instance_id):
		var plant: Plant = plants[instance_id]
		# Play fade-out animation before removing
		_play_plant_death(plant)
		await get_tree().create_timer(0.5).timeout
		remove_plant(instance_id)


func _on_simulation_complete(results: Dictionary) -> void:
	"""Handle simulation completion - animate reactions."""
	var healthy: Array = results.get("healthy", [])

	# Make healthy plants sway slightly
	for instance_id in healthy:
		if plants.has(instance_id):
			_play_plant_happy(plants[instance_id])


func _play_plant_death(plant: Plant) -> void:
	"""Play death/wither animation on plant."""
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(plant, "modulate:a", 0.0, 0.4)
	tween.tween_property(plant, "scale", Vector2(0.8, 0.8), 0.4)


func _play_plant_happy(plant: Plant) -> void:
	"""Play subtle sway animation on plant."""
	var original_rotation: float = plant.rotation

	var tween: Tween = create_tween()
	tween.tween_property(plant, "rotation", original_rotation + 0.05, 0.2)
	tween.tween_property(plant, "rotation", original_rotation - 0.05, 0.2)
	tween.tween_property(plant, "rotation", original_rotation, 0.2)


# === UTILITIES ===

func get_plant_for_instance(instance_id: int) -> Plant:
	"""Get plant by organism instance ID."""
	return plants.get(instance_id, null)


func get_all_plants() -> Array:
	"""Get all active plants."""
	return plants.values()


func sync_with_ecosystem() -> void:
	"""Sync plants with current ecosystem state."""
	# Remove plants for organisms that no longer exist
	var to_remove: Array = []
	for instance_id in plants.keys():
		if EcosystemState.get_organism_instance(instance_id).is_empty():
			to_remove.append(instance_id)

	for instance_id in to_remove:
		remove_plant(instance_id)

	# Add plants for organisms that don't have them
	for org in EcosystemState.get_all_organisms():
		var instance_id: int = org.get("instance_id", -1)
		var organism_id: int = org.get("organism_id", -1)

		if instance_id >= 0 and not plants.has(instance_id):
			if ORGANISM_TO_SPECIES.has(organism_id):
				spawn_plant_for_organism(instance_id)
