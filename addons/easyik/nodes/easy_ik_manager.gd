@tool
@icon("res://addons/easyik/icons/icon_easy_ik.svg")
class_name EasyIKManager
extends Node2D

## Universal 2D inverse-kinematics node.
##
## A single node that can run any of four IK modifications, chosen with the
## [member modification_type] selector in the inspector. Only the fields relevant
## to the selected modification are shown.
##
## Unlike Godot's native SkeletonModification2D stack, every solver here writes
## [member Node2D.global_rotation] with a determinant-based flip compensation, so
## the rig stays correct when a parent (e.g. the whole Skeleton2D) is mirrored with
## scale.x = -1. That is the reason this addon exists.
##
## The bone chain is an explicit ordered list of joints, built in the "Manage Bone
## Chain" window (Add / Remove / reorder, one Bone2D per joint) — the same workflow as
## Godot's native SkeletonModification2DCCDIK.


# ─── GENERAL ───────────────────────────────────────────────────────────────────

## If false, this manager does not modify any bones.
@export var enabled: bool = true

## The IK algorithm this manager runs. Changing it updates which fields are shown.
@export var modification_type: EasyIKEnums.ModificationType = EasyIKEnums.ModificationType.TWO_BONE_IK:
	set(value):
		modification_type = value
		notify_property_list_changed()
		if Engine.is_editor_hint():
			update_configuration_warnings()
			queue_redraw()

## Node the chain reaches toward. If left empty, the manager's own position is used.
@export var target: Node2D

## How strongly the modification is applied (0 = ignore, 1 = full). Blended per bone with lerp_angle.
@export_range(0.0, 1.0, 0.01) var strength: float = 1.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)

## Soft IK — how early (as a fraction of the chain's reach) the limb starts bending before full
## extension, so it eases toward the target instead of snapping straight then folding abruptly.
## 0 = hard/exact IK. ~0.15 gives natural motion. Applies to all chain modes.
@export_range(0.0, 1.0, 0.01) var softness: float = 0.15:
	set(value):
		softness = clampf(value, 0.0, 1.0)

## Delays the target the chain tracks with a critically-damped spring (roughly the seconds it takes
## to catch up). 0 = track instantly. Small values like 0.06–0.20 remove the abrupt velocity jumps
## from linearly-keyed IK controllers without much noticeable lag.
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:s") var target_tracking_delay: float = 0.0:
	set(value):
		target_tracking_delay = maxf(value, 0.0)

## Whether the solver runs on idle frames (_process) or physics frames (_physics_process).
## Match this to the AnimationPlayer that drives the target so IK runs after it.
@export var ik_process_mode: EasyIKEnums.IKProcessMode = EasyIKEnums.IKProcessMode.PROCESS:
	set(value):
		ik_process_mode = value
		_apply_process_mode()


# ─── LOOK AT ───────────────────────────────────────────────────────────────────

@export_group("Look At")

## (LookAt) The bone that will point at the target.
@export var bone: Bone2D:
	set(value):
		bone = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

## (LookAt) Extra angle added to the aim direction, in degrees.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var angle_offset: float = 0.0


# ─── BONE CHAIN (CCDIK / FABRIK / TwoBoneIK) ───────────────────────────────────
# The chain is edited in the "Manage Bone Chain" window; the inspector plugin turns
# `manage_chain` into the button that opens it.

@export_group("Bone Chain")

## Anchor for the inspector "Manage Bone Chain" button (never stored, never a real value).
@export var manage_chain: bool = false

## (CCDIK / FABRIK) Solver passes per frame. Higher converges faster but costs more.
@export_range(1, 16) var iterations: int = 1:
	set(value):
		iterations = clampi(value, 1, 16)


# ─── TWO BONE IK ───────────────────────────────────────────────────────────────

@export_group("Two Bone")

## (TwoBoneIK) Flips which side the middle joint bends toward.
@export var flip_bend_direction: bool = false


# ─── GIZMO ─────────────────────────────────────────────────────────────────────

@export_group("Gizmo", "gizmo_")

## Master toggle for the editor viewport gizmo.
@export var gizmo_enabled: bool = true:
	set(value):
		gizmo_enabled = value
		if Engine.is_editor_hint():
			queue_redraw()

## Draw the allowed-rotation wedge for each constrained joint (CCDIK / FABRIK).
@export var gizmo_show_constraints: bool = true:
	set(value):
		gizmo_show_constraints = value
		if Engine.is_editor_hint():
			queue_redraw()

## Radius of the target marker, in pixels.
@export_range(2.0, 64.0, 0.5, "or_greater", "suffix:px") var gizmo_target_size: float = 10.0:
	set(value):
		gizmo_target_size = value
		if Engine.is_editor_hint():
			queue_redraw()

@export_subgroup("Colors", "gizmo_col_")
## Color of the bone segments.
@export var gizmo_col_bone: Color = Color(0.36, 0.74, 1.0, 0.95)
## Color of the intermediate joint dots.
@export var gizmo_col_joint: Color = Color(0.20, 0.52, 0.95, 1.0)
## Color of the chain-root dot.
@export var gizmo_col_root: Color = Color(0.55, 1.0, 0.65, 1.0)
## Color of the target marker.
@export var gizmo_col_target: Color = Color(1.0, 0.68, 0.22, 0.6)
## Fill color of the constraint wedge (alpha controls transparency).
@export var gizmo_col_constraint_fill: Color = Color(0.35, 0.85, 0.45, 0.16)
## Edge color of the constraint wedge.
@export var gizmo_col_constraint_edge: Color = Color(0.45, 0.95, 0.55, 0.6)

@export_subgroup("Sizes", "gizmo_")
## Width of the bone segment lines, in pixels.
@export_range(0.5, 10.0, 0.5, "or_greater") var gizmo_bone_width: float = 3.0
## Radius of the joint dots, in pixels.
@export_range(2.0, 16.0, 0.5, "or_greater") var gizmo_joint_radius: float = 5.5
## Width of the target marker lines (ring + crosshair), in pixels.
@export_range(0.5, 10.0, 0.5, "or_greater") var gizmo_target_width: float = 0.5
## Width of the constraint wedge edge lines, in pixels.
@export_range(0.5, 10.0, 0.5, "or_greater") var gizmo_constraint_width: float = 0.5


# ─── INTERNAL STATE ────────────────────────────────────────────────────────────

## The joint list. One entry per joint, in root → tip order. Each is a Dictionary:
##   { "bone": NodePath, "enabled": bool, "min": float, "max": float, "invert": bool, "localspace": bool }
## Hidden from the inspector — edited via the "Manage Bone Chain" window. Exported so it serializes.
@export var _joints: Array[Dictionary] = []

var _chain: Array[Bone2D] = []  # Resolved bones, parallel to _joints (null where unassigned).

# Critically-damped spring state for target_tracking_delay.
var _smoothed_target: Vector2 = Vector2.ZERO
var _target_velocity: Vector2 = Vector2.ZERO
var _target_ready: bool = false  # False until the first solve snaps the smoothed target to the raw one.


# ─── LIFE CYCLE ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Run after the AnimationPlayer (priority 0) has written the target positions.
	process_priority = 1000
	process_physics_priority = 1000
	_resolve_chain()
	_smoothed_target = _raw_target_position()
	_apply_process_mode()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	_solve(delta)


func _physics_process(delta: float) -> void:
	_solve(delta)


func _apply_process_mode() -> void:
	set_process(ik_process_mode == EasyIKEnums.IKProcessMode.PROCESS)
	set_physics_process(ik_process_mode == EasyIKEnums.IKProcessMode.PHYSICS_PROCESS)


# ─── DISPATCH ──────────────────────────────────────────────────────────────────

func _solve(delta: float) -> void:
	if not enabled:
		return
	_update_smoothed_target(delta)
	match modification_type:
		EasyIKEnums.ModificationType.LOOK_AT:
			_solve_look_at()
		EasyIKEnums.ModificationType.CCDIK:
			_solve_ccdik()
		EasyIKEnums.ModificationType.FABRIK:
			_solve_fabrik()
		EasyIKEnums.ModificationType.TWO_BONE_IK:
			_solve_two_bone()


# ─── SOLVER: LOOK AT ───────────────────────────────────────────────────────────

func _solve_look_at() -> void:
	if bone == null:
		return
	var scale_orient := signf(bone.global_transform.determinant())
	var to_target := _target_position() - bone.global_position
	var aim := to_target.angle() - (bone.get_bone_angle() - angle_offset) * scale_orient
	bone.global_rotation = lerp_angle(bone.global_rotation, aim, strength)


# ─── SOLVER: TWO BONE IK ───────────────────────────────────────────────────────

func _solve_two_bone() -> void:
	if not _chain_complete(2):
		return
	var joint_one := _chain[0]
	var joint_two := _chain[1]
	var scale_orient := signf(joint_one.global_transform.determinant())

	var first_bone_vector := joint_two.position * joint_one.global_scale
	var second_bone_vector := Vector2(joint_two.get_length(), 0.0) \
			.rotated(joint_two.get_bone_angle() * scale_orient) * joint_two.global_scale.abs()

	var target_pos := _target_position()
	var target_vector := _two_bone_target_vector(joint_one, target_pos, first_bone_vector, second_bone_vector)

	var bend := -1.0 if flip_bend_direction else 1.0
	var l1 := first_bone_vector.length()
	var l2 := second_bone_vector.length()

	var rot_one: float
	if _two_bone_unreachable(target_vector, l1, l2):
		rot_one = PI * float(l1 < l2) + target_vector.angle()
	else:
		var cos_a := clampf(_cos_from_sides(l1, target_vector.length(), l2), -1.0, 1.0)
		rot_one = acos(cos_a) * bend * scale_orient \
				+ (target_pos - joint_one.global_position).angle() \
				- first_bone_vector.angle()
	joint_one.global_rotation = lerp_angle(joint_one.global_rotation, rot_one, strength)

	var rot_two := (target_pos - joint_two.global_position).angle() - second_bone_vector.angle()
	joint_two.global_rotation = lerp_angle(joint_two.global_rotation, rot_two, strength)


func _cos_from_sides(a: float, b: float, c: float) -> float:
	if a > 0.0 and b > 0.0:
		return (a * a + b * b - c * c) / (2.0 * a * b)
	return 0.0


func _two_bone_unreachable(target_vector: Vector2, l1: float, l2: float) -> bool:
	return target_vector.length() < 0.001 or target_vector.length() < absf(l1 - l2)


func _two_bone_target_vector(joint_one: Bone2D, target_pos: Vector2, first_vec: Vector2, second_vec: Vector2) -> Vector2:
	var raw := target_pos - joint_one.global_position
	var length_difference := absf(first_vec.length() - second_vec.length())
	var full_length := (first_vec.length() + second_vec.length()) - length_difference
	if full_length <= 0.0:
		return raw
	var distance_ratio := (raw.length() - length_difference) / full_length
	if softness > 0.0 and distance_ratio < (1.0 + softness) and distance_ratio > (1.0 - softness):
		return raw.normalized() * (length_difference + full_length * _softness_result(distance_ratio))
	return raw


func _softness_result(a: float) -> float:
	return -(0.25 * (a - 1.0 - softness) * (a - 1.0 - softness) / softness) + 1.0


# ─── SOLVER: CCDIK ─────────────────────────────────────────────────────────────

func _solve_ccdik() -> void:
	if not _chain_complete(2):
		return
	var scale_orient := signf(_chain[0].global_transform.determinant())
	var tip_bone := _chain[_chain.size() - 1]
	var target_pos := _soft_target(_chain[0].global_position, _target_position())

	for _pass in iterations:
		for j in range(_chain.size() - 1, -1, -1):
			var joint := _chain[j]
			var end_effector := _bone_tip_position(tip_bone)
			var to_end := end_effector - joint.global_position
			var to_target := target_pos - joint.global_position
			if to_end.length() < 0.0001 or to_target.length() < 0.0001:
				continue
			var child_point := end_effector if j == _chain.size() - 1 else _chain[j + 1].global_position
			var current_aim := (child_point - joint.global_position).angle()
			var world_delta := to_end.angle_to(to_target)
			var new_aim := current_aim + world_delta * strength
			joint.global_rotation = new_aim - joint.get_bone_angle() * scale_orient
			_apply_joint_constraint(joint, j)


# ─── SOLVER: FABRIK ────────────────────────────────────────────────────────────

func _solve_fabrik() -> void:
	if not _chain_complete(2):
		return
	var scale_orient := signf(_chain[0].global_transform.determinant())
	var target_pos := _soft_target(_chain[0].global_position, _target_position())

	var base_point := _chain[0].global_position
	var joint_points: PackedVector2Array = []
	var limb_lengths: PackedFloat32Array = []
	for b in _chain:
		joint_points.append(b.global_position)
		limb_lengths.append(b.get_length())
	joint_points.append(_bone_tip_position(_chain[_chain.size() - 1]))

	for _pass in iterations:
		joint_points[joint_points.size() - 1] = target_pos
		for i in range(joint_points.size() - 1, 0, -1):
			var back_dir := joint_points[i].angle_to_point(joint_points[i - 1])
			joint_points[i - 1] = joint_points[i] + Vector2(limb_lengths[i - 1], 0.0).rotated(back_dir)
		joint_points[0] = base_point
		for i in range(joint_points.size() - 1):
			var fwd_dir := joint_points[i].angle_to_point(joint_points[i + 1])
			joint_points[i + 1] = joint_points[i] + Vector2(limb_lengths[i], 0.0).rotated(fwd_dir)

	for i in _chain.size():
		var aim := joint_points[i].angle_to_point(joint_points[i + 1])
		var rot := aim - _chain[i].get_bone_angle() * scale_orient
		_chain[i].global_rotation = lerp_angle(_chain[i].global_rotation, rot, strength)
		_apply_joint_constraint(_chain[i], i)


# ─── CONSTRAINTS ───────────────────────────────────────────────────────────────

## Clamps a joint so its bone aim stays within the configured angle limits (no-op if
## disabled). The clamp is expressed on the bone's aim relative to a reference direction —
## exactly the same quantity the gizmo draws, so the two always agree.
func _apply_joint_constraint(joint: Bone2D, index: int) -> void:
	if index < 0 or index >= _joints.size():
		return
	var d: Dictionary = _joints[index]
	if not d.get("enabled", false):
		return
	var localspace: bool = d.get("localspace", true)
	var scale_orient := signf(joint.global_transform.determinant())
	var rel := _joint_relative_angle(joint, localspace)
	var clamped := _clamp_angle(rel, d.get("min", -PI), d.get("max", PI), d.get("invert", false))
	joint.global_rotation = _joint_world_aim(joint, localspace, clamped) - joint.get_bone_angle() * scale_orient


## The bone's aim expressed in its constraint reference frame. Local space uses the parent's actual
## frame via basis_xform, so a mirrored (scale.x = -1) pose maps to the SAME relative angle — the
## limit is flip-invariant. (Reads identically to the old parent.global_rotation math at scale = 1.)
func _joint_relative_angle(joint: Bone2D, localspace: bool) -> float:
	var dir := _bone_tip_position(joint) - joint.global_position
	var parent := joint.get_parent()
	if localspace and parent is Node2D:
		return (parent as Node2D).global_transform.affine_inverse().basis_xform(dir).angle()
	return dir.angle()


## Maps a reference-frame angle back to the bone's world aim direction angle (inverse of above).
func _joint_world_aim(joint: Bone2D, localspace: bool, rel_angle: float) -> float:
	var parent := joint.get_parent()
	if localspace and parent is Node2D:
		return (parent as Node2D).global_transform.basis_xform(Vector2.from_angle(rel_angle)).angle()
	return rel_angle


## Port of Godot's SkeletonModification2D.clamp_angle — snaps an out-of-range angle to
## whichever bound is nearest. invert flips the allowed region to the outside of [min, max].
func _clamp_angle(angle: float, min_bound: float, max_bound: float, invert: bool) -> float:
	if angle < 0.0:
		angle += TAU
	if min_bound < 0.0:
		min_bound += TAU
	if max_bound < 0.0:
		max_bound += TAU
	if min_bound > max_bound:
		var tmp := min_bound
		min_bound = max_bound
		max_bound = tmp

	var out_of_range := false
	if not invert:
		out_of_range = angle < min_bound or angle > max_bound
	else:
		out_of_range = angle > min_bound and angle < max_bound
	if out_of_range:
		var min_vec := Vector2(cos(min_bound), sin(min_bound))
		var max_vec := Vector2(cos(max_bound), sin(max_bound))
		var ang_vec := Vector2(cos(angle), sin(angle))
		angle = min_bound if ang_vec.distance_squared_to(min_vec) <= ang_vec.distance_squared_to(max_vec) else max_bound
	return angle


# ─── HELPERS ───────────────────────────────────────────────────────────────────

## The (possibly smoothed) world position the solvers aim at.
func _target_position() -> Vector2:
	return _smoothed_target


## Raw controller position, before smoothing.
func _raw_target_position() -> Vector2:
	return target.global_position if target != null else global_position


## Total straight-line reach of the current chain.
func _chain_reach() -> float:
	var total := 0.0
	for b in _chain:
		if b != null:
			total += b.get_length()
	return total


## Soft IK: as the target approaches full reach, ease the effective target so it asymptotically
## approaches (never quite reaches) the fully-extended distance. This makes the chain start bending
## earlier and smoothly, removing the "stays straight then snaps" pop near full extension.
func _soft_target(root_pos: Vector2, target_pos: Vector2) -> Vector2:
	if softness <= 0.0:
		return target_pos
	var reach := _chain_reach()
	if reach <= 0.0:
		return target_pos
	var to := target_pos - root_pos
	var dist := to.length()
	if dist < 0.0001:
		return target_pos
	var margin := reach * softness       # width of the soft zone below full reach
	var knee := reach - margin           # start easing here
	if dist <= knee:
		return target_pos
	var t := (dist - knee) / maxf(margin, 0.0001)
	var soft_dist := knee + margin * (1.0 - exp(-t))
	return root_pos + to.normalized() * soft_dist


## Advances the smoothed target toward the raw one with a critically-damped spring.
func _update_smoothed_target(delta: float) -> void:
	var raw := _raw_target_position()
	if not _target_ready or target_tracking_delay <= 0.0 or delta <= 0.0:
		_smoothed_target = raw
		_target_velocity = Vector2.ZERO
		_target_ready = true
		return
	_smoothed_target = _smooth_damp(_smoothed_target, raw, delta)


## Unity-style SmoothDamp: eases `current` toward `target_pos` with continuous velocity (no
## overshoot), tracking `_target_velocity`. Frame-rate independent.
func _smooth_damp(current: Vector2, target_pos: Vector2, delta: float) -> Vector2:
	var smooth_time := maxf(0.0001, target_tracking_delay)
	var omega := 2.0 / smooth_time
	var x := omega * delta
	var factor := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target_pos
	var temp := (_target_velocity + omega * change) * delta
	_target_velocity = (_target_velocity - omega * temp) * factor
	return target_pos + (change + temp) * factor


## World position of a bone's far end, via to_global so it is exact under any parent scale.
func _bone_tip_position(b: Bone2D) -> Vector2:
	var length := b.get_length()
	if length <= 0.0:
		return b.global_position
	return b.to_global(Vector2(length, 0.0).rotated(b.get_bone_angle()))


## Resolves the joint list into `_chain` (parallel, null where a joint has no valid bone).
func _resolve_chain() -> void:
	_chain.clear()
	for j in _joints:
		var path: NodePath = j.get("bone", NodePath())
		var resolved: Bone2D = null
		if not path.is_empty():
			resolved = get_node_or_null(path) as Bone2D
		_chain.append(resolved)
	if Engine.is_editor_hint():
		queue_redraw()


## True when the chain has at least `min_count` joints and every one resolves to a Bone2D.
func _chain_complete(min_count: int) -> bool:
	if _chain.size() < min_count:
		return false
	for b in _chain:
		if b == null:
			return false
	return true


func _default_joint() -> Dictionary:
	return {
		"bone": NodePath(),
		"enabled": false,
		"min": deg_to_rad(-90.0),
		"max": deg_to_rad(90.0),
		"invert": false,
		"localspace": true,
	}


func _uses_joint_chain() -> bool:
	return modification_type == EasyIKEnums.ModificationType.CCDIK \
			or modification_type == EasyIKEnums.ModificationType.FABRIK


# ─── PUBLIC API (used by the "Manage Bone Chain" window) ───────────────────────

## True when the selected modification exposes per-joint angle limits.
func uses_joint_constraints() -> bool:
	return _uses_joint_chain()


## Number of joints in the list.
func get_joint_count() -> int:
	return _joints.size()


## The bone path assigned to a joint (may be empty).
func get_joint_bone_path(index: int) -> NodePath:
	if index < 0 or index >= _joints.size():
		return NodePath()
	return _joints[index].get("bone", NodePath())


## Display name of the joint's bone, or a placeholder when unassigned / missing.
func get_joint_bone_name(index: int) -> String:
	var path := get_joint_bone_path(index)
	if path.is_empty():
		return "(unassigned)"
	var b := get_node_or_null(path)
	return String(b.name) if b is Bone2D else "(missing)"


## A copy of a joint's data ({bone, enabled, min, max, invert, localspace}).
func get_joint_data(index: int) -> Dictionary:
	if index < 0 or index >= _joints.size():
		return _default_joint()
	return _joints[index].duplicate()


## A fresh default joint dictionary (used by the window's "Add Joint").
func new_joint_dict() -> Dictionary:
	return _default_joint()


## A deep-ish copy of the whole joint list, for undo/redo snapshots.
func get_joints_copy() -> Array:
	var out: Array = []
	for j in _joints:
		out.append(j.duplicate())
	return out


## Replaces the whole joint list (the single mutation entry point; used with undo/redo).
func set_joints(new_joints: Array) -> void:
	var rebuilt: Array[Dictionary] = []
	for j in new_joints:
		if j is Dictionary:
			rebuilt.append((j as Dictionary).duplicate())
	_joints = rebuilt
	_resolve_chain()
	if Engine.is_editor_hint():
		update_configuration_warnings()


## Human-readable "bone → … → tip" summary of the current chain.
func get_chain_summary() -> String:
	if _joints.is_empty():
		return "No joints yet — click \"Add Joint\"."
	var names: PackedStringArray = []
	for i in _joints.size():
		names.append(get_joint_bone_name(i))
	return " → ".join(names)


# ─── INSPECTOR ─────────────────────────────────────────────────────────────────

func _validate_property(property: Dictionary) -> void:
	var pname := String(property.name)
	if pname == "_joints":
		property.usage = PROPERTY_USAGE_STORAGE  # Serialize, but never show the raw array.
		return
	var m := modification_type
	var visible := true
	match pname:
		"bone", "angle_offset":
			visible = m == EasyIKEnums.ModificationType.LOOK_AT
		"manage_chain":
			# Editor-only anchor (no storage) for the inspector button; hidden for LookAt.
			if m == EasyIKEnums.ModificationType.LOOK_AT:
				visible = false
			else:
				property.usage = PROPERTY_USAGE_EDITOR
				return
		"iterations":
			visible = false  # Edited inside the "Manage Bone Chain" window.
		"softness":
			visible = m != EasyIKEnums.ModificationType.LOOK_AT
		"flip_bend_direction":
			visible = m == EasyIKEnums.ModificationType.TWO_BONE_IK
		"gizmo_show_constraints":
			visible = _uses_joint_chain()
		_:
			return
	if not visible:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	match modification_type:
		EasyIKEnums.ModificationType.LOOK_AT:
			if bone == null:
				warnings.append("Assign a Bone for LookAt.")
		_:
			if _joints.size() < 2:
				warnings.append("Open \"Manage Bone Chain\" and add at least two joints.")
			elif not _chain_complete(2):
				warnings.append("Every joint in the chain must have a Bone2D assigned.")
	return warnings


# ─── GIZMO ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not Engine.is_editor_hint() or not gizmo_enabled:
		return

	var bones: Array[Bone2D] = []
	if modification_type == EasyIKEnums.ModificationType.LOOK_AT:
		if bone != null:
			bones.append(bone)
	else:
		bones = _chain

	# Bone segments + constraint arcs.
	for i in bones.size():
		var b := bones[i]
		if b == null:
			continue
		var a := to_local(b.global_position)
		var t := to_local(_bone_tip_position(b))
		draw_line(a, t, gizmo_col_bone, gizmo_bone_width, true)
		if _uses_joint_chain() and gizmo_show_constraints:
			_draw_joint_limits(b, i, a)

	# Joint dots (on top of the segments).
	for i in bones.size():
		var b := bones[i]
		if b == null:
			continue
		var a := to_local(b.global_position)
		var core := gizmo_col_root if i == 0 else gizmo_col_joint
		draw_circle(a, gizmo_joint_radius, Color(0.9, 0.95, 1.0, 1.0))
		draw_circle(a, gizmo_joint_radius * 0.62, core)

	_draw_target(to_local(_target_position()))


func _draw_target(center: Vector2) -> void:
	var r := gizmo_target_size
	draw_arc(center, r, 0.0, TAU, 32, gizmo_col_target, gizmo_target_width, true)
	draw_line(center - Vector2(r * 1.4, 0), center + Vector2(r * 1.4, 0), gizmo_col_target, gizmo_target_width, true)
	draw_line(center - Vector2(0, r * 1.4), center + Vector2(0, r * 1.4), gizmo_col_target, gizmo_target_width, true)
	draw_circle(center, gizmo_target_width, gizmo_col_target)


## Draws the allowed rotation wedge for a constrained joint. Uses the SAME reference and the
## SAME normalized bounds as _apply_joint_constraint, so the wedge is exactly the region the
## bone is clamped into — the gizmo and the solver never disagree.
func _draw_joint_limits(b: Bone2D, index: int, center: Vector2) -> void:
	if index >= _joints.size():
		return
	var d: Dictionary = _joints[index]
	if not d.get("enabled", false):
		return

	var localspace: bool = d.get("localspace", true)
	var lo: float = d.get("min", -PI)
	var hi: float = d.get("max", PI)
	if lo < 0.0:
		lo += TAU
	if hi < 0.0:
		hi += TAU
	if lo > hi:
		var swap := lo
		lo = hi
		hi = swap

	# Allowed reference-frame band (complement when inverted).
	var start := lo
	var end := hi
	if d.get("invert", false):
		start = hi
		end = lo + TAU

	# Sample the band in reference-frame angles and map each to a world point via the same frame
	# mapping the solver uses, then to_local — so the wedge is flip-safe and matches the clamp.
	var radius := clampf(b.get_length() * 0.6, 14.0, 48.0)
	var segments := 32
	var arc: PackedVector2Array = []
	for s in range(segments + 1):
		var rel := lerpf(start, end, float(s) / float(segments))
		var world_aim := _joint_world_aim(b, localspace, rel)
		arc.append(to_local(b.global_position + Vector2.from_angle(world_aim) * radius))

	var fan: PackedVector2Array = [center]
	fan.append_array(arc)
	draw_colored_polygon(fan, gizmo_col_constraint_fill)
	draw_polyline(arc, gizmo_col_constraint_edge, gizmo_constraint_width, true)
	draw_line(center, arc[0], gizmo_col_constraint_edge, gizmo_constraint_width, true)
	draw_line(center, arc[arc.size() - 1], gizmo_col_constraint_edge, gizmo_constraint_width, true)
