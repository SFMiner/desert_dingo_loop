# ecosystem_constants.gd
# Defines all organism types, their trophic levels, and food requirements
# Uses the "1-to-3" rule: each consumer needs 3 of its food source to survive

extends Node

# === ENUMS ===

enum TrophicLevel {
	PRODUCER = 0,      # Plants - need only space
	PRIMARY = 1,       # Herbivores/Insects - eat plants
	SECONDARY = 2,     # Carnivores - eat primary consumers
	TERTIARY = 3       # Apex predators - eat secondary consumers
}

enum OrganismID {
	# Producers (Plants)
	SPINIFEX_GRASS,
	NEVERFAIL_GRASS,
	STURTS_DESERT_PEA,
	MULGA_TREE,
	BLOODWOOD_TREE,
	# Primary Consumers (Herbivores/Insects)
	ANT,
	TERMITE,
	RED_KANGAROO,
	BILBY,
	SPINIFEX_MOUSE,
	# Secondary Consumers (Carnivores/Omnivores)
	THORNY_DEVIL,
	HONEYEATER,
	WEDGE_TAILED_EAGLE,
	DINGO
}

# === CONSTANTS ===

# The core balance rule: each consumer needs this many food sources
const FOOD_REQUIREMENT: int = 3

# Total days in a game
const TOTAL_DAYS: int = 12

# Number of organisms offered per day (draft)
const DRAFT_SIZE: int = 5

# Number of placement slots in the desert
const TOTAL_SLOTS: int = 50

# Points per healthy organism at end of day
const POINTS_PER_HEALTHY: int = 10

# === ORGANISM DEFINITIONS ===
# Each organism has: name, trophic_level, food_sources (what it eats), color (placeholder)

var ORGANISMS: Dictionary = {
	# === PRODUCERS (Plants) ===
	OrganismID.SPINIFEX_GRASS: {
		"id": OrganismID.SPINIFEX_GRASS,
		"name": "Spinifex Grass",
		"short_name": "Spinifex",
		"trophic_level": TrophicLevel.PRODUCER,
		"food_sources": [],  # Plants don't eat anything
		"color": Color(0.6, 0.8, 0.2),  # Yellow-green
		"description": "Tough grass that grows in clumps.",
		"icon_char": "🌿"
	},
	OrganismID.NEVERFAIL_GRASS: {
		"id": OrganismID.NEVERFAIL_GRASS,
		"name": "Never-Fail Grass",
		"short_name": "NeverFail",
		"trophic_level": TrophicLevel.PRODUCER,
		"food_sources": [],
		"color": Color(0.5, 0.7, 0.3),  # Green
		"description": "Hardy grass that survives drought.",
		"icon_char": "🌾"
	},
	OrganismID.STURTS_DESERT_PEA: {
		"id": OrganismID.STURTS_DESERT_PEA,
		"name": "Sturt's Desert Pea",
		"short_name": "Desert Pea",
		"trophic_level": TrophicLevel.PRODUCER,
		"food_sources": [],
		"color": Color(0.9, 0.2, 0.2),  # Red flower
		"description": "Beautiful red flower of the desert.",
		"icon_char": "🌺"
	},
	OrganismID.MULGA_TREE: {
		"id": OrganismID.MULGA_TREE,
		"name": "Mulga Tree",
		"short_name": "Mulga",
		"trophic_level": TrophicLevel.PRODUCER,
		"food_sources": [],
		"color": Color(0.4, 0.6, 0.3),  # Dark green
		"description": "Small tree with silver-green leaves.",
		"icon_char": "🌳"
	},
	OrganismID.BLOODWOOD_TREE: {
		"id": OrganismID.BLOODWOOD_TREE,
		"name": "Bloodwood Tree",
		"short_name": "Bloodwood",
		"trophic_level": TrophicLevel.PRODUCER,
		"food_sources": [],
		"color": Color(0.5, 0.4, 0.3),  # Brown-green
		"description": "Tree with red sap like blood.",
		"icon_char": "🌲"
	},
	
	# === PRIMARY CONSUMERS (Herbivores/Insects) ===
	OrganismID.ANT: {
		"id": OrganismID.ANT,
		"name": "Ant",
		"short_name": "Ant",
		"trophic_level": TrophicLevel.PRIMARY,
		"food_sources": [TrophicLevel.PRODUCER],  # Eats plants
		"color": Color(0.3, 0.2, 0.1),  # Dark brown
		"description": "Tiny but mighty desert worker.",
		"icon_char": "🐜"
	},
	OrganismID.TERMITE: {
		"id": OrganismID.TERMITE,
		"name": "Termite",
		"short_name": "Termite",
		"trophic_level": TrophicLevel.PRIMARY,
		"food_sources": [TrophicLevel.PRODUCER],
		"color": Color(0.8, 0.7, 0.5),  # Tan
		"description": "Builds tall mounds in the desert.",
		"icon_char": "🪲"
	},
	OrganismID.RED_KANGAROO: {
		"id": OrganismID.RED_KANGAROO,
		"name": "Red Kangaroo",
		"short_name": "Kangaroo",
		"trophic_level": TrophicLevel.PRIMARY,
		"food_sources": [TrophicLevel.PRODUCER],
		"color": Color(0.8, 0.4, 0.3),  # Reddish-brown
		"description": "Hops across the desert eating grass.",
		"icon_char": "🦘"
	},
	OrganismID.BILBY: {
		"id": OrganismID.BILBY,
		"name": "Bilby",
		"short_name": "Bilby",
		"trophic_level": TrophicLevel.PRIMARY,
		"food_sources": [TrophicLevel.PRODUCER],
		"color": Color(0.7, 0.6, 0.5),  # Gray-brown
		"description": "Nocturnal digger with big ears.",
		"icon_char": "🐰"
	},
	OrganismID.SPINIFEX_MOUSE: {
		"id": OrganismID.SPINIFEX_MOUSE,
		"name": "Spinifex-hopping Mouse",
		"short_name": "Mouse",
		"trophic_level": TrophicLevel.PRIMARY,
		"food_sources": [TrophicLevel.PRODUCER],
		"color": Color(0.9, 0.8, 0.6),  # Light tan
		"description": "Tiny mouse that hops like a kangaroo.",
		"icon_char": "🐭"
	},
	
	# === SECONDARY CONSUMERS (Carnivores/Omnivores) ===
	OrganismID.THORNY_DEVIL: {
		"id": OrganismID.THORNY_DEVIL,
		"name": "Thorny Devil",
		"short_name": "Thorny Devil",
		"trophic_level": TrophicLevel.SECONDARY,
		"food_sources": [TrophicLevel.PRIMARY],  # Eats insects/herbivores
		"color": Color(0.7, 0.5, 0.3),  # Sandy brown
		"description": "Spiky lizard that loves ants.",
		"icon_char": "🦎"
	},
	OrganismID.HONEYEATER: {
		"id": OrganismID.HONEYEATER,
		"name": "Spiny-cheeked Honeyeater",
		"short_name": "Honeyeater",
		"trophic_level": TrophicLevel.SECONDARY,
		"food_sources": [TrophicLevel.PRIMARY],
		"color": Color(0.6, 0.5, 0.4),  # Brown
		"description": "Bird that drinks nectar and eats bugs.",
		"icon_char": "🐦"
	},
	OrganismID.WEDGE_TAILED_EAGLE: {
		"id": OrganismID.WEDGE_TAILED_EAGLE,
		"name": "Wedge-tailed Eagle",
		"short_name": "Eagle",
		"trophic_level": TrophicLevel.SECONDARY,
		"food_sources": [TrophicLevel.PRIMARY],  # Eats kangaroos, bilbies, etc.
		"color": Color(0.3, 0.25, 0.2),  # Dark brown
		"description": "Soars high, hunting from above.",
		"icon_char": "🦅"
	},
	OrganismID.DINGO: {
		"id": OrganismID.DINGO,
		"name": "Dingo",
		"short_name": "Dingo",
		"trophic_level": TrophicLevel.SECONDARY,  # Also tertiary but simplified
		"food_sources": [TrophicLevel.PRIMARY],  # Eats kangaroos, bilbies, mice
		"color": Color(0.9, 0.7, 0.4),  # Sandy yellow
		"description": "Wild dog of the Australian desert.",
		"icon_char": "🐕"
	}
}

# === HELPER FUNCTIONS ===

func get_organism_data(organism_id: OrganismID) -> Dictionary:
	"""Get the full data dictionary for an organism."""
	if ORGANISMS.has(organism_id):
		return ORGANISMS[organism_id]
	push_error("Unknown organism ID: " + str(organism_id))
	return {}


func get_organisms_by_trophic_level(level: TrophicLevel) -> Array:
	"""Get all organism IDs at a specific trophic level."""
	var result: Array = []
	for id in ORGANISMS.keys():
		if ORGANISMS[id]["trophic_level"] == level:
			result.append(id)
	return result


func get_all_organism_ids() -> Array:
	"""Get all organism IDs."""
	return ORGANISMS.keys()


func get_producers() -> Array:
	"""Get all producer (plant) organism IDs."""
	return get_organisms_by_trophic_level(TrophicLevel.PRODUCER)


func get_primary_consumers() -> Array:
	"""Get all primary consumer (herbivore/insect) organism IDs."""
	return get_organisms_by_trophic_level(TrophicLevel.PRIMARY)


func get_secondary_consumers() -> Array:
	"""Get all secondary consumer (carnivore) organism IDs."""
	return get_organisms_by_trophic_level(TrophicLevel.SECONDARY)


func get_random_draft() -> Array:
	"""
	Generate a random draft of organisms for the player to choose from.
	Ensures a mix of trophic levels for strategic choices.
	"""
	var draft: Array = []
	var all_ids: Array = get_all_organism_ids()
	
	# Shuffle and pick DRAFT_SIZE organisms
	all_ids.shuffle()
	
	# Ensure at least one producer and one consumer in each draft
	var producers: Array = get_producers()
	var consumers: Array = get_primary_consumers() + get_secondary_consumers()
	
	producers.shuffle()
	consumers.shuffle()
	
	# Add 2-3 producers and 2-3 consumers
	var num_producers: int = randi_range(2, 3)
	var num_consumers: int = DRAFT_SIZE - num_producers
	
	for i in range(min(num_producers, producers.size())):
		draft.append(producers[i])
	
	for i in range(min(num_consumers, consumers.size())):
		draft.append(consumers[i])
	
	# If we don't have enough, fill with random
	while draft.size() < DRAFT_SIZE:
		var random_id = all_ids[randi() % all_ids.size()]
		if not random_id in draft:
			draft.append(random_id)
	
	draft.shuffle()
	return draft


func trophic_level_name(level: TrophicLevel) -> String:
	"""Get human-readable name for a trophic level."""
	match level:
		TrophicLevel.PRODUCER:
			return "Producer"
		TrophicLevel.PRIMARY:
			return "Primary Consumer"
		TrophicLevel.SECONDARY:
			return "Secondary Consumer"
		TrophicLevel.TERTIARY:
			return "Tertiary Consumer"
	return "Unknown"
