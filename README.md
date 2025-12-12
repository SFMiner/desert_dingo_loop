# 🏜️ Desert Loop

An educational ecosystem simulator inspired by PBS Kids' "Feed the Dingo" game. Players build and maintain an Australian desert ecosystem over 12 days by placing plants and animals in a balanced food web.

## 🎮 How to Play

1. **Draft Phase**: Each day, you receive 5 random organisms (plants and animals)
2. **Placement Phase**: Drag organisms from the bottom bar into empty slots in the desert
3. **Simulation Phase**: Click the "☀️ GO!" button to advance the day
4. **Results**: See which organisms survived and which starved

### The "1-to-3" Rule

The core balance mechanic:
- **1 Herbivore needs 3 Plants** to survive
- **1 Predator needs 3 Herbivores** to survive

If an organism doesn't have enough food, it will starve and disappear!

### Win Condition

Reach Day 12 with at least one organism from each trophic level:
- 🌿 At least 1 Plant (Producer)
- 🐰 At least 1 Herbivore (Primary Consumer)  
- 🦊 At least 1 Predator (Secondary Consumer)

## 🦘 Organisms

### Producers (Plants)
| Icon | Name | Description |
|------|------|-------------|
| 🌿 | Spinifex Grass | Tough grass that grows in clumps |
| 🌾 | Never-Fail Grass | Hardy grass that survives drought |
| 🌺 | Sturt's Desert Pea | Beautiful red flower of the desert |
| 🌳 | Mulga Tree | Small tree with silver-green leaves |
| 🌲 | Bloodwood Tree | Tree with red sap like blood |

### Primary Consumers (Herbivores/Insects)
| Icon | Name | Description |
|------|------|-------------|
| 🐜 | Ant | Tiny but mighty desert worker |
| 🪲 | Termite | Builds tall mounds in the desert |
| 🦘 | Red Kangaroo | Hops across the desert eating grass |
| 🐰 | Bilby | Nocturnal digger with big ears |
| 🐭 | Spinifex-hopping Mouse | Tiny mouse that hops like a kangaroo |

### Secondary Consumers (Predators)
| Icon | Name | Description |
|------|------|-------------|
| 🦎 | Thorny Devil | Spiky lizard that loves ants |
| 🐦 | Spiny-cheeked Honeyeater | Bird that drinks nectar and eats bugs |
| 🦅 | Wedge-tailed Eagle | Soars high, hunting from above |
| 🐕 | Dingo | Wild dog of the Australian desert |

## 🎯 Educational Goals

This game teaches:
- **Food Chains**: Understanding who eats whom
- **Trophic Levels**: Producers, Primary Consumers, Secondary Consumers
- **Energy Transfer**: The 10% rule (simplified to 1:3 ratio)
- **Ecosystem Balance**: Too many predators = not enough prey
- **Cause and Effect**: Decisions have consequences

### Curriculum Alignment
- NGSS MS-LS2-3: Food webs and energy flow
- NGSS MS-LS2-4: Changes in ecosystems

## 🛠️ Technical Details

### Requirements
- Godot 4.3+
- Web browser with WebGL support (for web export)

### Project Structure
```
desert_loop/
├── scenes/
│   ├── MainMenu.tscn
│   ├── DesertRoom.tscn
│   ├── OrganismBubble.tscn
│   └── PlacementSlot.tscn
├── scripts/
│   ├── ecosystem_constants.gd  (AutoLoad)
│   ├── ecosystem_state.gd      (AutoLoad)
│   ├── save_system.gd          (AutoLoad)
│   ├── audio_manager.gd        (AutoLoad)
│   ├── main_menu.gd
│   ├── desert_room.gd
│   ├── organism_bubble.gd
│   └── placement_slot.gd
├── assets/
│   ├── sprites/    (placeholder - add your sprites here)
│   └── audio/      (placeholder - add your sounds here)
└── data/
```

### AutoLoad Singletons
- **EcosystemConstants**: Organism definitions, food requirements
- **EcosystemState**: Game state, simulation logic
- **SaveSystem**: localStorage (web) / file (desktop) saving
- **AudioManager**: Sound effect management

### Save System
- **Autosave**: Saves automatically at the start of each new day
- **Manual Save**: Returns to menu to trigger save
- **Web**: Uses browser localStorage
- **Desktop**: Uses user:// directory

## 🎨 Customization

### Adding Custom Sprites

#### For Animated Creatures (Animals)
Animals use sprite sheets and have movement behaviors. Place your sprite sheets in `assets/sprites/`:

| File | Species | Movement Style |
|------|---------|----------------|
| `dingo.png` | Dingo | WANDER - steady pace, occasional turns |
| `kangaroo.png` | Red Kangaroo | WANDER - faster, hopping motion |
| `ant.png` | Ant | WANDER - small scale, slow |
| `termite.png` | Termite | WANDER - small scale, slow |
| `bilby.png` | Bilby | AMBLE - frequent stops to sniff |
| `sf_mouse.png` | Spinifex Mouse | SCURRY_HIDE - rush to plant bases |
| `thorny_devil.png` | Thorny Devil | SCURRY_BASK - rush to sunny spots |
| `eagle.png` | Wedge-tailed Eagle | SOAR - glide in sky, land in trees |
| `honeyeater.png` | Honeyeater | FLUTTER - short bursts between perches |

**Sprite Sheet Format:**
- Recommended: 4 frames horizontal x 2 rows vertical
- Row 1: Walking/moving animation
- Row 2: Idle animation (optional)
- Update `creature_manager.gd` `_setup_sprite_frames()` to match your layout

**Animation Setup:**
Each creature needs animations in the AnimationPlayer:
- `{species}` - Movement animation (e.g., "dingo", "kangaroo")
- `{species}_idle` - Idle animation (optional, e.g., "dingo_idle")

#### For Static Organisms (Plants)
Plants use the bubble system. Replace placeholder colors:
1. Add sprite files to `assets/sprites/`
2. Update `OrganismBubble.tscn` to use `Sprite2D` instead of `ColorRect`
3. Modify `organism_bubble.gd` to load sprite based on organism_id

### Adding Sound Effects
Add audio files to `assets/audio/` and update `audio_manager.gd`:
```gdscript
func _ready():
    # ... existing code ...
    load_sound("place", "res://assets/audio/pop.ogg")
    load_sound("eat", "res://assets/audio/crunch.ogg")
    # etc.
```

### Adjusting Difficulty
In `ecosystem_constants.gd`:
```gdscript
const FOOD_REQUIREMENT: int = 3  # Change to 2 for easier, 4 for harder
const TOTAL_DAYS: int = 12       # Change for shorter/longer games
const DRAFT_SIZE: int = 5        # Change for more/fewer choices per day
```

## 📝 License

MIT License - Feel free to use and modify for educational purposes!

## 🙏 Credits

- Inspired by PBS Kids' "Feed the Dingo" from PLUM LANDING
- Built with Godot Engine 4.3
