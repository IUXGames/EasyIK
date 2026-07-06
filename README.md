# EasyIK

[![Godot 4](https://img.shields.io/badge/Godot-4.6+-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Version](https://img.shields.io/badge/version-1.0.0-38bdf8)](./plugin.cfg)

**EasyIK** is a **universal 2D inverse-kinematics addon** for [**Godot 4**](https://godotengine.org/). It adds a single node—**`EasyIKManager`**—that can run any of four IK modifications, chosen from one selector in the inspector: **`2DLookAt`**, **`2DCCDIK`**, **`2DFABRIK`**, and **`2DTwoBoneIK`**.

Unlike Godot's built-in `SkeletonModification2D` stack, EasyIK stays **correct when your character is mirrored with `scale.x = -1`**—the exact scenario where native 2D IK deforms limbs. It captures the transform determinant each frame and folds that flip factor into every bone-angle term, so a mirrored rig bends exactly like the un-mirrored one, per-joint angle limits included.

You pick a modification, assign a target, build the bone chain in a dedicated window, and EasyIK rotates the bones to reach the target every frame—no per-limb sign flipping, no duplicate left/right rigs.

---

## 📑 Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Documentation](#documentation)
- [Project layout](#project-layout)
- [Changelog](#changelog)
- [Credits](#credits)

---

## ✨ Features

| | |
| :--- | :--- |
| **Single universal node** | One **`EasyIKManager`** picks its algorithm from a dropdown; the inspector shows only the fields that mode needs. |
| **Four modifications** | **`2DLookAt`** (aim one bone), **`2DTwoBoneIK`** (analytic arms/legs), **`2DCCDIK`** and **`2DFABRIK`** (N-bone chains). |
| **Flip-safe by design** | Correct under `scale.x = -1`, including per-joint angle limits—the reason the addon exists. |
| **Bone-chain manager** | A dedicated editor window to **add / remove / reorder** joints and pick each `Bone2D` from the scene tree, with full undo/redo. |
| **Per-joint angle limits** | Min / max, invert, local/global space—like native CCDIK constraints, with a **live wedge gizmo**. |
| **Soft IK** | `softness` eases the approach to full extension, killing the classic IK "pop." |
| **Smooth target follow** | `target_tracking_delay` follows the target with a critically-damped spring (frame-rate independent). |
| **Customizable gizmo** | Colors, line widths and sizes exposed in the inspector for bones, joints, target and constraint wedges. |
| **Editor integration** | Plugin registers the **`EasyIKManager`** node type and the **Manage Bone Chain** inspector window on enable. |
| **No autoload, no runtime deps** | Pure node addon—enable the plugin and add the node. |

---

## 📋 Requirements

| Item | Required? | Notes |
| :--- | :---: | :--- |
| **Godot 4.6+** | Yes | Developed and tested on Godot **4.6+** (see [`plugin.cfg`](./plugin.cfg)). 2D only. |
| **A `Skeleton2D` + `Bone2D` chain** | Yes | The bones EasyIK rotates. A single `Bone2D` is enough for `2DLookAt`. |
| **A `Node2D` target** | Yes | The point each chain reaches toward—often keyed by an `AnimationPlayer`. |

Expected install path in your project:

```text
res://addons/easyik/
```

---

## 📦 Installation

1. Copy this repository's `addons/easyik` folder into your Godot project under **`res://addons/easyik/`**.
2. Open **Project → Project Settings → Plugins**.
3. Enable **EasyIK** — the editor registers the **`EasyIKManager`** node type and the inspector integration (see [`plugin.gd`](./plugin.gd)).
4. Add an **`EasyIKManager`** node to your character and configure it in the inspector.

> **No code or autoload required.** The node registers via `class_name`; you only write code if you want to move targets or tweak EasyIK at runtime.

---

## 🚀 Quick start

### 1️⃣ Add a target

Create a `Node2D` where the tip of the limb should reach (e.g. `armTarget`) and place it where the hand currently is.

### 2️⃣ Add the EasyIKManager

Add an **`EasyIKManager`** node to your character. In the inspector:

- **Modification Type** → `2DTwoBoneIK`
- **Target** → drag your `armTarget`

### 3️⃣ Build the bone chain

Click **Manage Bone Chain** (in the *Bone Chain* group). In the window:

1. Click **＋ Add Joint** and assign the first bone (e.g. `shoulder`).
2. Click **＋ Add Joint** again and assign the second bone (e.g. `arm`).

The summary shows `shoulder → arm`. The limb now reaches toward the target. If the elbow bends the wrong way, tick **Flip Bend Direction**.

### 4️⃣ Drive the target

Key the target's position in an `AnimationPlayer`, or move it from code:

```gdscript
extends Node2D

@onready var arm_target: Node2D = $armTarget

func _process(_delta: float) -> void:
    # Make the hand follow the mouse.
    arm_target.global_position = get_global_mouse_position()
```

### 5️⃣ Flip the character correctly

Apply `scale.x = -1` to a **plain `Node2D` wrapper** that holds the skeleton **and** the targets—**not** to a `CharacterBody2D` (physics recomposition corrupts a mirrored transform). EasyIK keeps every limb and angle limit mirrored cleanly:

```gdscript
extends CharacterBody2D

@onready var visual: Node2D = $Visual   # holds Body + Bones + IKTargets
var _facing := 1

func _flip(direction: float) -> void:
    if direction == 0.0: return
    var f := signi(int(direction))
    if f != _facing:
        _facing = f
        visual.scale.x = f
```

*(Full field reference, the four modifications, joint limits and use-case recipes live in the docs.)*

---

## 📚 Documentation

The **official documentation** is a website:

Open **[EasyIK Official Documentation](https://iuxgames.github.io/EasyIK_WebSite/)** in your browser for the full interactive docs (section navigation, **EN / ES** language toggle, and **quick search**).

---

## 🗂 Project layout

```text
addons/easyik/
├── plugin.cfg                        # Plugin metadata
├── plugin.gd                         # EditorPlugin: registers the inspector plugin
├── core/
│   └── ik_enums.gd                   # EasyIKEnums: ModificationType, IKProcessMode
├── nodes/
│   ├── easy_ik_manager.gd            # EasyIKManager node — the four solvers + gizmo
│   └── editor/
│       ├── ik_inspector_plugin.gd    # Swaps chain fields for the "Manage Bone Chain" button
│       ├── ik_chain_button.gd        # Inspector button that opens the window
│       └── ik_chain_manager_window.gd# Add / remove / reorder joints + per-joint limits
├── icons/
│   └── icon_easy_ik.svg              # Node icon
└── webSite/                          # Documentation website (EN / ES)
```

---

## 📝 Changelog

### v1.0.0
- Initial public release.
- **`EasyIKManager`** node with four selectable modifications: **`2DLookAt`**, **`2DCCDIK`**, **`2DFABRIK`**, **`2DTwoBoneIK`**.
- **Flip-safe solvers** — correct bone rotations under `scale.x = -1` via determinant-based orientation, writing `global_rotation` directly.
- **Manage Bone Chain window** — explicit ordered joint list with scene-tree bone picker, reordering, removal, solver iterations, and full undo/redo.
- **Per-joint angle limits** — min / max, invert, local/global space, flip-invariant (measured in the parent bone's frame), with a live wedge gizmo.
- **Soft IK** (`softness`) and a critically-damped **target tracking delay** (`target_tracking_delay`).
- **Customizable gizmo** — colors, line widths and sizes for bones, joints, target and constraint wedges.

---

## 🙏 Credits

- **EasyIK** — **IUX Games**, **Isaackiux** · version **1.0.0** (see [`plugin.cfg`](./plugin.cfg)).
- Solver flip-handling technique inspired by the determinant-based approach used in community 2D IK addons.
