# Silent.CC // Havoc [Season 2]

A high-performance Luau tactical client menu for **Havoc**, built with an authentic C++ ImGui top-navbar architecture, zero image asset dependencies, expanded 680x720 geometry, and low-latency input telemetry.

## Quick Loadstring

To execute `silent.cc` directly in your environment, run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dist/silent_cc.luau", true))()
```

Or using the root loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/init.luau", true))()
```

---

## Havoc Introspection Dumper

To dump network remotes, weapon modules, GC tables, and bone rigs for Havoc reverse engineering:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dumper.luau", true))()
```
*Outputs to `havoc_dump.json` in your executor's workspace folder and copies raw JSON directly to clipboard.*

---

## Architecture & Controls

* **Toggle Menu**: `[RightShift]` (rebindable)
* **Titlebar**: Fully draggable across viewports (clean minimal header, no action buttons)
* **Top Navigation Bar**: Sequential tab switching (`Main`, `Esp`, `Visuals`, `Character`, `settings`)
* **Dual-Column Panels**:
  * **Main**: Aimbot & Silent Aim engines, FOV Circles, Hit Parts, Smoothing, Lead Prediction, Sticky Aim
  * **Esp**: 2D Bounding Boxes, Health Indicators, Snaplines, Distance & Name tags
  * **Visuals**: Chams / Highlight shaders, Dropped weapons & world ESP
  * **Character**: WalkSpeed & physics overrides, Weapon handling mods
  * **Settings**: Profile configuration & clean script unloading

---

## Repository Structure

```
├── init.luau             # Root loader with 404 validation
├── dumper.luau           # Client introspection & weapon dumper
├── README.md             # Documentation and usage instructions
├── dist/
│   └── silent_cc.luau    # Expanded standalone client bundle (680x720)
└── src/
    ├── main.luau         # Modular Havoc controller
    └── ui/
        └── library.luau  # Top-navbar tactical UI framework
```
