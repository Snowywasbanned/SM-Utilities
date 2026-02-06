# SM Utilities
Useful commands and includes for server owners & plugin developers alike.

### [[Download Here](https://github.com/Serider-Lounge/SM-Utilities/actions)]

# Includes
## Heapons

| Include | Description |
|---------|-------------|
| `chat.inc` | Chat utilities |
| `steam.inc` | Steam utilities |
| `tf2.inc` | Team Fortress 2 utilities<br>ℹ️ Compatible with [mods](https://store.steampowered.com/mods/440/) too!|

# Plugins
## <img src="https://shared.fastly.steamstatic.com/community_assets/images/apps/3545060/08607ace82bfb52cf8993efe88c2ef00fa25c96f.ico" width="24" height="24" style="vertical-align: text-bottom;"> TF2 Classified Tools

### Admin Commands

| Command | Usage | Description |
|---------|-------|-------------|
| sm_setteam / sm_team | `[target] <team>` | Set player's team |
| sm_setclass / sm_class | `[target] <class>` | Set player's class |
| sm_respawn | `[target]` | Force respawn player(s) |
| sm_health | `[target] <amount>` | Set player's health |
| sm_maxhealth | `[target] <amount>` | Set player's max health |
| sm_currency | `[target] <amount>` | Set player's currency |
| sm_scale | `[target] <amount>` | Set player's scale |
| sm_addattr / sm_addattribute | `[target] <attribute> [value] [duration]` | Add attribute to player |
| sm_removeattr / sm_removeattribute | `[target] <attribute>` | Remove attribute from player |
| sm_getattr / sm_getattribute | `[target] <attribute>` | Get attribute value from player |
| sm_fireinput | `<target> <input> <value>` | Fire entity input on player |
| sm_hint | `<target> <message> <duration> [icon]` | Show instructor hint to player |

### Player Commands

| Command | Description |
|---------|-------------|
| sm_fp / sm_firstperson | Switch to first-person view |
| sm_tp / sm_thirdperson | Switch to third-person view |

### Target Filters

| Filter | Description |
|--------|-------------|
| @red | Target red players |
| @blue | Target blue players |
| @green | Target green players |
| @yellow | Target yellow players |
| @vips | Target civilian players (VIPs) |

## 🗺️ Map Utilities

### Admin Commands

| Command | Description |
|---------|-------------|
| sm_reloadmap | Reloads the current map |

### Server Commands
Removed `FCVAR_CHEATS` flags off the following commands:

| Command |
|---------|
| nav_generate |
| nav_generate_incremental |
| sm_nav_generate |
| sm_nav_generate_incremental |
| bot_kick |
