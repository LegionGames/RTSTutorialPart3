extends KinematicBody2D
class_name Unit

# owner
export var unit_owner := 0

# movement
var selected = false
var movement_target = Vector2.ZERO
var velocity = Vector2.ZERO
var speed = 80
var target_max = 10
const move_threshold = 0.5
var last_position
var facing_forward = true


# navigation
var nav_path : PoolVector2Array
var leg_reset_threshold = 9
var current_leg = Vector2.ZERO
var movement_group = []

# frames
var idle_forward_frames = load("res://Frames/Knight/knight_idle_forward.tres")
var idle_back_frames = load("res://Frames/Knight/knight_idle_back.tres")
var walking_forward_frames = load("res://Frames/Knight/knight_walking_forward.tres")
var walking_back_frames = load("res://Frames/Knight/knight_walking_back.tres")
var attack_forward_frames = load("res://Frames/Knight/knight_attack_forward.tres")
var attack_back_frames = load("res://Frames/Knight/knight_attack_back.tres")
var die_forward_frames = load("res://Frames/Knight/knight_die_forward.tres")
var die_back_frames = load("res://Frames/Knight/knight_die_back.tres")


# children
onready var stop_timer = $StopTimer
onready var sprite = $AnimatedSprite
onready var state_machine = $UnitSM
onready var collision_shape = $CollisionShape2D
onready var nav2d = get_node("/root/Game/Navigation2D")
onready var rays = $Rays
onready var ray_front = $Rays/RayFront
onready var game = get_node("/root/Game")

# materials 
var enemy_material = load("res://Material/enemy_unit_material.tres")


# combat
var attack_target = null
var attack_range = 25
var health = 15
var damage_amount = 3
var possible_targets = []


func _ready():
	movement_target = position
	if unit_owner == 1:
		material = enemy_material


func move_to_target(delta, tar):
	velocity = Vector2.ZERO
	velocity = position.direction_to(tar) * speed
	move_with_avoidance()


func move_along_path(delta):
	if nav_path.size() > 0:
		var distance_to_next_point = position.distance_to(nav_path[0])
		current_leg = nav_path[0]
		if distance_to_next_point < leg_reset_threshold:
			nav_path.remove(0)
			if nav_path.size() != 0:
				current_leg = nav_path[0]
				velocity = position.direction_to(nav_path[0]) * speed
				state_machine.update_sprite()
				move_with_avoidance()
		else:
			velocity = position.direction_to(nav_path[0]) * speed
			move_with_avoidance()
		colliders_reached_target()


func colliders_reached_target():
	if stop_timer.is_stopped():
		for i in get_slide_count():
			var collider = get_slide_collision(i).collider
			for unit in movement_group:
				if unit.get_ref():
					if unit.get_ref() == collider:
						if collider.reached_target():
							stop_timer.start()


func reached_target() -> bool:
	return movement_target == position


func move_with_avoidance():
	rays.rotation = velocity.angle()
	if _obstacle_ahead():
		var viable_ray = _get_viable_ray()
		if viable_ray:
			velocity = Vector2.RIGHT.rotated(rays.rotation + viable_ray.rotation) * speed
	move_and_slide(velocity)


func _obstacle_ahead() -> bool:
	return ray_front.is_colliding()


func _get_viable_ray() -> RayCast2D:
	for ray in rays.get_children():
		if !ray.is_colliding():
			return ray
	return null


func set_target(target):
	stop_timer.stop()
	movement_group = game.get_movement_group()
	nav_path = nav2d.get_simple_path(self.global_position, target)
	movement_target = target


func recalculate_path():
	nav_path = nav2d.get_simple_path(self.global_position, movement_target)


func select():
	selected = true
	$Selected.visible = true
#	print("current leg: " + str(current_leg))
#	print("distance: " + str(position.distance_to(current_leg)))
#	print("position: " + str(position))
#	print("velocity: "+ str(velocity))


func deselect():
	selected = false
	$Selected.visible = false


func _on_VisionRange_body_entered(body):
	if body.is_in_group("unit"):
		if body.unit_owner != unit_owner:
			possible_targets.append(body)


func _on_VisionRange_body_exited(body):
	if possible_targets.has(body):
		possible_targets.erase(body)


func _compare_distance(target_a, target_b):
	if position.distance_to(target_a.position) < position.distance_to(target_b.position):
		return true
	else:
		return false


func closest_enemy() -> Unit:
	if possible_targets.size() > 0:
		possible_targets.sort_custom(self, "_compare_distance")
		return possible_targets[0]
	else:
		return null


func closest_enemy_within_range() -> Unit:
	if closest_enemy():
		if closest_enemy().position.distance_to(position) < attack_range:
			return closest_enemy()
		else:
			return null
	else:
		return null


func target_within_range() -> bool:
	if attack_target.get_ref().position.distance_to(position) < attack_range:
		return true
	else:
		return false


func take_damage(amount) -> bool:
	health -= amount
	if health <= 0:
		state_machine.died()
		collision_shape.disabled = true
		return false
	else:
		return true


func get_state():
	return state_machine.state


func is_dying() -> bool:
	return state_machine.state == state_machine.states.dying
