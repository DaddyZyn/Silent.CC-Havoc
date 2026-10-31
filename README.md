# Silent.CC // Havoc [Season 2]

A high-performance Luau tactical client menu for **Havoc**, built with an authentic C++ ImGui top-navbar architecture, zero image asset dependencies, and low-latency input telemetry.

## Quick Loadstring

To execute `silent.cc` directly in your environment, run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dist/silent_cc.luau"))()
```

Or using the root loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/init.luau"))()
```

---

## Architecture & Controls

* **Toggle Menu**: `[RightShift]` (rebindable)
* **Titlebar**: Fully draggable across viewports
* **Top Navigation Bar**: Instant tab switching (`Main`, `Esp`, `Visuals`, `Character`, `settings`)
* **Dual-Column Panels**:
  * **Main**: Aimbot & Silent Aim engines, FOV Circles, Hit Parts, Smoothing, Lead Prediction, Sticky Aim
  * **Esp**: 2D Bounding Boxes, Health Indicators, Snaplines, Distance & Name tags
  * **Visuals**: Chams / Highlight shaders, Dropped weapons & world ESP
  * **Character**: WalkSpeed & physics overrides, Weapon handling mods
  * **Settings**: Profile configuration & clean script unloading

---

## Repository Structure

```
├── init.luau             # Root loader for raw loadstring execution
├── README.md             # Documentation and usage instructions
├── dist/
│   └── silent_cc.luau    # Consolidated standalone client bundle
└── src/
    ├── main.luau         # Modular Havoc controller
    └── ui/
        └── library.luau  # Top-navbar tactical UI framework
```
