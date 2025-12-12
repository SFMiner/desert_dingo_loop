# organism_bubble.gd
# A draggable organism bubble that can be placed in the ecosystem
# Shows visual feedback for health status and food availability

extends Control
class_name OrganismBubble

# === SIGNALS ===

signal drag_started(bubble: OrganismBubble)
signal drag_ended(bubble: OrganismBubble)
signal placed_in_slot(bubble: OrganismBubble, slot_index: int)
signal returned_to_inventory(bubble: OrganismBubble)

# === CONSTANTS ===

const BUBBLE_SIZE: Vector2 = Vector2(80, 80)
const HOVER_SCALE: float = 1.1
const DRAG_SCALE: float = 1.2

# === STATE ===

var organism_id: int = -1
var instance_id: int = -1  # Set when placed in ecosystem
var is_in_inventory: bool = true
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var slot_index: int = -1

var health_status: int = EcosystemState.HealthStatus.HEALTHY

# === NODE REFERENCES ===

@onready var background: ColorRect = $Background
@onready var icon_label: Label = $IconLabel
@onready var name_label: Label = $NameLabel
@onready var health_indicator: ColorRect = $HealthIndicator
@onready var food_warning: Label = $FoodWarning

# === LIFECYCLE ===

func _ready() -> void:
	custom_minimum_size = BUBBLE_SIZE
	size = BUBBLE_SIZE
	
	# Connect mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	_update_visuals()


func _process(_delta: float) -> void:
	if is_dragging:
		# Follow mouse
		global_position = get_global_mouse_position() - drag_offset


# === SETUP ===

func setup_from_organism_id(org_id: int) -> void:
	"""Initialize bubble with organism data from constants."""
	organism_id = org_id
	is_in_inventory = true
	instance_id = -1
	slot_index = -1
	health_status = EcosystemState.HealthStatus.HEALTHY
	_update_visuals()


func setup_from_instance(inst_id: int) -> void:
	"""Initialize bubble from an existing ecosystem instance."""
	instance_id = inst_id
	is_in_inventory = false
	
	var inst_data: Dictionary = EcosystemState.get_organism_instance(inst_id)
	if inst_data.is_empty():
		push_error("Invalid instance ID: " + str(inst_id))
		return
	
	organism_id = inst_data.get("organism_id", -1)
	slot_index = inst_data.get("slot_index", -1)
	health_status = inst_data.get("health_status", EcosystemState.HealthStatus.HEALTHY)
	_update_visuals()


# === VISUALS ===

func _update_visuals() -> void:
	"""Update all visual elements based on organism data."""
	if organism_id < 0:
		return
	
	var org_data: Dictionary = EcosystemConstants.get_organism_data(organism_id)
	if org_data.is_empty():
		return
	
	# Background color based on organism
	if background:
		background.color = org_data.get("color", Color.WHITE)
	
	# Icon emoji
	if icon_label:
		icon_label.text = org_data.get("icon_char", "?")
	
	# Name label
	if name_label:
		name_label.text = org_data.get("short_name", "???")
	
	# Health indicator
	_update_health_indicator()
	
	# Food warning (hidden by default)
	if food_warning:
		food_warning.visible = false


func _update_health_indicator() -> void:
	"""Update the health indicator color based on status."""
	if not health_indicator:
		return
	
	match health_status:
		EcosystemState.HealthStatus.HEALTHY:
			health_indicator.color = Color(0.2, 0.8, 0.2, 0.8)  # Green
			health_indicator.visible = true
		EcosystemState.HealthStatus.HUNGRY:
			health_indicator.color = Color(0.9, 0.6, 0.1, 0.8)  # Orange
			health_indicator.visible = true
		EcosystemState.HealthStatus.DEAD:
			health_indicator.color = Color(0.8, 0.2, 0.2, 0.8)  # Red
			health_indicator.visible = true


func show_food_warning(can_feed: bool) -> void:
	"""Show/hide the food availability warning."""
	if food_warning:
		food_warning.visible = not can_feed
		if not can_feed:
			food_warning.text = "⚠️"
			food_warning.modulate = Color.RED


func set_highlighted(highlighted: bool, color: Color = Color.WHITE) -> void:
	"""Set highlight state for food chain visualization."""
	if background:
		if highlighted:
			background.modulate = color
		else:
			background.modulate = Color.WHITE


func play_bob_animation() -> void:
	"""Play happy bobbing animation for healthy organisms."""
	var tween: Tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "position:y", position.y - 5, 0.15)
	tween.tween_property(self, "position:y", position.y, 0.15)


func play_death_animation() -> void:
	"""Play poof animation when organism dies."""
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)


# === INPUT HANDLING ===

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_drag()
			else:
				_end_drag()
	
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		
		if touch_event.pressed:
			_start_drag()
		else:
			_end_drag()


func _start_drag() -> void:
	"""Begin dragging the bubble."""
	if not is_in_inventory:
		return  # Can't drag placed organisms
	
	is_dragging = true
	original_position = global_position
	drag_offset = get_local_mouse_position()
	
	# Visual feedback
	scale = Vector2(DRAG_SCALE, DRAG_SCALE)
	z_index = 100  # Bring to front
	
	# Show food availability preview
	var preview: Dictionary = EcosystemState.preview_food_availability(organism_id)
	show_food_warning(preview.get("can_feed", true))
	
	drag_started.emit(self)
	AudioManager.play_click_sound()


func _end_drag() -> void:
	"""End dragging the bubble."""
	if not is_dragging:
		return
	
	is_dragging = false
	scale = Vector2.ONE
	z_index = 0
	
	# Hide food warning
	show_food_warning(true)
	
	drag_ended.emit(self)


func snap_to_position(pos: Vector2) -> void:
	"""Snap bubble to a specific position (for slot placement)."""
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", pos, 0.15)


func return_to_original() -> void:
	"""Return bubble to its original position."""
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", original_position, 0.2)
	returned_to_inventory.emit(self)


# === HOVER EFFECTS ===

func _on_mouse_entered() -> void:
	if not is_dragging:
		scale = Vector2(HOVER_SCALE, HOVER_SCALE)
		
		# Show food preview on hover
		if is_in_inventory:
			var preview: Dictionary = EcosystemState.preview_food_availability(organism_id)
			show_food_warning(preview.get("can_feed", true))
		
		AudioManager.play_hover_sound()


func _on_mouse_exited() -> void:
	if not is_dragging:
		scale = Vector2.ONE
		show_food_warning(true)  # Hide warning


# === GETTERS ===

func get_organism_data() -> Dictionary:
	"""Get the organism's constant data."""
	return EcosystemConstants.get_organism_data(organism_id)


func get_trophic_level() -> int:
	"""Get the organism's trophic level."""
	var data: Dictionary = get_organism_data()
	return data.get("trophic_level", -1)
