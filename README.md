# Generative Design — animation_demo

This folder contains a Processing sketch that renders animated particle stripes, motion-driven waves and a rain layer. The sketch fetches or simulates weather and river discharge data used to drive visual parameters.

Files documented in the sketch:
- `animation_demo/animation_demo.pde` — main sketch (entry point)
- `animation_demo/api.pde`       — API fetching and simulated weather helpers
- `animation_demo/MotionParticle.pde` — motion particle helper class
- `animation_demo/particle.pde`  — background particle class
- `animation_demo/raindrop.pde`  — raindrop class
- `animation_demo/waveevent.pde` — wave event struct

# Generative Design — animation_demo

This project is a Processing sketch that renders animated particle stripes, motion-driven waves and a rain layer. Visual behaviour is driven by live
or simulated weather/flood data.

This README centralises documentation for the main files and explains how to run the sketch.

File reference
--------------

### animation_demo/animation_demo.pde — Main sketch (entry point)

- Responsibilities: canvas setup, main `draw()` loop, camera reading, motion detection, composing particles/waves/rain, drawing debug overlays.
- Important flags:
  - `SHOW_CAMERA_PREVIEW` (bool): show/hide camera preview overlay.
  - `SHOW_INFO_PANEL` (bool): show/hide API/time info panel.
  - `debugHourOverride` (int): when >= 0 forces displayed hour.
  - `FAST_TIME_MODE` / `FAST_TIME_SECONDS`: when active compresses 24h to N seconds.
- Key interactions: `addWave(x,intensity)` is called on motion detection.

### animation_demo/api.pde — API fetching and simulated weather helpers

- Responsibilities: fetch precipitation and river discharge from Open-Meteo, maintain cached values, expose helpers used by the sketch.
- Exposed helpers:
  - `getPrecipIntensity()` → float 0..1 used to spawn raindrops.
  - `getDischargeAmplitude()` → controls wave amplitude multiplier.
  - `getDischargeSpeedMultiplier()` → controls wave aging/speed multiplier.
- Important flags and values (edit as needed):
  - `SIMULATED_RAIN_MODE` (bool)
  - `FORCE_SIMULATED_RAIN` (bool) — force noise-driven rain even if API returns values
  - `SIMULATED_RAIN_MAX`, `SIMULATED_RAIN_SPEED`
  - `FORCE_MAX_DISCHARGE` (bool) and `MAX_DISCHARGE_VALUE`
- Notes: `httpGet()` performs the HTTP GET with timeouts; network errors will be logged to the console. The file also reads/writes `api_cache.txt`.

### animation_demo/MotionParticle.pde — `MotionParticle` class

- Small, short-lived particles added on motion detection. Methods:
  - `update()` updates position/life.
  - `display()` renders to the `canvas` PGraphics.

### animation_demo/particle.pde — `Particle` class

- Background particles used to form the base animated stripes. Methods:
  - `update()` computes noise-driven motion.
  - `display()` draws each particle to the `canvas`.

### animation_demo/raindrop.pde — `RainDrop` class

- Models individual raindrops: position, length, speed and brightness.
- Methods:
  - `update()` advances the drop each frame.
  - `display()` draws vertical points representing the drop.
- Spawning: `animation_demo.pde` spawns `RainDrop` instances using
  `getPrecipIntensity()`.

### animation_demo/waveevent.pde — `WaveEvent` struct

- Lightweight event with fields: `x`, `intensity`, `age`.
- Created by `addWave()` and consumed during per-column wave synthesis.

How to run
----------

Prerequisites:

- Install Processing (https://processing.org/download/). Use Processing 3.x

Run in the Processing IDE:

1. Open Processing.
2. Choose `File -> Open...` and open the `animation_demo` folder (select
   `animation_demo.pde`).
3. Click the Run button (play icon).
