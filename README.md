# EasyIK
EasyIK is a universal 2D inverse-kinematics addon for Godot 4.6+. It adds a single node — EasyIKManager — that can run any of four IK modifications, chosen from one selector in the inspector, and it stays correct when your character is mirrored with scale.x = -1 — the exact scenario where Godot's built-in SkeletonModification2D stack deforms limbs.
