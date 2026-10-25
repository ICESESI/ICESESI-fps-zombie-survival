# ICE ZOMBIE SURVIVAL — ULTIMATE EDITION

## Implemented in this source update
- Preserved the existing procedural Godot 4.4 project and its Android export workflow.
- Added sprint with stamina drain/recovery and crouch toggle controls.
- Added persistent horizontal/vertical look sensitivity values (defaults retained; settings UI is not yet built).
- Added headshot damage multiplier (2x when the ray hits the named Head mesh).
- Added randomized Walker, Runner, Brute, Armored and Toxic zombie archetypes with different speed/HP/damage/armor traits.
- Added three boss difficulty phases based on remaining health for HILMI JR PRO.
- Added a reusable WeaponCatalog script with data for the five weapon types already represented in the prototype.
- Renamed the project to ICE ZOMBIE SURVIVAL — ULTIMATE EDITION.

## Important limitations
- This is a staged overhaul of the supplied prototype, not all 20 sections of the master prompt completed.
- Zombie models are still procedural built-in meshes, not professionally rigged external models.
- No external animation/audio/texture packs were supplied; the game has no professional asset pack bundled.
- Full navigation mesh pathfinding, 20 enemy types, all weapon classes, campaign/quests/crafting, full settings UI, object pooling and multi-map campaign remain future work.
- Godot executable is not installed in the current environment, so parser/runtime validation and Android APK export could not be run here. Build with the repository GitHub Actions workflow and test on-device before release.
