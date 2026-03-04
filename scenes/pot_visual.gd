## Cauldron visual with bubble, steam, and splash particle effects.
extends Node2D

@onready var _pot_body: ColorRect = $PotBody
@onready var _pot_rim: ColorRect = $PotRim
@onready var _liquid: ColorRect = $Liquid
@onready var _bubble_particles: GPUParticles2D = $BubbleParticles
@onready var _steam_particles: GPUParticles2D = $SteamParticles
@onready var _splash_particles: GPUParticles2D = $SplashParticles

var _current_stage: int = 0


func _ready() -> void:
	_bubble_particles.emitting = false
	_steam_particles.emitting = false
	_splash_particles.emitting = false


func set_heat_stage(stage: int) -> void:
	_current_stage = stage

	match stage:
		0:  # Cool
			_liquid.color = Color(0.2, 0.5, 0.3, 0.8)
			_bubble_particles.emitting = false
			_steam_particles.emitting = false
		1:  # Warm
			_liquid.color = Color(0.4, 0.5, 0.2, 0.85)
			_bubble_particles.emitting = true
			_bubble_particles.amount = 4
			_steam_particles.emitting = false
		2:  # Hot
			_liquid.color = Color(0.6, 0.4, 0.15, 0.9)
			_bubble_particles.emitting = true
			_bubble_particles.amount = 8
			_steam_particles.emitting = false
		3:  # Bubbling
			_liquid.color = Color(0.8, 0.35, 0.1, 0.9)
			_bubble_particles.emitting = true
			_bubble_particles.amount = 16
			_steam_particles.emitting = true
			_steam_particles.amount = 6
		4:  # Danger
			_liquid.color = Color(0.9, 0.2, 0.1, 0.95)
			_bubble_particles.emitting = true
			_bubble_particles.amount = 24
			_steam_particles.emitting = true
			_steam_particles.amount = 12


func play_splash() -> void:
	_splash_particles.restart()
	_splash_particles.emitting = true
	Juice.squash_stretch(self, 0.15, 0.25)


func play_boilover() -> void:
	_liquid.color = Color(1.0, 0.15, 0.05, 1.0)
	_bubble_particles.amount = 32
	_steam_particles.amount = 20
	Juice.flash(self, Color(1.0, 0.3, 0.1), 0.4)
