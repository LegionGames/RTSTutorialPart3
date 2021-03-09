extends StateMachine


enum Commands {
	NONE,
	MOVE,
	ATTACK_MOVE,
	HOLD
}
var command = Commands.NONE

enum CommandMods {
	NONE,
	ATTACK_MOVE
}
var command_mod = CommandMods.NONE


func _ready():
	add_state("idle")
	add_state("moving")
	add_state("engaging")
	add_state("attacking")
	add_state("dying")
	call_deferred("set_state", states.idle)


func _input(event):
	if parent.selected and state != states.dying:
		if Input.is_action_just_pressed("attack_move"):
			command_mod = CommandMods.ATTACK_MOVE
		if Input.is_action_just_pressed("hold"):
			command = Commands.HOLD
			set_state(states.idle)
		if Input.is_action_just_released("right_click"):
			parent.set_target(event.position)
			set_state(states.moving)
			match command_mod:
				CommandMods.NONE:
					command = Commands.MOVE
				CommandMods.ATTACK_MOVE:
					command = Commands.ATTACK_MOVE


func _state_logic(delta):
	match state:
		states.idle:
			pass
		states.moving:
			parent.move_along_path(delta)
		states.engaging:
			if parent.attack_target.get_ref():
				parent.move_to_target(delta, parent.attack_target.get_ref().position)
			else:
				set_state(states.idle)
		states.attacking:
			pass
		states.dying:
			pass


func update_sprite():
	match state:
		states.idle:
			if parent.facing_forward:
				parent.sprite.frames = parent.idle_forward_frames
			else:
				parent.sprite.frames = parent.idle_back_frames
		states.moving:
			if parent.position.x < parent.movement_target.x:
				parent.sprite.flip_h = false
			elif parent.position.x > parent.movement_target.x:
				parent.sprite.flip_h = true
			if parent.position.y < parent.movement_target.y:
				parent.sprite.frames = parent.walking_forward_frames
				parent.facing_forward = true
			elif parent.position.y > parent.movement_target.y:
				parent.sprite.frames = parent.walking_back_frames
				parent.facing_forward = false
		states.engaging:
			if parent.position.x < parent.attack_target.get_ref().position.x:
				parent.sprite.flip_h = false
			elif parent.position.x > parent.attack_target.get_ref().position.x:
				parent.sprite.flip_h = true
			if parent.position.y < parent.attack_target.get_ref().position.y:
				parent.sprite.frames = parent.walking_forward_frames
				parent.facing_forward = true
			elif parent.position.y > parent.attack_target.get_ref().position.y:
				parent.sprite.frames = parent.walking_back_frames
				parent.facing_forward = false
		states.attacking:
			if parent.facing_forward:
				parent.sprite.frames = parent.attack_forward_frames
			else:
				parent.sprite.frames = parent.attack_back_frames
		states.dying:
			if parent.facing_forward:
				parent.sprite.frames = parent.die_forward_frames
			else:
				parent.sprite.frames = parent.die_back_frames


func _enter_state(new_state, old_state):
	update_sprite()
	if [states.idle, states.attacking].has(new_state):
		parent.set_collision_layer_bit(1, true)
	if [states.moving, states.engaging].has(new_state):
		parent.set_collision_layer_bit(1, false)


func _exit_state(old_state, new_state):
	match old_state:
		states.attacking:
			if new_state == states.idle:
				parent.attack_target = null
		states.moving:
			if new_state != states.moving and command != Commands.ATTACK_MOVE:
				parent.movement_target = parent.position


func _get_transition(delta):
	match state:
		states.idle:
			match command:
				Commands.HOLD:
					if parent.closest_enemy_within_range() != null:
						parent.attack_target = weakref(parent.closest_enemy_within_range())
						set_state(states.attacking)
				Commands.ATTACK_MOVE:
					parent.recalculate_path()
					set_state(states.moving)
				Commands.NONE:
					if parent.closest_enemy() != null:
						parent.attack_target = weakref(parent.closest_enemy())
						set_state(states.engaging)
		states.moving:
			if (command == Commands.ATTACK_MOVE):
				if parent.closest_enemy() != null:
					parent.attack_target = weakref(parent.closest_enemy())
					set_state(states.engaging)
			if parent.position.distance_to(parent.movement_target) < parent.target_max:
				parent.movement_target = parent.position
				set_state(states.idle)
				command = Commands.NONE
				#print("reached target")
		states.engaging:
			if parent.closest_enemy_within_range() != null:
				parent.attack_target = weakref(parent.closest_enemy())
				set_state(states.attacking)
			if parent.attack_target.get_ref().is_dying():
				set_state(states.idle)
				parent.attack_target = null
		states.attacking:
			if parent.attack_target.get_ref().is_dying():
				set_state(states.idle)
				parent.attack_target = null
		states.dying:
			pass


func _on_StopTimer_timeout():
	if state != states.dying:
		set_state(states.idle)
		parent.movement_target = parent.position
		print("group reached target")


func died():
	set_state(states.dying)


func _on_AnimatedSprite_animation_finished():
	match state:
		states.attacking:
			if parent.attack_target.get_ref():
				if parent.attack_target.get_ref().take_damage(parent.damage_amount):
					if parent.target_within_range():
						pass
					else:
						set_state(states.engaging)
				else:
					set_state(states.idle)
			else:
				set_state(states.idle)
		states.dying:
			parent.queue_free()
