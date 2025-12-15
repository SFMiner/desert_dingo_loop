# desert_room.gd
# Main game scene controller
# Manages the desert ecosystem, drag-drop, simulation, and UI

extends Control

# === CONSTANTS ===

const SLOT_ROWS: int = 5
const SLOT_COLS: int = 10	
const SLOT_SPACING: Vector2 = Vector2(100, 100)

# === PRELOADS ===

var OrganismBubbleScene: PackedScene = preload("res://scenes/OrganismBubble.tscn")
var PlacementSlotScene: PackedScene = preload("res://scenes/PlacementSlot.tscn")
var music_on : bool = true
# === NODE REFERENCES ===

@onready var desert_background: ColorRect = $DesertBackground
@onready var slot_grid: Control = %SlotGrid
@onready var organisms_container: Control = $OrganismsContainer
@onready var inventory_bar: Control = $CanvasLayer/InventoryBar
@onready var inventory_container: HBoxContainer = $CanvasLayer/InventoryBar/InventoryContainer
@onready var go_button: Button = $CanvasLayer/GoButton
@onready var day_label: Label = $CanvasLayer/DayLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var summary_panel: Panel = $CanvasLayer/SummaryPanel
@onready var summary_label: Label = $CanvasLayer/SummaryPanel/SummaryLabel
@onready var results_panel: Panel = $CanvasLayer/ResultsPanel
@onready var results_label: Label = $CanvasLayer/ResultsPanel/ResultsLabel
@onready var next_day_button: Button = $CanvasLayer/ResultsPanel/NextDayButton
@onready var menu_button: Button = $CanvasLayer/MenuButton
@onready var food_lines: Control = $FoodLines
@onready var  theme_player = $theme_player
# === STATE ===

var slots: Array[PlacementSlot] = []
var organism_bubbles: Dictionary = {}  # instance_id -> OrganismBubble
var inventory_bubbles: Array[OrganismBubble] = []
var dragged_bubble: OrganismBubble = null
var game_ended: bool = false

# === LIFECYCLE ===

func _ready() -> void:
	# Connect signals
	EcosystemState.day_changed.connect(_on_day_changed)
	EcosystemState.simulation_complete.connect(_on_simulation_complete)
	EcosystemState.game_over.connect(_on_game_over)
	EcosystemState.organism_added.connect(_on_organism_added)
	EcosystemState.organism_removed.connect(_on_organism_removed)
	if music_on: 
		theme_player.play()
	# Setup UI
	_create_slot_grid()
	_update_ui()
	_populate_inventory()
	_sync_existing_organisms()
	
	# Hide results panel
	results_panel.visible = false
	game_ended = false
	
	AudioManager.play_day_start_sound()


func _process(_delta: float) -> void:
	if dragged_bubble != null:
		_update_slot_highlights()


# === SLOT GRID SETUP ===

func _create_slot_grid() -> void:
	"""Create the grid of placement slots."""
	slots.clear()
	
	# Position grid in the upper-center area of the screen
	# Leave room for inventory bar at bottom
	var grid_size: Vector2 = Vector2(SLOT_COLS * SLOT_SPACING.x, SLOT_ROWS * SLOT_SPACING.y)
	var start_pos: Vector2 = Vector2(
		(680.0 - grid_size.x) / 2.0,  # Center horizontally
		80.0  # Start below top UI
	)
	
	for row in range(SLOT_ROWS):
		for col in range(SLOT_COLS):
			var slot_index: int = row * SLOT_COLS + col
			var slot: PlacementSlot = PlacementSlotScene.instantiate()
			slot_grid.add_child(slot)
			slot.setup(slot_index)
			slot.position = start_pos + Vector2(col * SLOT_SPACING.x, row * SLOT_SPACING.y)
			slot.organism_dropped.connect(_on_organism_dropped)
			slots.append(slot)


func _sync_existing_organisms() -> void:
	"""Sync the display with organisms already in EcosystemState."""
	for org in EcosystemState.get_all_organisms():
		var instance_id: int = org.get("instance_id", -1)
		var slot_index: int = org.get("slot_index", -1)
		
		if instance_id >= 0 and slot_index >= 0 and slot_index < slots.size():
			_create_organism_bubble_at_slot(instance_id, slot_index)


func _create_organism_bubble_at_slot(instance_id: int, slot_index: int) -> void:
	"""Create a bubble for an organism in the ecosystem."""
	if slot_index < 0 or slot_index >= slots.size():
		return
	
	var slot: PlacementSlot = slots[slot_index]
	
	var bubble: OrganismBubble = OrganismBubbleScene.instantiate()
	organisms_container.add_child(bubble)
	bubble.setup_from_instance(instance_id)
	bubble.is_in_inventory = false
	bubble.global_position = slot.get_center_position() - (bubble.size / 2.0)
	
	organism_bubbles[instance_id] = bubble
	slot.occupy(instance_id)


# === INVENTORY MANAGEMENT ===

func _populate_inventory() -> void:
	"""Populate the inventory bar with current draft organisms."""
	_clear_inventory()
	
	var draft: Array = EcosystemState.get_current_draft()
	
	for organism_id in draft:
		var bubble: OrganismBubble = OrganismBubbleScene.instantiate()
		inventory_container.add_child(bubble)
		bubble.setup_from_organism_id(organism_id)
		bubble.is_in_inventory = true
		
		bubble.drag_started.connect(_on_bubble_drag_started)
		bubble.drag_ended.connect(_on_bubble_drag_ended)
		
		inventory_bubbles.append(bubble)


func _clear_inventory() -> void:
	"""Clear all inventory bubbles."""
	for bubble in inventory_bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	inventory_bubbles.clear()


# === DRAG AND DROP ===

func _on_bubble_drag_started(bubble: OrganismBubble) -> void:
	"""Handle start of bubble drag."""
	dragged_bubble = bubble
	
	# Reparent to ensure it renders on top
	var global_pos: Vector2 = bubble.global_position
	bubble.get_parent().remove_child(bubble)
	organisms_container.add_child(bubble)
	bubble.global_position = global_pos


func _on_bubble_drag_ended(bubble: OrganismBubble) -> void:
	"""Handle end of bubble drag."""
	if dragged_bubble != bubble:
		return
	
	# Clear all highlights
	_clear_slot_highlights()
	
	# Find the slot under the mouse
	var drop_slot: PlacementSlot = _get_slot_under_mouse()
	
	if drop_slot != null and drop_slot.can_accept_drop():
		# Try to place the organism
		if drop_slot.try_drop(bubble):
			# Remove from inventory
			inventory_bubbles.erase(bubble)
			EcosystemState.use_draft_organism(bubble.organism_id)
		else:
			bubble.return_to_original()
	else:
		bubble.return_to_original()
	
	dragged_bubble = null
	_update_summary()


func _on_organism_dropped(slot: PlacementSlot, organism_id: int) -> void:
	"""Handle organism being dropped into a slot."""
	var instance_id: int = EcosystemState.add_organism_to_ecosystem(organism_id, slot.slot_index)
	
	if instance_id >= 0:
		AudioManager.play_place_sound()
		_update_summary()
	else:
		push_error("Failed to add organism to ecosystem")


func _update_slot_highlights() -> void:
	"""Update slot highlights during drag."""
	if dragged_bubble == null:
		return
	
	var preview: Dictionary = EcosystemState.preview_food_availability(dragged_bubble.organism_id)
	var can_feed: bool = preview.get("can_feed", true)
	var food_sources: Array = preview.get("food_sources", [])
	
	for slot in slots:
		if slot.is_occupied:
			var org: Dictionary = slot.get_organism_instance()
			if org.get("instance_id", -1) in food_sources:
				slot.show_food_source()
			else:
				slot.clear_highlight()
		else:
			if _is_mouse_over_slot(slot):
				if can_feed:
					slot.show_valid_drop_zone()
				else:
					slot.show_invalid_drop_zone()
			else:
				slot.clear_highlight()


func _clear_slot_highlights() -> void:
	"""Clear all slot highlights."""
	for slot in slots:
		slot.clear_highlight()


func _get_slot_under_mouse() -> PlacementSlot:
	"""Get the slot under the current mouse position."""
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	for slot in slots:
		if _is_point_in_slot(mouse_pos, slot):
			return slot
	
	return null


func _is_mouse_over_slot(slot: PlacementSlot) -> bool:
	"""Check if mouse is over a specific slot."""
	return _is_point_in_slot(get_global_mouse_position(), slot)


func _is_point_in_slot(point: Vector2, slot: PlacementSlot) -> bool:
	"""Check if a point is within a slot's bounds."""
	var rect: Rect2 = Rect2(slot.global_position, slot.size)
	return rect.has_point(point)


# === UI UPDATES ===

func _update_ui() -> void:
	"""Update all UI elements."""
	day_label.text = "Day %d of %d" % [EcosystemState.current_day, EcosystemConstants.TOTAL_DAYS]
	score_label.text = "Score: %d" % EcosystemState.total_score
	_update_summary()


func _update_summary() -> void:
	"""Update the ecosystem summary panel."""
	var summary: Dictionary = EcosystemState.get_ecosystem_summary()
	
	summary_label.text = "🌿 Plants: %d\n🐰 Herbivores: %d\n🦊 Predators: %d\n\n📍 Empty: %d" % [
		summary.get("producers", 0),
		summary.get("primary_consumers", 0),
		summary.get("secondary_consumers", 0),
		summary.get("empty_slots", 0)
	]


# === SIMULATION ===

func _on_go_button_pressed() -> void:
	"""Handle GO button press - run simulation."""
	AudioManager.play_click_sound()
	go_button.disabled = true
	
	var results: Dictionary = EcosystemState.run_simulation()
	_show_food_connections(results.get("food_connections", []))


func _show_food_connections(connections: Array) -> void:
	"""Show visual lines connecting eaters to food."""
	for child in food_lines.get_children():
		child.queue_free()
	
	for connection in connections:
		var eater_id: int = connection.get("eater_id", -1)
		var food_id: int = connection.get("food_id", -1)
		
		if organism_bubbles.has(eater_id) and organism_bubbles.has(food_id):
			var eater_bubble: OrganismBubble = organism_bubbles[eater_id]
			var food_bubble: OrganismBubble = organism_bubbles[food_id]
			
			var line: Line2D = Line2D.new()
			line.add_point(eater_bubble.global_position + eater_bubble.size / 2.0)
			line.add_point(food_bubble.global_position + food_bubble.size / 2.0)
			line.width = 3.0
			line.default_color = Color(0.9, 0.6, 0.1, 0.7)
			food_lines.add_child(line)
	
	await get_tree().create_timer(1.5).timeout
	for child in food_lines.get_children():
		child.queue_free()


func _on_simulation_complete(results: Dictionary) -> void:
	"""Handle simulation completion."""
	var healthy: Array = results.get("healthy", [])
	var dead: Array = results.get("dead", [])
	var dead_names: Array = results.get("dead_names", [])
	var day_score: int = results.get("day_score", 0)
	
	# Play happy animation for healthy organisms
	for instance_id in healthy:
		if organism_bubbles.has(instance_id):
			organism_bubbles[instance_id].play_bob_animation()
	
	if healthy.size() > 0:
		AudioManager.play_eat_sound()
	
	# Play death animation for dead organisms
	for instance_id in dead:
		if organism_bubbles.has(instance_id):
			organism_bubbles[instance_id].play_death_animation()
	
	if dead.size() > 0:
		AudioManager.play_starve_sound()
	
	# Wait for animations to complete
	await get_tree().create_timer(0.8).timeout
	
	# NOW remove the dead organisms from ecosystem (after animation)
	EcosystemState.remove_pending_dead()
	
	# Clean up references to dead bubbles
	for instance_id in dead:
		if organism_bubbles.has(instance_id):
			organism_bubbles.erase(instance_id)
	
	_show_results(healthy.size(), dead.size(), dead_names, day_score)


func _show_results(healthy_count: int, dead_count: int, dead_names: Array, day_score: int) -> void:
	"""Show the results panel."""
	var result_text: String = "Day %d Results\n\n" % EcosystemState.current_day
	result_text += "✅ Healthy: %d\n" % healthy_count
	
	if dead_count > 0:
		result_text += "💀 Starved: %d\n" % dead_count
		# List the names of dead organisms
		for dead_name in dead_names:
			result_text += "   • %s\n" % dead_name
	
	result_text += "\n🏆 Points: +%d" % day_score
	
	results_label.text = result_text
	results_panel.visible = true
	
	if EcosystemState.current_day >= EcosystemConstants.TOTAL_DAYS:
		next_day_button.text = "See Final Results"
	else:
		next_day_button.text = "Next Day ☀️"


func _on_next_day_button_pressed() -> void:
	"""Handle next day button press."""
	AudioManager.play_click_sound()
	results_panel.visible = false
	
	if game_ended:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	
	EcosystemState.advance_to_next_day()
	
	if EcosystemState.game_active:
		go_button.disabled = false
		_populate_inventory()
		_update_ui()
		AudioManager.play_day_start_sound()


# === STATE CHANGE HANDLERS ===

func _on_day_changed(new_day: int) -> void:
	"""Handle day change."""
	_update_ui()


func _on_organism_added(instance_id: int) -> void:
	"""Handle organism being added to ecosystem."""
	var org: Dictionary = EcosystemState.get_organism_instance(instance_id)
	var slot_index: int = org.get("slot_index", -1)
	
	for bubble in organisms_container.get_children():
		if bubble is OrganismBubble and bubble.organism_id == org.get("organism_id", -1) and bubble.is_in_inventory:
			bubble.instance_id = instance_id
			bubble.is_in_inventory = false
			bubble.slot_index = slot_index
			organism_bubbles[instance_id] = bubble
			
			if slot_index >= 0 and slot_index < slots.size():
				var slot: PlacementSlot = slots[slot_index]
				bubble.snap_to_position(slot.get_center_position() - (bubble.size / 2.0))
				slot.occupy(instance_id)
			
			return
	
	if slot_index >= 0:
		_create_organism_bubble_at_slot(instance_id, slot_index)


func _on_organism_removed(instance_id: int) -> void:
	"""Handle organism being removed from ecosystem."""
	if organism_bubbles.has(instance_id):
		organism_bubbles.erase(instance_id)
	
	for slot in slots:
		if slot.organism_instance_id == instance_id:
			slot.clear()
			break


func _on_game_over(won: bool, final_score: int) -> void:
	"""Handle game over."""
	game_ended = true
	var result_text: String = ""
	
	if won:
		result_text = "🎉 Congratulations! 🎉\n\n"
		result_text += "You kept the desert ecosystem\nalive for 12 days!\n\n"
		AudioManager.play_win_sound()
	else:
		result_text = "The ecosystem collapsed...\n\n"
		result_text += "Some organisms didn't survive.\n"
		result_text += "Try again!\n\n"
	
	result_text += "🏆 Final Score: %d" % final_score
	
	results_label.text = result_text
	next_day_button.text = "Return to Menu"
	results_panel.visible = true


func _on_menu_button_pressed() -> void:
	"""Handle menu button press."""
	AudioManager.play_click_sound()
	SaveSystem.autosave()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func hide_organisms_container():
	if organisms_container:
		organisms_container.visible = false
	
func show_organisms_container():
	if organisms_container:
		organisms_container.visible = true


func toggle_music():
	if music_on:
		theme_player.stop()
		music_on = false
	else:
		$theme_player.play()
		music_on = true
		
func _on_button_pressed() -> void:
	toggle_music() # Replace with function body.
