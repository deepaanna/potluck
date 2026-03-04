## Generic object pool for efficient scene instantiation and reuse.
## Preallocates instances and grows dynamically when needed.
class_name ObjectPool
extends Node

var _scene: PackedScene
var _pool: Array[Node] = []
var _active: Array[Node] = []
var _parent: Node


## Initialize the pool with a scene and initial count
func init(scene: PackedScene, count: int, parent: Node = null) -> void:
	_scene = scene
	_parent = parent
	for i: int in range(count):
		var instance: Node = _create_instance()
		_pool.append(instance)


## Get an instance from the pool. Creates a new one if pool is empty.
func get_instance() -> Node:
	var instance: Node
	if _pool.size() > 0:
		instance = _pool.pop_back()
	else:
		instance = _create_instance()
		push_warning("ObjectPool: Pool empty, creating new instance dynamically")

	_active.append(instance)
	if instance is CanvasItem:
		(instance as CanvasItem).visible = true
	elif instance is Node3D:
		(instance as Node3D).visible = true
	instance.set_process(true)
	instance.set_physics_process(true)
	return instance


## Return an instance to the pool for reuse
func release(instance: Node) -> void:
	if not is_instance_valid(instance):
		return

	_active.erase(instance)
	_pool.append(instance)

	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	elif instance is Node3D:
		(instance as Node3D).visible = false
	instance.set_process(false)
	instance.set_physics_process(false)


## Release all active instances back to the pool
func release_all() -> void:
	for instance: Node in _active.duplicate():
		release(instance)


## Get the number of available instances in the pool
func available_count() -> int:
	return _pool.size()


## Get the number of currently active instances
func active_count() -> int:
	return _active.size()


func _create_instance() -> Node:
	var instance: Node = _scene.instantiate()
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	elif instance is Node3D:
		(instance as Node3D).visible = false
	instance.set_process(false)
	instance.set_physics_process(false)

	var target: Node = _parent if _parent != null else self
	target.add_child(instance)
	return instance
