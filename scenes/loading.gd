## Simple loading screen shown during scene transitions.
extends Control

@onready var label: Label = %Label
@onready var progress_bar: ProgressBar = %ProgressBar

var _target_scene: String = ""


func _ready() -> void:
	AnalyticsManager.log_screen("loading")


## Start loading a scene by path
func load_scene(scene_path: String) -> void:
	_target_scene = scene_path
	ResourceLoader.load_threaded_request(scene_path)


func _process(_delta: float) -> void:
	if _target_scene.is_empty():
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_scene, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				progress_bar.value = progress[0] * 100.0
				label.text = "Loading... %d%%" % int(progress[0] * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			var scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene) as PackedScene
			if scene != null:
				get_tree().change_scene_to_packed(scene)
			_target_scene = ""
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Loading: Failed to load scene: %s" % _target_scene)
			label.text = "Loading failed!"
			_target_scene = ""
