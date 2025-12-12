# ecosystem_state.gd
# Global singleton tracking the current game state
# Manages organisms in the ecosystem, day progression, and simulation logic

extends Node

# === SIGNALS ===

signal day_changed(new_day: int)
signal organism_added(organism_instance_id: int)
signal organism_removed(organism_instance_id: int)
signal simulation_started()
signal simulation_complete(results: Dictionary)
signal game_over(won: bool, final_score: int)
signal ecosystem_updated()

# === ENUMS ===

enum HealthStatus {
	HEALTHY,   # Has enough food
	HUNGRY,    # Not enough food but still alive
	DEAD       # Removed from ecosystem
}

enum GamePhase {
	DRAFT,       # Player is selecting from offered organisms
	PLACEMENT,   # Player is placing organisms in slots
	SIMULATION,  # Running the ecosystem check
	RESULTS      # Showing what happened
}

# === GAME STATE VARIABLES ===

var current_day: int = 1
var current_phase: GamePhase = GamePhase.DRAFT
var total_score: int = 0
var game_active: bool = false

# Organisms currently in the ecosystem
# Key: instance_id (int), Value: organism data dictionary
var organisms_in_ecosystem: Dictionary = {}
var next_instance_id: int = 0

# Current draft offerings
var current_draft: Array = []

# Organisms placed this turn (before simulation)
var organisms_placed_this_turn: Array = []

# Slots tracking (which slots are occupied)
var occupied_slots: Dictionary = {}  # slot_index -> instance_id

# === LIFECYCLE ===

func _ready() -> void:
	pass


# === GAME FLOW ===

func start_new_game() -> void:
	"""Initialize a fresh game."""
	current_day = 1
	current_phase = GamePhase.DRAFT
	total_score = 0
	game_active = true
	organisms_in_ecosystem.clear()
	next_instance_id = 0
	current_draft.clear()
	organisms_placed_this_turn.clear()
	occupied_slots.clear()
	
	# Generate first draft
	_generate_new_draft()
	
	day_changed.emit(current_day)
	ecosystem_updated.emit()


func load_game_state(save_data: Dictionary) -> void:
	"""Load game state from save data."""
	current_day = save_data.get("current_day", 1)
	total_score = save_data.get("total_score", 0)
	game_active = save_data.get("game_active", true)
	next_instance_id = save_data.get("next_instance_id", 0)
	
	# Reconstruct organisms dictionary
	organisms_in_ecosystem.clear()
	var organisms_array: Array = save_data.get("organisms", [])
	for org_data in organisms_array:
		var instance_id: int = org_data.get("instance_id", 0)
		organisms_in_ecosystem[instance_id] = org_data
	
	# Reconstruct occupied slots
	occupied_slots.clear()
	var slots_data: Dictionary = save_data.get("occupied_slots", {})
	for slot_key in slots_data.keys():
		occupied_slots[int(slot_key)] = slots_data[slot_key]
	
	current_phase = GamePhase.DRAFT
	organisms_placed_this_turn.clear()
	
	# Generate new draft for the loaded day
	_generate_new_draft()
	
	day_changed.emit(current_day)
	ecosystem_updated.emit()


func get_save_data() -> Dictionary:
	"""Get current game state for saving."""
	var organisms_array: Array = []
	for instance_id in organisms_in_ecosystem.keys():
		organisms_array.append(organisms_in_ecosystem[instance_id])
	
	# Convert occupied_slots keys to strings for JSON
	var slots_data: Dictionary = {}
	for slot_key in occupied_slots.keys():
		slots_data[str(slot_key)] = occupied_slots[slot_key]
	
	return {
		"current_day": current_day,
		"total_score": total_score,
		"game_active": game_active,
		"next_instance_id": next_instance_id,
		"organisms": organisms_array,
		"occupied_slots": slots_data
	}


# === ORGANISM MANAGEMENT ===

func add_organism_to_ecosystem(organism_id: int, slot_index: int) -> int:
	"""
	Add an organism to the ecosystem.
	Returns the instance_id of the new organism, or -1 if failed.
	"""
	if occupied_slots.has(slot_index):
		push_warning("Slot %d is already occupied" % slot_index)
		return -1
	
	var org_data: Dictionary = EcosystemConstants.get_organism_data(organism_id)
	if org_data.is_empty():
		return -1
	
	var instance_id: int = next_instance_id
	next_instance_id += 1
	
	var organism_instance: Dictionary = {
		"instance_id": instance_id,
		"organism_id": organism_id,
		"slot_index": slot_index,
		"health_status": HealthStatus.HEALTHY,
		"day_added": current_day,
		# Copy relevant data from constants
		"name": org_data["name"],
		"short_name": org_data["short_name"],
		"trophic_level": org_data["trophic_level"],
		"color": org_data["color"],
		"icon_char": org_data["icon_char"]
	}
	
	organisms_in_ecosystem[instance_id] = organism_instance
	occupied_slots[slot_index] = instance_id
	organisms_placed_this_turn.append(instance_id)
	
	organism_added.emit(instance_id)
	ecosystem_updated.emit()
	
	return instance_id


func remove_organism_from_ecosystem(instance_id: int) -> void:
	"""Remove an organism from the ecosystem."""
	if not organisms_in_ecosystem.has(instance_id):
		return
	
	var org: Dictionary = organisms_in_ecosystem[instance_id]
	var slot_index: int = org.get("slot_index", -1)
	
	if slot_index >= 0 and occupied_slots.has(slot_index):
		occupied_slots.erase(slot_index)
	
	organisms_in_ecosystem.erase(instance_id)
	organism_removed.emit(instance_id)
	ecosystem_updated.emit()


func get_organism_instance(instance_id: int) -> Dictionary:
	"""Get organism instance data by ID."""
	return organisms_in_ecosystem.get(instance_id, {})


func get_all_organisms() -> Array:
	"""Get all organism instances in the ecosystem."""
	return organisms_in_ecosystem.values()


func get_organisms_at_trophic_level(level: int) -> Array:
	"""Get all organisms at a specific trophic level."""
	var result: Array = []
	for org in organisms_in_ecosystem.values():
		if org["trophic_level"] == level:
			result.append(org)
	return result


func count_organisms_at_trophic_level(level: int) -> int:
	"""Count organisms at a specific trophic level."""
	return get_organisms_at_trophic_level(level).size()


func is_slot_occupied(slot_index: int) -> bool:
	"""Check if a slot is occupied."""
	return occupied_slots.has(slot_index)


func get_empty_slots() -> Array:
	"""Get list of empty slot indices."""
	var empty: Array = []
	for i in range(EcosystemConstants.TOTAL_SLOTS):
		if not occupied_slots.has(i):
			empty.append(i)
	return empty


# === DRAFT SYSTEM ===

func _generate_new_draft() -> void:
	"""Generate a new set of organisms for the player to choose from."""
	current_draft = EcosystemConstants.get_random_draft()


func get_current_draft() -> Array:
	"""Get the current draft offerings."""
	return current_draft.duplicate()


func use_draft_organism(organism_id: int) -> bool:
	"""Remove an organism from the draft (when placed)."""
	var index: int = current_draft.find(organism_id)
	if index >= 0:
		current_draft.remove_at(index)
		return true
	return false


# === SIMULATION LOGIC ===

func run_simulation() -> Dictionary:
	"""
	Run the ecosystem simulation for the current day.
	Checks if each organism has enough food.
	Returns results dictionary with health statuses.
	"""
	simulation_started.emit()
	current_phase = GamePhase.SIMULATION
	
	var results: Dictionary = {
		"healthy": [],
		"hungry": [],
		"dead": [],
		"dead_names": [],  # Names of dead organisms for display
		"food_connections": [],  # For visual feedback
		"day_score": 0
	}
	
	# Count organisms at each trophic level
	var producer_count: int = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRODUCER)
	var primary_count: int = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY)
	var secondary_count: int = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.SECONDARY)
	
	# Calculate how many of each consumer can be fed
	# Each primary consumer needs FOOD_REQUIREMENT producers
	var fed_primary: int = producer_count / EcosystemConstants.FOOD_REQUIREMENT
	# Each secondary consumer needs FOOD_REQUIREMENT primary consumers
	var fed_secondary: int = primary_count / EcosystemConstants.FOOD_REQUIREMENT
	
	# Process each organism
	_pending_removals.clear()
	
	# First, update all organisms' health status
	for instance_id in organisms_in_ecosystem.keys():
		var org: Dictionary = organisms_in_ecosystem[instance_id]
		var trophic_level: int = org["trophic_level"]
		var is_fed: bool = false
		
		match trophic_level:
			EcosystemConstants.TrophicLevel.PRODUCER:
				# Producers are always healthy (they just need space)
				is_fed = true
			EcosystemConstants.TrophicLevel.PRIMARY:
				# Primary consumers need producers
				if fed_primary > 0:
					is_fed = true
					fed_primary -= 1
			EcosystemConstants.TrophicLevel.SECONDARY:
				# Secondary consumers need primary consumers
				if fed_secondary > 0:
					is_fed = true
					fed_secondary -= 1
		
		if is_fed:
			org["health_status"] = HealthStatus.HEALTHY
			results["healthy"].append(instance_id)
			results["day_score"] += EcosystemConstants.POINTS_PER_HEALTHY
		else:
			# Not enough food - mark as dead
			org["health_status"] = HealthStatus.DEAD
			results["dead"].append(instance_id)
			results["dead_names"].append(org.get("short_name", "Unknown"))
			_pending_removals.append(instance_id)
	
	# DON'T remove dead organisms yet - wait for animation
	# They will be removed when remove_pending_dead() is called
	
	# Update total score
	total_score += results["day_score"]
	
	# Generate food connection lines for visual feedback
	results["food_connections"] = _generate_food_connections()
	
	simulation_complete.emit(results)
	
	return results


# Organisms pending removal after death animation
var _pending_removals: Array = []


func remove_pending_dead() -> void:
	"""Remove organisms that died in the simulation. Called after death animation."""
	for instance_id in _pending_removals:
		remove_organism_from_ecosystem(instance_id)
	_pending_removals.clear()


func _generate_food_connections() -> Array:
	"""
	Generate visual connections showing who eats whom.
	Returns array of {eater_id, food_id} pairs.
	"""
	var connections: Array = []
	
	var producers: Array = get_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRODUCER)
	var primaries: Array = get_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY)
	var secondaries: Array = get_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.SECONDARY)
	
	# Connect primary consumers to producers
	var producer_index: int = 0
	for primary in primaries:
		if primary["health_status"] == HealthStatus.HEALTHY:
			for i in range(EcosystemConstants.FOOD_REQUIREMENT):
				if producer_index < producers.size():
					connections.append({
						"eater_id": primary["instance_id"],
						"food_id": producers[producer_index]["instance_id"]
					})
					producer_index += 1
	
	# Connect secondary consumers to primary consumers
	var primary_index: int = 0
	for secondary in secondaries:
		if secondary["health_status"] == HealthStatus.HEALTHY:
			for i in range(EcosystemConstants.FOOD_REQUIREMENT):
				if primary_index < primaries.size():
					connections.append({
						"eater_id": secondary["instance_id"],
						"food_id": primaries[primary_index]["instance_id"]
					})
					primary_index += 1
	
	return connections


func advance_to_next_day() -> void:
	"""Advance to the next day."""
	current_day += 1
	organisms_placed_this_turn.clear()
	
	if current_day > EcosystemConstants.TOTAL_DAYS:
		_end_game()
	else:
		_generate_new_draft()
		current_phase = GamePhase.DRAFT
		day_changed.emit(current_day)
		
		# Autosave at the start of each new day
		SaveSystem.autosave()


func _end_game() -> void:
	"""Handle end of game (after Day 12)."""
	game_active = false
	
	# Check win condition: at least one of each trophic level alive
	var has_producer: bool = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRODUCER) > 0
	var has_primary: bool = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY) > 0
	var has_secondary: bool = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.SECONDARY) > 0
	
	var won: bool = has_producer and has_primary and has_secondary
	
	game_over.emit(won, total_score)
	
	# Clear save on game end
	SaveSystem.clear_save()


# === PREVIEW HELPERS ===

func preview_food_availability(organism_id: int) -> Dictionary:
	"""
	Preview if there's enough food for an organism if placed.
	Used for hover feedback to show green/red highlights.
	Returns: {can_feed: bool, available: int, needed: int, food_sources: Array}
	"""
	var org_data: Dictionary = EcosystemConstants.get_organism_data(organism_id)
	if org_data.is_empty():
		return {"can_feed": false, "available": 0, "needed": 0, "food_sources": []}
	
	var trophic_level: int = org_data["trophic_level"]
	var needed: int = EcosystemConstants.FOOD_REQUIREMENT
	var available: int = 0
	var food_sources: Array = []
	
	match trophic_level:
		EcosystemConstants.TrophicLevel.PRODUCER:
			# Producers always can be placed
			return {"can_feed": true, "available": 999, "needed": 0, "food_sources": []}
		
		EcosystemConstants.TrophicLevel.PRIMARY:
			# Count producers
			var producers: Array = get_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRODUCER)
			var existing_primaries: int = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY)
			# Available food = producers - (existing primaries * FOOD_REQUIREMENT)
			var used_producers: int = existing_primaries * EcosystemConstants.FOOD_REQUIREMENT
			available = max(0, producers.size() - used_producers)
			for p in producers:
				food_sources.append(p["instance_id"])
		
		EcosystemConstants.TrophicLevel.SECONDARY:
			# Count primary consumers
			var primaries: Array = get_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY)
			var existing_secondaries: int = count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.SECONDARY)
			var used_primaries: int = existing_secondaries * EcosystemConstants.FOOD_REQUIREMENT
			available = max(0, primaries.size() - used_primaries)
			for p in primaries:
				food_sources.append(p["instance_id"])
	
	return {
		"can_feed": available >= needed,
		"available": available,
		"needed": needed,
		"food_sources": food_sources
	}


func get_ecosystem_summary() -> Dictionary:
	"""Get a summary of the current ecosystem state."""
	return {
		"producers": count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRODUCER),
		"primary_consumers": count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.PRIMARY),
		"secondary_consumers": count_organisms_at_trophic_level(EcosystemConstants.TrophicLevel.SECONDARY),
		"total_organisms": organisms_in_ecosystem.size(),
		"empty_slots": get_empty_slots().size(),
		"current_day": current_day,
		"total_score": total_score
	}
