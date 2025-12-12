# placement_slot.gd
# A slot in the desert where organisms can be placed
# Provides visual feedback for drag-and-drop

extends Control
class_name PlacementSlot

# === SIGNALS ===

signal organism_dropped(slot: PlacementSlot, organism_id: int)

# === CONSTANTS ===

const SLOT_SIZE: Vector2 = Vector2(90, 90)
const HIGHLIGHT_COLOR_VALID: Color = Color(0.2, 0.8, 0.2, 0.4)
const HIGHLIGHT_COLOR_INVALID: Color = Color(0.8, 0.2, 0.2, 0.4)
const HIGHLIGHT_COLOR_FOOD: Color = Color(0.9, 0.7, 0.1, 0.4)

# === STATE ===

var slot_index: int = -1
var is_occupied: bool = false
var organism_instance_id: int = -1
var is_highlighted: bool = false
var highlight_color: Color = Color.TRANSPARENT

# === NODE REFERENCES ===

@onready var background: ColorRect = $Background
@onready var highlight: ColorRect = $Highlight
@onready var slot_label: Label = $SlotLabel

# === LIFECYCLE ===

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_update_visuals()


# === SETUP ===

func setup(index: int) -> void:
	"""Initialize the slot with its index."""
	slot_index = index
	is_occupied = false
	organism_instance_id = -1
	
	if slot_label:
		slot_label.text = ""  # Don't show slot numbers to keep it simple
	
	_update_visuals()


# === VISUALS ===

func _update_visuals() -> void:
	"""Update visual state."""
	if background:
		if is_occupied:
			background.color = Color(0.6, 0.502, 0.4, 0.569)  # Slightly darker when occupied
		else:
			background.color = Color(0.8, 0.698, 0.502, 0.482)  # Light sand color
	
	if highlight:
		highlight.visible = is_highlighted
		highlight.color = highlight_color


func set_highlight(enabled: bool, color: Color = HIGHLIGHT_COLOR_VALID) -> void:
	"""Set the highlight state of this slot."""
	is_highlighted = enabled
	highlight_color = color
	_update_visuals()


func show_valid_drop_zone() -> void:
	"""Show this slot as a valid drop target."""
	set_highlight(true, HIGHLIGHT_COLOR_VALID)


func show_invalid_drop_zone() -> void:
	"""Show this slot as an invalid drop target."""
	set_highlight(true, HIGHLIGHT_COLOR_INVALID)


func show_food_source() -> void:
	"""Highlight this slot as containing a food source."""
	set_highlight(true, HIGHLIGHT_COLOR_FOOD)


func clear_highlight() -> void:
	"""Remove all highlighting."""
	set_highlight(false)


# === SLOT STATE ===

func occupy(instance_id: int) -> void:
	"""Mark this slot as occupied by an organism."""
	is_occupied = true
	organism_instance_id = instance_id
	_update_visuals()


func clear() -> void:
	"""Clear this slot."""
	is_occupied = false
	organism_instance_id = -1
	_update_visuals()


func can_accept_drop() -> bool:
	"""Check if this slot can accept a dropped organism."""
	return not is_occupied


# === INPUT HANDLING ===

func _on_mouse_entered() -> void:
	"""Handle mouse entering slot area."""
	if not is_occupied:
		# Light hover effect
		if background:
			background.color = Color(0.9, 0.8, 0.6, 0.3)


func _on_mouse_exited() -> void:
	"""Handle mouse leaving slot area."""
	_update_visuals()


func try_drop(bubble: OrganismBubble) -> bool:
	"""
	Attempt to drop an organism bubble into this slot.
	Returns true if successful.
	"""
	if is_occupied:
		return false
	
	if bubble == null or bubble.organism_id < 0:
		return false
	
	# Check if there's enough food for this organism
	var preview: Dictionary = EcosystemState.preview_food_availability(bubble.organism_id)
	
	# Allow placement even without food - the organism will just die during simulation
	# This teaches cause and effect
	
	organism_dropped.emit(self, bubble.organism_id)
	return true


# === GETTERS ===

func get_center_position() -> Vector2:
	"""Get the center position of this slot in global coordinates."""
	return global_position + (size / 2.0)


func get_organism_instance() -> Dictionary:
	"""Get the organism instance data if occupied."""
	if not is_occupied or organism_instance_id < 0:
		return {}
	return EcosystemState.get_organism_instance(organism_instance_id)
