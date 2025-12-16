# plant.gd
# Static plant sprite that appears in the desert
# Z-index is based on Y position for depth sorting

extends Node2D
class_name Plant

# === EXPORTS ===

@export var species: String = ""

# === NODE REFERENCES ===

@onready var sprite: Sprite2D = $Sprite2D

# === STATE ===

var organism_id: int = -1
var instance_id: int = -1

# === LIFECYCLE ===

func _ready() -> void:
	_update_z_index()


func _process(_delta: float) -> void:
	_update_z_index()


# === SETUP ===

func setup(org_species: String, org_id: int, inst_id: int, pos: Vector2) -> void:
	"""Initialize plant with species, IDs, and position."""
	species = org_species
	organism_id = org_id
	instance_id = inst_id
	position = pos

	# Load sprite
	_load_sprite()

	# Add to appropriate group
	_add_to_group()

	_update_z_index()


func _load_sprite() -> void:
	"""Load the sprite texture based on organism data."""
	var org_data: Dictionary = EcosystemConstants.get_organism_data(organism_id)
	if org_data.is_empty():
		return

	var sprite_filename: String = org_data.get("sprite_filename", "")
	if sprite_filename != "":
		var sprite_path: String = "res://assets/spritesheets/" + sprite_filename
		sprite.texture = load(sprite_path)


func _add_to_group() -> void:
	"""Add plant to appropriate group for creature pathfinding."""
	# Determine if this is a tree or regular plant
	var org_data: Dictionary = EcosystemConstants.get_organism_data(organism_id)
	var name: String = org_data.get("name", "").to_lower()

	if "tree" in name:
		add_to_group("trees")
	else:
		add_to_group("plants")


func _update_z_index() -> void:
	"""Update z-index based on Y position for depth sorting."""
	# Higher Y = closer to camera = higher z-index
	z_index = int(position.y)
