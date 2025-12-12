# save_system.gd
# Handles saving and loading game state
# Uses localStorage for web builds, file system for desktop

extends Node

# === SIGNALS ===

signal save_complete(success: bool)
signal load_complete(success: bool, has_save: bool)

# === CONSTANTS ===

const SAVE_KEY: String = "desert_loop_save"
const SAVE_FILE_PATH: String = "user://desert_loop_save.json"

# === STATE ===

var _has_save_data: bool = false

# === LIFECYCLE ===

func _ready() -> void:
	# Check if save exists on startup
	_has_save_data = _check_save_exists()


# === PUBLIC API ===

func has_save() -> bool:
	"""Check if a save file exists."""
	return _has_save_data


func save_game() -> bool:
	"""Save the current game state."""
	var save_data: Dictionary = EcosystemState.get_save_data()
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	
	var success: bool = false
	
	if OS.has_feature("web"):
		success = _save_web(save_data)
	else:
		success = _save_desktop(save_data)
	
	if success:
		_has_save_data = true
	
	save_complete.emit(success)
	return success


func autosave() -> void:
	"""Perform an autosave (silent, no signals)."""
	var save_data: Dictionary = EcosystemState.get_save_data()
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	
	if OS.has_feature("web"):
		_save_web(save_data)
	else:
		_save_desktop(save_data)
	
	_has_save_data = true


func load_game() -> bool:
	"""Load the saved game state."""
	var save_data: Dictionary = {}
	var success: bool = false
	
	if OS.has_feature("web"):
		save_data = _load_web()
	else:
		save_data = _load_desktop()
	
	if not save_data.is_empty():
		EcosystemState.load_game_state(save_data)
		success = true
	
	load_complete.emit(success, _has_save_data)
	return success


func clear_save() -> void:
	"""Delete the save file."""
	if OS.has_feature("web"):
		_clear_web()
	else:
		_clear_desktop()
	
	_has_save_data = false


func get_save_info() -> Dictionary:
	"""Get information about the save file without loading full state."""
	var save_data: Dictionary = {}
	
	if OS.has_feature("web"):
		save_data = _load_web()
	else:
		save_data = _load_desktop()
	
	if save_data.is_empty():
		return {}
	
	return {
		"current_day": save_data.get("current_day", 1),
		"total_score": save_data.get("total_score", 0),
		"organism_count": save_data.get("organisms", []).size(),
		"save_timestamp": save_data.get("save_timestamp", 0)
	}


# === WEB STORAGE (localStorage) ===

func _save_web(data: Dictionary) -> bool:
	"""Save to browser localStorage."""
	var json_string: String = JSON.stringify(data)
	
	# Use JavaScriptBridge to access localStorage
	var js_code: String = """
		try {
			localStorage.setItem('%s', '%s');
			true;
		} catch(e) {
			console.error('Save failed:', e);
			false;
		}
	""" % [SAVE_KEY, json_string.c_escape()]
	
	var result = JavaScriptBridge.eval(js_code)
	return result == true


func _load_web() -> Dictionary:
	"""Load from browser localStorage."""
	var js_code: String = """
		try {
			var data = localStorage.getItem('%s');
			data ? data : '';
		} catch(e) {
			console.error('Load failed:', e);
			'';
		}
	""" % SAVE_KEY
	
	var result = JavaScriptBridge.eval(js_code)
	
	if result == null or result == "":
		return {}
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(result)
	
	if error == OK:
		return json.data
	
	push_error("Failed to parse save data: " + json.get_error_message())
	return {}


func _clear_web() -> void:
	"""Clear localStorage save."""
	var js_code: String = """
		try {
			localStorage.removeItem('%s');
		} catch(e) {
			console.error('Clear failed:', e);
		}
	""" % SAVE_KEY
	
	JavaScriptBridge.eval(js_code)


func _check_save_exists_web() -> bool:
	"""Check if localStorage save exists."""
	var js_code: String = """
		try {
			localStorage.getItem('%s') !== null;
		} catch(e) {
			false;
		}
	""" % SAVE_KEY
	
	var result = JavaScriptBridge.eval(js_code)
	return result == true


# === DESKTOP STORAGE (File) ===

func _save_desktop(data: Dictionary) -> bool:
	"""Save to file system."""
	var json_string: String = JSON.stringify(data, "\t")
	
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		return true
	
	push_error("Failed to open save file for writing")
	return false


func _load_desktop() -> Dictionary:
	"""Load from file system."""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return {}
	
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()
		
		var json: JSON = JSON.new()
		var error: Error = json.parse(json_text)
		
		if error == OK:
			return json.data
		
		push_error("Failed to parse save data: " + json.get_error_message())
	
	return {}


func _clear_desktop() -> void:
	"""Delete save file."""
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)


func _check_save_exists_desktop() -> bool:
	"""Check if save file exists."""
	return FileAccess.file_exists(SAVE_FILE_PATH)


# === HELPER ===

func _check_save_exists() -> bool:
	"""Check if any save data exists."""
	if OS.has_feature("web"):
		return _check_save_exists_web()
	else:
		return _check_save_exists_desktop()
