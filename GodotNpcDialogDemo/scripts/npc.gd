extends CharacterBody3D

#region VARIABLE
const SPEED = 1.3

const ANIM_IDLE := "Idle0"
const ANIM_WALKING := "Walking0"
const ANIM_WAVING := "Waving0"

enum STATE {
	IDLE,
	WANDER, 
	PLAYER_SPOTTED,
	PLAYER_SPOTTED_NOW_FAR_AWAY, 
	WANDER_RESUME, 
	VISITING_POINT_OF_INTEREST}

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback:AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
@onready var wander_resume_delay_timer: Timer = $WanderResumeDelayTimer
@onready var point_of_interest_duration_timer: Timer = $PointOfInterestDurationTimer

@export var points_of_interest:Array[Node3D] = []

var current_state:STATE = STATE.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_awareness_range := 2.0 
var player
var wander_target :Vector3
var last_point_of_interest_index:int
#endregion

func set_current_state(newState:STATE) -> void:
	if newState == current_state:
		return
	
	match newState:
		STATE.WANDER:
			wander_target = get_random_point_of_interest()
			set_target(wander_target)
		STATE.WANDER_RESUME:
			wander_target = points_of_interest[last_point_of_interest_index].global_position
			set_target(wander_target)
		STATE.PLAYER_SPOTTED:
			wander_resume_delay_timer.stop()
			set_target(global_position)
		STATE.PLAYER_SPOTTED_NOW_FAR_AWAY:
			wander_resume_delay_timer.start()
		STATE.VISITING_POINT_OF_INTEREST:
			set_target(global_position)
			point_of_interest_duration_timer.start()
	
	current_state = newState
	
	print(STATE.keys()[newState])

#region FUNCTION - NATIVE
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	set_current_state(STATE.WANDER)

func _physics_process(delta:float) -> void:
	# set velocity
	var current_location = global_transform.origin
	var next_location = navigation_agent_3d.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED
	velocity = velocity.move_toward(new_velocity, 0.25)
	
	# set state based on player distance
	var distance = global_position.distance_to(player.global_position)
	if distance <= player_awareness_range:
		if current_state != STATE.PLAYER_SPOTTED:
			set_current_state(STATE.PLAYER_SPOTTED)
	else:
		if current_state == STATE.PLAYER_SPOTTED:
			set_current_state(STATE.PLAYER_SPOTTED_NOW_FAR_AWAY)
	
	# handle state
	match current_state:
		STATE.WANDER:
			look_at(next_location)
			playback.travel(ANIM_WALKING)
			move_and_slide()
		STATE.WANDER_RESUME:
			look_at(next_location)
			playback.travel(ANIM_WALKING)
			move_and_slide()
		STATE.PLAYER_SPOTTED:
			look_at(player.global_position)
			playback.travel(ANIM_IDLE)
		STATE.PLAYER_SPOTTED_NOW_FAR_AWAY:
			look_at(player.global_position)
			playback.travel(ANIM_IDLE)
#endregion
	
#region FUNCTION - CUSTOM
func set_target(target_position:Vector3) -> void:
	navigation_agent_3d.target_position = target_position

func get_random_point_of_interest()->Vector3:
	var points_of_interest_count = points_of_interest.size()
	var random_index = 0
	
	if points_of_interest_count > 1:
		random_index = last_point_of_interest_index
		while random_index == last_point_of_interest_index:
			random_index = randi() % points_of_interest_count

	last_point_of_interest_index = random_index

	return points_of_interest[random_index].global_position
#endregion

#region FUNCTION - SIGNAL
func _on_navigation_agent_3d_target_reached() -> void:
	if current_state != STATE.PLAYER_SPOTTED && current_state != STATE.VISITING_POINT_OF_INTEREST:
		#print("signal - target reached")
		set_current_state(STATE.VISITING_POINT_OF_INTEREST)
	
func _on_wander_resume_delay_timer_timeout() -> void:
	#print("signal - wander resume delay timeout")
	#print(last_point_of_interest_index)
	set_current_state(STATE.WANDER_RESUME)
	
func _on_point_of_interest_duration_timer_timeout() -> void:
	#print("signal - point of interest duration timeout")
	set_current_state(STATE.WANDER)
#endregion
