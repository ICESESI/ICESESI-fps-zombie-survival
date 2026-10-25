extends RefCounted
class_name WeaponCatalog

# Data catalog used by future modular weapon scenes. Values are gameplay tuning,
# not a claim that professional weapon models/audio are bundled.
const WEAPONS := {
    "pistol": {"label": "Pistol", "damage": 50, "fire_rate": 0.28, "magazine": 12, "reload": 1.15, "rarity": "common", "cost": 0},
    "smg": {"label": "SMG", "damage": 38, "fire_rate": 0.12, "magazine": 30, "reload": 1.45, "rarity": "common", "cost": 250},
    "rifle": {"label": "Assault Rifle", "damage": 100, "fire_rate": 0.42, "magazine": 8, "reload": 1.7, "rarity": "rare", "cost": 500},
    "shotgun": {"label": "Shotgun", "damage": 80, "fire_rate": 0.75, "magazine": 6, "reload": 1.9, "rarity": "rare", "cost": 650},
    "sniper": {"label": "Sniper Rifle", "damage": 180, "fire_rate": 0.9, "magazine": 5, "reload": 2.2, "rarity": "epic", "cost": 900}
}

static func get_weapon(key: String) -> Dictionary:
    return WEAPONS.get(key, WEAPONS["pistol"]).duplicate(true)

static func keys() -> Array:
    return WEAPONS.keys()
