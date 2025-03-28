@tool
extends Node3D
class_name JesteretteGenerator

# Constants for script paths
const BODY_GENERATOR_PATH = "res://generators/body_generator.gd"
const HEAD_GENERATOR_PATH = "res://generators/head_generator.gd"
const HAIR_GENERATOR_PATH = "res://generators/hair_generator.gd"
const OUTFIT_GENERATOR_PATH = "res://generators/outfit_generator.gd"
const CHARACTER_SETTINGS_PATH = "res://resources/character_settings.gd"

# Dynamically loaded classes
var BodyGenerator
var HeadGenerator
var HairGenerator
var OutfitGenerator
var CharacterSettings

# Export properties for the editor
@export var generate: bool:
	set(_value):
		generate_character()

@export var settings: Resource

func _init():
	_load_dependencies()

func _load_dependencies():
	# Load generator scripts
	var generators = {
		"BodyGenerator": BODY_GENERATOR_PATH,
		"HeadGenerator": HEAD_GENERATOR_PATH,
		"HairGenerator": HAIR_GENERATOR_PATH,
		"OutfitGenerator": OUTFIT_GENERATOR_PATH,
	}
	
	for generator_name in generators:
		var script = load(generators[generator_name])
		if script:
			set(generator_name, script)
		else:
			print_debug(generators[generator_name] + " was not found. Have you checked the path in character_generator.gd?")
	
	# Load settings resource
	var settings_script = load(CHARACTER_SETTINGS_PATH)
	if settings_script:
		CharacterSettings = settings_script
		if !settings:
			settings = CharacterSettings.new()
	else:
		print_debug(CHARACTER_SETTINGS_PATH + " was not found. Have you checked the path in character_generator.gd?")

func generate_character() -> void:
	# Clear existing character
	for child in get_children():
		if child.name == "JesteretteCharacter":
			remove_child(child)
			child.queue_free()
	
	var character = Node3D.new()
	character.name = "JesteretteCharacter"
	add_child(character)
	if Engine.is_editor_hint():
		character.owner = get_tree().edited_scene_root
	
	# Generate character parts using loaded generators
	if BodyGenerator:
		var body_gen = BodyGenerator.new()
		body_gen.generate(character, settings)
	
	if HeadGenerator:
		var head_gen = HeadGenerator.new()
		head_gen.generate(character, settings)
	
	if HairGenerator:
		var hair_gen = HairGenerator.new()
		hair_gen.generate(character, settings)
	
	if OutfitGenerator:
		var outfit_gen = OutfitGenerator.new()
		outfit_gen.generate(character, settings)

# Utility function used by all generators
static func set_owner_recursive(node: Node, owner: Node) -> void:
	if Engine.is_editor_hint():
		node.owner = owner
		for child in node.get_children():
			set_owner_recursive(child, owner)
