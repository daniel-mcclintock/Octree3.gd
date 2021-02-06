"""Simple Octree for spatially storing data."""

var _center : Vector3
var _size : float
var _half_size : float
var _aabb : AABB

var _data : Array
var _children : Array

var _population : int
var _max_population : int


func _init(center : Vector3, size : float, max_population : int):
	_population = 0
	_max_population = max_population

	_center = center
	_size = size
	_half_size = 0.5 * _size
	_data = []


func _get_aabb() -> AABB:
	# Generate, store and return AABB for native intersection math
	if not _aabb:
		_aabb = AABB(_center - Vector3.ONE * _half_size, Vector3.ONE * _size)

	return _aabb


func add(position : Vector3, data, mtx : Mutex) -> void:
	if _children:
		# Don't store data in nodes with children.
		_children[_which_child(position)].add(position, data, mtx)
	elif (_population >= _max_population):
		mtx.lock()
		_create_children()
		mtx.unlock()

		# Transfer data from this node into its children.
		for d in _data:
			add(d.position, d.data, mtx)

		# Add this request payload to appropriate child
		_children[_which_child(position)].add(position, data, mtx)
		mtx.lock()
		_data = []
		_population = 0
		mtx.unlock()
	else:
		mtx.lock()
		_data.append({"position": position, "data": data})
		_population += 1
		mtx.unlock()


func _create_children() -> void:
	var new_size = _size * 0.5
	var new_half_size = new_size * 0.5

	_children = [
		# 000
		get_script().new(_center + Vector3(-new_half_size, -new_half_size, -new_half_size), new_size, _max_population),
		# 001
		get_script().new(_center + Vector3(-new_half_size, -new_half_size, new_half_size), new_size, _max_population),
		# 010
		get_script().new(_center + Vector3(-new_half_size, new_half_size, -new_half_size), new_size, _max_population),
		# 011
		get_script().new(_center + Vector3(-new_half_size, new_half_size, new_half_size), new_size, _max_population),
		# 100
		get_script().new(_center + Vector3(new_half_size, -new_half_size, -new_half_size), new_size, _max_population),
		# 101
		get_script().new(_center + Vector3(new_half_size, -new_half_size, new_half_size), new_size, _max_population),
		# 110
		get_script().new(_center + Vector3(new_half_size, new_half_size, -new_half_size), new_size, _max_population),
		# 111
		get_script().new(_center + Vector3(new_half_size, new_half_size, new_half_size), new_size, _max_population)
	]


func _which_child(position : Vector3) -> int:
	# Given a position return array index of child where it should be stored.
	# TODO: look into using the _aabb to derive this
	if position.x < _center.x:
		if position.y < _center.y:
			if position.z < _center.z:
				#000
				return 0
			else:
				return 1
				#001
		else:
			if position.z < _center.z:
				return 2
				#010
			else:
				return 3
				#011
	else:
		if position.y < _center.y:
			if position.z < _center.z:
				#100
				return 4
			else:
				#101
				return 5

		else:
			if position.z < _center.z:
				#110
				return 6
			else:
				#111
				return 7


func get_ray_hits(start : Vector3, end : Vector3, distance : float, radius_expand : float = 0.0) -> Array:
	# Given a ray segment (start, end) find all data points contained within octree.
	var nodes : Array = _ray_nodes(start, end)

	var result : Array = []
	for node in nodes:
		if true or node._population:
			for data in node._data:
				var dd : float = abs(_distance_of_nearest_point_along_ray(start, end, data.position))
				if dd <= distance:
					result.append(data)
	return result


func _distance_of_nearest_point_along_ray(start : Vector3, end : Vector3, point : Vector3) -> float:
	# Given a ray segment (start, end) calculate the distance of the closest point along the ray.
	# https://forum.unity.com/threads/how-do-i-find-the-closest-point-on-a-line.340058/
	var dir : Vector3 = (start - end).normalized()
	var v : Vector3 = point - start
	var d : float = v.dot(dir)
	return point.distance_to(start + dir * d)


func _ray_nodes(start, end) -> Array:
	# Given a ray segment (start, end) find all intersecting octree nodes.
	if not _children:
		# if we are a node that stores data check ray intersects with node bounds and if so return self
		if _get_aabb().intersects_segment(start, end):
			return [self]
	else:
		# if we have children ask our children if they intersect with ray
		var c = []
		for child in _children:
			var r = child._ray_nodes(start, end)
			if r:
				c += r
		return c

	return []


func is_inside(position) -> bool:
	# Does this position exist within the current node bounds.
	if position.x > _center.x + _half_size:
		return false
	if position.y > _center.y + _half_size:
		return false
	if position.z > _center.z + _half_size:
		return false
	if position.x < _center.x - _half_size:
		return false
	if position.y < _center.y - _half_size:
		return false
	if position.z < _center.z - _half_size:
		return false

	return true


func debug_render_bounds(immediate_geometry : ImmediateGeometry) -> void:
	# Given pre-existing ImmediateGeometry, render debug mesh.
	if _children:
		for child in _children:
			child.RenderBounds(immediate_geometry)
	else:
		if _population:
			var bounding_vertices = [
				# Inefficient
				_center + Vector3(-_half_size, -_half_size, -_half_size),
				_center + Vector3(-_half_size, _half_size, -_half_size),
				_center + Vector3(_half_size, _half_size, -_half_size),
				_center + Vector3(_half_size, _half_size, _half_size),
				_center + Vector3(-_half_size, _half_size, _half_size),
				_center + Vector3(-_half_size, _half_size, -_half_size),
				_center + Vector3(-_half_size, _half_size, _half_size),
				_center + Vector3(-_half_size, -_half_size, _half_size),
				_center + Vector3(-_half_size, -_half_size, -_half_size),
				_center + Vector3(_half_size, -_half_size, -_half_size),
				_center + Vector3(_half_size, _half_size, -_half_size),
				_center + Vector3(_half_size, -_half_size, -_half_size),
				_center + Vector3(_half_size, -_half_size, _half_size),
				_center + Vector3(-_half_size, -_half_size, _half_size),
				_center + Vector3(_half_size, -_half_size, _half_size),
				_center + Vector3(_half_size, _half_size, _half_size),
			]
			immediate_geometry.begin(PrimitiveMesh.PRIMITIVE_LINE_STRIP)
			for p in bounding_vertices:
				immediate_geometry.add_vertex(p)
			immediate_geometry.end()
