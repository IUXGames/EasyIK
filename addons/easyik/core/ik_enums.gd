class_name EasyIKEnums

## Shared enums for the EasyIK addon.
## Kept in a dedicated class so the node script and any future editor helpers
## reference the same identifiers.


## The inverse-kinematics algorithm an EasyIKManager runs.
enum ModificationType {
	LOOK_AT     = 0,  ## Points a single bone at the target (2DLookAt).
	CCDIK       = 1,  ## Cyclic Coordinate Descent over a bone chain (2DCCDIK).
	FABRIK      = 2,  ## Forward And Backward Reaching IK over a bone chain (2DFABRIK).
	TWO_BONE_IK = 3,  ## Analytic law-of-cosines solve for exactly two bones (2DTwoBoneIK).
}


## When the solver runs relative to the game loop.
## Match this to the AnimationPlayer's callback mode so IK runs AFTER the
## animation writes the target positions.
enum IKProcessMode {
	PROCESS         = 0,  ## Runs in _process (idle frames).
	PHYSICS_PROCESS = 1,  ## Runs in _physics_process (physics frames).
}
