#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <regex>
#include <entitylump>

#include <serider/shared>

#undef REQUIRE_EXTENSIONS
#include <serider/tf2>
#define REQUIRE_EXTENSIONS

#define PLUGIN_PREFIX "{#4C4C4C}[{#F69E1D}Source{#5596CF}Mod{#4C4C4C}]\x01"

enum
{
    convert_mobster_vip,
    truce_active,

    MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_ThirdPerson[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "SM Utilities | TF2 Classified Tools",
    author = "Heapons",
    description = "Tools and utilities for Team Fortress 2 Classified",
    version = "26w07b",
    url = "https://github.com/Heapons/SM-Utilities"
};

public void OnPluginStart()
{
    /* Events */
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    /* ConVars */
    g_ConVars[convert_mobster_vip] = CreateConVar("sm_convert_mobster_vip", "1", "Convert Mobster VIP to TF2C VIP.", _, true, 0.0, true, 1.0);
    g_ConVars[truce_active]        = CreateConVar("sm_truce_active", "0", "Toggle truce mode.", _, true, 0.0, true, 1.0);

    /* Commands */
    // @admins
    RegAdminCmd("sm_setteam", Command_SetTeam, ADMFLAG_GENERIC);
    RegAdminCmd("sm_team",    Command_SetTeam, ADMFLAG_GENERIC);

    RegAdminCmd("sm_setclass", Command_SetClass, ADMFLAG_GENERIC);
    RegAdminCmd("sm_class",    Command_SetClass, ADMFLAG_GENERIC);

    RegAdminCmd("sm_fireinput", Command_FireInput, ADMFLAG_GENERIC);

    RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_GENERIC);

    RegAdminCmd("sm_health", Command_Health, ADMFLAG_GENERIC);
    RegAdminCmd("sm_maxhealth", Command_MaxHealth, ADMFLAG_GENERIC);
    RegAdminCmd("sm_currency", Command_Currency, ADMFLAG_GENERIC);
    RegAdminCmd("sm_scale", Command_Scale, ADMFLAG_GENERIC);

    RegAdminCmd("sm_addattr", Command_AddAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_addattribute", Command_AddAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removeattr", Command_RemoveAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removeattribute", Command_RemoveAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_getattr", Command_GetAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_getattribute", Command_GetAttribute, ADMFLAG_GENERIC);

    RegAdminCmd("sm_hint", Command_HintSay, ADMFLAG_GENERIC);

    RegAdminCmd("sm_addcond", Command_AddCondition, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removecond", Command_RemoveCondition, ADMFLAG_GENERIC);

    // @everyone
    RegConsoleCmd("sm_fp", Command_FirstPerson);
    RegConsoleCmd("sm_firstperson", Command_FirstPerson);
    RegConsoleCmd("sm_tp", Command_ThirdPerson);
    RegConsoleCmd("sm_thirdperson", Command_ThirdPerson);

    /* Target Filters */
    AddMultiTargetFilter("@red",    TargetFilter_RedTeam,    "Red",    false);
    AddMultiTargetFilter("@blue",   TargetFilter_BlueTeam,   "Blue",   false);
    AddMultiTargetFilter("@green",  TargetFilter_GreenTeam,  "Green",  false);
    AddMultiTargetFilter("@yellow", TargetFilter_YellowTeam, "Yellow", false);
    AddMultiTargetFilter("@vips",   TargetFilter_Civilians,  "Civilians", true);
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    for (int i = 0; i < MAX_CONVARS; i++)
    {
        if (convar == g_ConVars[i])
        {
            switch (i)
            {
                case truce_active:
                {
                    GameRules_SetProp("m_bTruceActive", convar.BoolValue);
                }
            }
            break;
        }
    }
}

public void OnMapInit()
{
    if (g_ConVars[convert_mobster_vip].BoolValue)
    {
        int lumpLength = EntityLump.Length();
        EntityLumpEntry entry;
        char classname[64], buffer[256];

        bool isVScriptVIP = false;
        for (int i = lumpLength - 1; i >= 0; i--)
        {
            entry = EntityLump.Get(i);

            if (entry.GetNextKey("classname", classname, sizeof(classname), -1) != -1 && StrEqual(classname, "logic_script", false))
            {
                if (entry.GetNextKey("vscripts", buffer, sizeof(buffer), -1) != -1 && StrContains(buffer, "vip.nut", false) != -1)
                {
                    isVScriptVIP = true;
                    EntityLump.Erase(i);
                    continue;
                }
            }
            int pos = -1;
            while ((pos = entry.GetNextKey("OnMapSpawn", buffer, sizeof(buffer), pos)) != -1)
            {
                if (StrContains(buffer, "cane", false) != -1)
                {
                    EntityLump.Erase(i);
                    break;
                }
            }
            CloseHandle(entry);
        }
        if (isVScriptVIP)
        {
            int index = EntityLump.Append();
            entry = EntityLump.Get(index);
            entry.Append("classname", "tf2c_logic_vip");
            entry.Append("blue_escort", "1");
            entry.Append("show_escort_progress", "1");
            entry.Append("hud_type", "1");
            entry.Append("vehicle_type", "2");
            CloseHandle(entry);
        }
    }
}

public void OnMapStart()
{
    // Item Schema
    char path[PLATFORM_MAX_PATH] = "scripts/items/custom_items_game.txt";
	if (FileExists(path))
	{
		PrecacheGeneric(path, true);
		AddFileToDownloadsTable(path);
	}

    // Global
    ArrayList dirs = new ArrayList(PLATFORM_MAX_PATH);
    DirectoryListing custom = OpenDirectory("custom");
    char entry[PLATFORM_MAX_PATH];
    FileType fileType;
    char ext[16];
    char dir[PLATFORM_MAX_PATH];

    if (custom != null)
    {
        while (custom.GetNext(entry, sizeof(entry), fileType))
        {
            if (fileType == FileType_Directory && StrContains(entry, "global", false) == 0)
            {
                Format(path, sizeof(path), "custom/%s", entry);
                dirs.PushString(path);
            }
        }
        delete custom;
    }

    while (dirs.Length > 0)
    {
        dirs.GetString(dirs.Length - 1, dir, sizeof(dir));
        dirs.Erase(dirs.Length - 1);

        DirectoryListing listing = OpenDirectory(dir);
        if (listing == null)
        {
            continue;
        }

        while (listing.GetNext(entry, sizeof(entry), fileType))
        {
            if (StrEqual(entry, ".") || StrEqual(entry, ".."))
            {
                continue;
            }

            Format(path, sizeof(path), "%s/%s", dir, entry);

            if (fileType == FileType_Directory)
            {
                dirs.PushString(path);
                continue;
            }

            if (!FileExists(path))
            {
                continue;
            }

            AddFileToDownloadsTable(path);

            int maxlen = strlen(path);
            bool isModelFile, isDecalFile;

            isModelFile = StrEqual(path[maxlen - 4], ".mdl", false) ||
                          StrEqual(path[maxlen - 4], ".vcd", false) ||
                          StrEqual(path[maxlen - 4], ".vvd", false) ||
                          StrEqual(path[maxlen - 4], ".phy", false) ||
                          StrEqual(path[maxlen - 4], ".vtx", false) ||
                          StrEqual(path[maxlen - 7], ".sw.vtx", false) ||
                          StrEqual(path[maxlen - 9], ".dx80.vtx", false) ||
                          StrEqual(path[maxlen - 9], ".dx90.vtx", false);

            isDecalFile = StrEqual(path[maxlen - 4], ".vmt", false) ||
                          StrEqual(path[maxlen - 4], ".vtf", false);

            PrecacheGeneric(path);

            if (isModelFile)
            {
                PrecacheModel(path);
            }
            else if (isDecalFile)
            {
                PrecacheDecal(path);
            }
            else
            {
                ext[0] = '\0';
                int dotPos = FindCharInString(path, '.', true);
                if (dotPos != -1)
                {
                    strcopy(ext, sizeof(ext), path[dotPos + 1]);
                }

                if (StrEqual(ext, "wav", false) || StrEqual(ext, "mp3", false))
                {
                    PrecacheSound(path);
                }
            }
        }
        delete listing;
    }
    delete dirs;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    TFPlayer player = Entity(client);

    // Third-Person
    CreateTimer(0.1, Timer_Event_PlayerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Event_PlayerSpawn(Handle timer, int client)
{
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(g_ThirdPerson[client]);
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    g_ThirdPerson[client] = false;
}

/* Functions */
// Commands
public Action Command_SetTeam(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_setteam [target] <team>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char teamName[32];
    
    if (args == 1)
    {
        GetCmdArg(1, teamName, sizeof(teamName));
        GetCmdArgString(targetArg, sizeof(targetArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, teamName, sizeof(teamName));
    }

    // Find the team
    int teamIndex = FindTeamByName(teamName);
    if (teamIndex < 0)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Invalid team: {lightgreen}%s", teamName);
        return Plugin_Handled;
    }

    // Process target string
    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    GetTeamName(teamIndex, teamName, sizeof(teamName));
    if (StrEqual(teamName, "Red"))
    {
        teamName = "\x07FF4040RED\x01";
    }
    else if (StrEqual(teamName, "Blue"))
    {
        teamName = "\x0799CCFFBLU\x01";
    }
    else if (StrEqual(teamName, "Green"))
    {
        teamName = "\x0799FF99GRN\x01";
    }
    else if (StrEqual(teamName, "Yellow"))
    {
        teamName = "\x07FFB200YLW\x01";
    }
    else
    {
        Format(teamName, sizeof(teamName), "\x07CCCCCC%s\x01", teamName);
    }

    TFPlayer target;
    if (targetCount > 1)
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.team = view_as<TFTeam>(teamIndex);
        }
        CReplyToCommand(client, PLUGIN_PREFIX ... " Changed \x04%d\x01 players to %s", targetCount, teamName);
    }
    else
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.team = view_as<TFTeam>(teamIndex);
        }
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Changed \x03%N\x01 to %s", target.index, teamName);
    }

    return Plugin_Handled;
}

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <regex>
#include <entitylump>

#include <serider/shared>

#undef REQUIRE_EXTENSIONS
#include <serider/tf2>
#define REQUIRE_EXTENSIONS

#define PLUGIN_PREFIX "{#4C4C4C}[{#F69E1D}Source{#5596CF}Mod{#4C4C4C}]\x01"

enum
{
    convert_mobster_vip,
    truce_active,

    MAX_CONVARS
}

ConVar g_ConVars[MAX_CONVARS];

bool g_ThirdPerson[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "SM Utilities | TF2 Classified Tools",
    author = "Heapons",
    description = "Tools and utilities for Team Fortress 2 Classified",
    version = "26w07b",
    url = "https://github.com/Heapons/SM-Utilities"
};

public void OnPluginStart()
{
    /* Events */
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    /* ConVars */
    g_ConVars[convert_mobster_vip] = CreateConVar("sm_convert_mobster_vip", "1", "Convert Mobster VIP to TF2C VIP.", _, true, 0.0, true, 1.0);
    g_ConVars[truce_active]        = CreateConVar("sm_truce_active", "0", "Toggle truce mode.", _, true, 0.0, true, 1.0);

    /* Commands */
    // @admins
    RegAdminCmd("sm_setteam", Command_SetTeam, ADMFLAG_GENERIC);
    RegAdminCmd("sm_team",    Command_SetTeam, ADMFLAG_GENERIC);

    RegAdminCmd("sm_setclass", Command_SetClass, ADMFLAG_GENERIC);
    RegAdminCmd("sm_class",    Command_SetClass, ADMFLAG_GENERIC);

    RegAdminCmd("sm_fireinput", Command_FireInput, ADMFLAG_GENERIC);

    RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_GENERIC);

    RegAdminCmd("sm_health", Command_Health, ADMFLAG_GENERIC);
    RegAdminCmd("sm_maxhealth", Command_MaxHealth, ADMFLAG_GENERIC);
    RegAdminCmd("sm_currency", Command_Currency, ADMFLAG_GENERIC);
    RegAdminCmd("sm_scale", Command_Scale, ADMFLAG_GENERIC);

    RegAdminCmd("sm_addattr", Command_AddAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_addattribute", Command_AddAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removeattr", Command_RemoveAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removeattribute", Command_RemoveAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_getattr", Command_GetAttribute, ADMFLAG_GENERIC);
    RegAdminCmd("sm_getattribute", Command_GetAttribute, ADMFLAG_GENERIC);

    RegAdminCmd("sm_hint", Command_HintSay, ADMFLAG_GENERIC);

    RegAdminCmd("sm_addcond", Command_AddCondition, ADMFLAG_GENERIC);
    RegAdminCmd("sm_removecond", Command_RemoveCondition, ADMFLAG_GENERIC);

    // @everyone
    RegConsoleCmd("sm_fp", Command_FirstPerson);
    RegConsoleCmd("sm_firstperson", Command_FirstPerson);
    RegConsoleCmd("sm_tp", Command_ThirdPerson);
    RegConsoleCmd("sm_thirdperson", Command_ThirdPerson);

    /* Target Filters */
    AddMultiTargetFilter("@red",    TargetFilter_RedTeam,    "Red",    false);
    AddMultiTargetFilter("@blue",   TargetFilter_BlueTeam,   "Blue",   false);
    AddMultiTargetFilter("@green",  TargetFilter_GreenTeam,  "Green",  false);
    AddMultiTargetFilter("@yellow", TargetFilter_YellowTeam, "Yellow", false);
    AddMultiTargetFilter("@vips",   TargetFilter_Civilians,  "Civilians", true);
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    for (int i = 0; i < MAX_CONVARS; i++)
    {
        if (convar == g_ConVars[i])
        {
            switch (i)
            {
                case truce_active:
                {
                    GameRules_SetProp("m_bTruceActive", convar.BoolValue);
                }
            }
            break;
        }
    }
}

public void OnMapInit()
{
    if (g_ConVars[convert_mobster_vip].BoolValue)
    {
        int lumpLength = EntityLump.Length();
        EntityLumpEntry entry;
        char classname[64], buffer[256];

        bool isVScriptVIP = false;
        for (int i = lumpLength - 1; i >= 0; i--)
        {
            entry = EntityLump.Get(i);

            if (entry.GetNextKey("classname", classname, sizeof(classname), -1) != -1 && StrEqual(classname, "logic_script", false))
            {
                if (entry.GetNextKey("vscripts", buffer, sizeof(buffer), -1) != -1 && StrContains(buffer, "vip.nut", false) != -1)
                {
                    isVScriptVIP = true;
                    EntityLump.Erase(i);
                    continue;
                }
            }
            int pos = -1;
            while ((pos = entry.GetNextKey("OnMapSpawn", buffer, sizeof(buffer), pos)) != -1)
            {
                if (StrContains(buffer, "cane", false) != -1)
                {
                    EntityLump.Erase(i);
                    break;
                }
            }
            CloseHandle(entry);
        }
        if (isVScriptVIP)
        {
            int index = EntityLump.Append();
            entry = EntityLump.Get(index);
            entry.Append("classname", "tf2c_logic_vip");
            entry.Append("blue_escort", "1");
            entry.Append("show_escort_progress", "1");
            entry.Append("hud_type", "1");
            entry.Append("vehicle_type", "2");
            CloseHandle(entry);
        }
    }
}

public void OnMapStart()
{
    // Item Schema
    char path[PLATFORM_MAX_PATH] = "scripts/items/custom_items_game.txt";
	if (FileExists(path))
	{
		PrecacheGeneric(path, true);
		AddFileToDownloadsTable(path);
	}

    // Global
    ArrayList dirs = new ArrayList(PLATFORM_MAX_PATH);
    DirectoryListing custom = OpenDirectory("custom");
    char entry[PLATFORM_MAX_PATH];
    FileType fileType;
    char ext[16];
    char dir[PLATFORM_MAX_PATH];

    if (custom != null)
    {
        while (custom.GetNext(entry, sizeof(entry), fileType))
        {
            if (fileType == FileType_Directory && StrContains(entry, "global", false) == 0)
            {
                Format(path, sizeof(path), "custom/%s", entry);
                dirs.PushString(path);
            }
        }
        delete custom;
    }

    while (dirs.Length > 0)
    {
        dirs.GetString(dirs.Length - 1, dir, sizeof(dir));
        dirs.Erase(dirs.Length - 1);

        DirectoryListing listing = OpenDirectory(dir);
        if (listing == null)
        {
            continue;
        }

        while (listing.GetNext(entry, sizeof(entry), fileType))
        {
            if (StrEqual(entry, ".") || StrEqual(entry, ".."))
            {
                continue;
            }

            Format(path, sizeof(path), "%s/%s", dir, entry);

            if (fileType == FileType_Directory)
            {
                dirs.PushString(path);
                continue;
            }

            if (!FileExists(path))
            {
                continue;
            }

            AddFileToDownloadsTable(path);

            int maxlen = strlen(path);
            bool isModelFile, isDecalFile;

            isModelFile = StrEqual(path[maxlen - 4], ".mdl", false) ||
                          StrEqual(path[maxlen - 4], ".vcd", false) ||
                          StrEqual(path[maxlen - 4], ".vvd", false) ||
                          StrEqual(path[maxlen - 4], ".phy", false) ||
                          StrEqual(path[maxlen - 4], ".vtx", false) ||
                          StrEqual(path[maxlen - 7], ".sw.vtx", false) ||
                          StrEqual(path[maxlen - 9], ".dx80.vtx", false) ||
                          StrEqual(path[maxlen - 9], ".dx90.vtx", false);

            isDecalFile = StrEqual(path[maxlen - 4], ".vmt", false) ||
                          StrEqual(path[maxlen - 4], ".vtf", false);

            PrecacheGeneric(path);

            if (isModelFile)
            {
                PrecacheModel(path);
            }
            else if (isDecalFile)
            {
                PrecacheDecal(path);
            }
            else
            {
                ext[0] = '\0';
                int dotPos = FindCharInString(path, '.', true);
                if (dotPos != -1)
                {
                    strcopy(ext, sizeof(ext), path[dotPos + 1]);
                }

                if (StrEqual(ext, "wav", false) || StrEqual(ext, "mp3", false))
                {
                    PrecacheSound(path);
                }
            }
        }
        delete listing;
    }
    delete dirs;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    TFPlayer player = Entity(client);

    // Third-Person
    CreateTimer(0.1, Timer_Event_PlayerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Event_PlayerSpawn(Handle timer, int client)
{
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(g_ThirdPerson[client]);
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    g_ThirdPerson[client] = false;
}

/* Functions */
// Commands
public Action Command_SetTeam(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_setteam [target] <team>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char teamName[32];
    
    if (args == 1)
    {
        GetCmdArg(1, teamName, sizeof(teamName));
        GetCmdArgString(targetArg, sizeof(targetArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, teamName, sizeof(teamName));
    }

    // Find the team
    int teamIndex = FindTeamByName(teamName);
    if (teamIndex < 0)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Invalid team: {lightgreen}%s", teamName);
        return Plugin_Handled;
    }

    // Process target string
    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    GetTeamName(teamIndex, teamName, sizeof(teamName));
    if (StrEqual(teamName, "Red"))
    {
        teamName = "\x07FF4040RED\x01";
    }
    else if (StrEqual(teamName, "Blue"))
    {
        teamName = "\x0799CCFFBLU\x01";
    }
    else if (StrEqual(teamName, "Green"))
    {
        teamName = "\x0799FF99GRN\x01";
    }
    else if (StrEqual(teamName, "Yellow"))
    {
        teamName = "\x07FFB200YLW\x01";
    }
    else
    {
        Format(teamName, sizeof(teamName), "\x07CCCCCC%s\x01", teamName);
    }

    TFPlayer target;
    if (targetCount > 1)
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.team = view_as<TFTeam>(teamIndex);
        }
        CReplyToCommand(client, PLUGIN_PREFIX ... " Changed \x04%d\x01 players to %s", targetCount, teamName);
    }
    else
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.team = view_as<TFTeam>(teamIndex);
        }
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Changed \x03%N\x01 to %s", target.index, teamName);
    }

    return Plugin_Handled;
}

public Action Command_AddAttribute(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_addattr [target] <attribute> [value] [duration]");
        return Plugin_Handled;
    }

    char targetArg[64];
    char attrName[64];
    char valueArg[32] = "1.0";
    char durationArg[32] = "-1.0";

    switch (args)
    {
        case 1:
        {
            GetCmdArg(1, attrName, sizeof(attrName));
            strcopy(targetArg, sizeof(targetArg), "@me");
        }
        case 2:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, attrName, sizeof(attrName));
        }
        case 3:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, attrName, sizeof(attrName));
            GetCmdArg(3, valueArg, sizeof(valueArg));
        }
        default:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, attrName, sizeof(attrName));
            GetCmdArg(3, valueArg, sizeof(valueArg));
            GetCmdArg(4, durationArg, sizeof(durationArg));
        }
    }

    float value = StringToFloat(valueArg);
    float duration = StringToFloat(durationArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        int targetIdx = targets[i];
        TFPlayer target = Entity(targetIdx);
        
        target.AddAttribute(attrName, value, duration);

        for (int slot = 0; slot < 6; slot++)
        {
            int weapon = GetPlayerWeaponSlot(targetIdx, slot);
            if (weapon != -1)
            {
                TFPlayer weaponEnt = Entity(weapon);
                weaponEnt.AddAttribute(attrName, value, duration);
            }
        }
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Applied \x05%s\x01 to \x04%d\x01 players and weapons", attrName, targetCount);
    }
    else
    {
        int targetIdx = targets[0];
        CReplyToCommandEx(client, targetIdx, PLUGIN_PREFIX ... " Applied \x05%s\x01 to \x03%N\x01 and weapons", attrName, targetIdx);
    }

    return Plugin_Handled;
}

public Action Command_RemoveAttribute(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_removeattr [target] <attribute>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char attrName[64];

    if (args == 1)
    {
        GetCmdArg(1, attrName, sizeof(attrName));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, attrName, sizeof(attrName));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.RemoveAttribute(attrName);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Removed \x05%s\x01 from \x04%d\x01 players", attrName, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Removed \x05%s\x01 from \x03%N", attrName, target.index);
    }

    return Plugin_Handled;
}

public Action Command_GetAttribute(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_getattr [target] <attribute>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char attrName[64];

    if (args == 1)
    {
        GetCmdArg(1, attrName, sizeof(attrName));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, attrName, sizeof(attrName));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        float value = target.GetAttribute(attrName);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Attribute \x05%s\x01 for \x03%N: \x04%.3f", attrName, target.index, value);
    }

    return Plugin_Handled;
}

public Action Command_AddCondition(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_addcond [target] <condition> [duration]");
        return Plugin_Handled;
    }

    char targetArg[64];
    char condArg[16];
    char durationArg[32] = "-1.0";

    switch (args)
    {
        case 1:
        {
            GetCmdArg(1, condArg, sizeof(condArg));
            strcopy(targetArg, sizeof(targetArg), "@me");
        }
        case 2:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, condArg, sizeof(condArg));
        }
        default:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, condArg, sizeof(condArg));
            GetCmdArg(3, durationArg, sizeof(durationArg));
        }
    }

    int condition = StringToInt(condArg);
    float duration = StringToFloat(durationArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.AddCond(condition, duration);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Added condition \x05%d\x01 to \x04%d\x01 players", condition, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Added condition \x05%d\x01 to \x03%N", condition, target.index);
    }

    return Plugin_Handled;
}

public Action Command_RemoveCondition(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_removecond [target] <condition>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char condArg[16];

    if (args == 1)
    {
        GetCmdArg(1, condArg, sizeof(condArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, condArg, sizeof(condArg));
    }

    int condition = StringToInt(condArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.RemoveCond(condition);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Removed condition \x05%d\x01 from \x04%d\x01 players", condition, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Removed condition \x05%d\x01 from \x03%N", condition, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Currency(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_currency [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.currency = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set currency to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set currency to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Scale(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_scale [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    float value = StringToFloat(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.scale = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set scale to \x05%.2f\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set scale to \x05%.2f\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Health(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_health [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.health = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set health to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set health to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_MaxHealth(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_maxhealth [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.max_health = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set max health to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set max health to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_SetClass(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_setclass [target] <class>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char className[32];

    if (args == 1)
    {
        GetCmdArg(1, className, sizeof(className));
        GetCmdArgString(targetArg, sizeof(targetArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, className, sizeof(className));
    }

    TFClassType classType;
    if (StrContains(className, "sc", false) == 0)
    {
        classType = TFClass_Scout;
        className = "Scout";
    }
    else if (StrContains(className, "sn", false) == 0)
    {
        classType = TFClass_Sniper;
        className = "Sniper";
    }
    else if (StrContains(className, "so", false) == 0)
    {
        classType = TFClass_Soldier;
        className = "Soldier";
    }
    else if (StrContains(className, "d", false) == 0)
    {
        classType = TFClass_DemoMan;
        className = "Demoman";
    }
    else if (StrContains(className, "m", false) == 0)
    {
        classType = TFClass_Medic;
        className = "Medic";
    }
    else if (StrContains(className, "h", false) == 0)
    {
        classType = TFClass_Heavy;
        className = "Heavy";
    }
    else if (StrContains(className, "p", false) == 0)
    {
        classType = TFClass_Pyro;
        className = "Pyro";
    }
    else if (StrContains(className, "sp", false) == 0)
    {
        classType = TFClass_Spy;
        className = "Spy";
    }
    else if (StrContains(className, "e", false) == 0)
    {
        classType = TFClass_Engineer;
        className = "Engineer";
    }
    else if (StrContains(className, "c", false) == 0)
    {
        classType = TFClass_Civilian;
        className = "Civilian";
    }
    else
    {
        classType = TFClass_Unknown;
        className = "Undefined";
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    if (targetCount > 1)
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.class = classType;
        }
        CReplyToCommand(client, PLUGIN_PREFIX ... " Changed \x04%d\x01 players into \x05%s", targetCount, className);
    }
    else
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.class = classType;
            CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Changed \x03%N\x01 into \x05%s", target.index, className);
        }
    }

    target.ForceRespawn();

    float origin[3];
    GetClientAbsOrigin(target.index, origin);
    TeleportEntity(target.index, origin);

    return Plugin_Handled;
}

public Action Command_FireInput(int client, int args)
{
    if (args < 3)
    {
        ReplyToCommand(client, "Usage: sm_fireinput <target> <input> <value>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char entityInput[64];
    char entityValue[64];

    GetCmdArg(1, targetArg, sizeof(targetArg));
    GetCmdArg(2, entityInput, sizeof(entityInput));
    GetCmdArg(3, entityValue, sizeof(entityValue));

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        int intValue;
        if (entityValue[0] != '\0' && StringToIntEx(entityValue, intValue) > 0)
        {
            SetVariantInt(intValue);
        }
        else
        {
            SetVariantString(entityValue);
        }
        AcceptEntityInput(target.index, entityInput);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Fired \x05%s\x01 on \x04%d\x01 players", entityInput, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Fired \x05%s\x01 on \x03%N", entityInput, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
    char targetArg[64];
    if (args == 0)
    {
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.ForceRespawn();
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Respawned \x04%d\x01 players", targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Respawned \x03%N", target.index);
    }

    return Plugin_Handled;
}

public Action Command_FirstPerson(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    g_ThirdPerson[client] = false;
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(false);
    
    CReplyToCommand(client, PLUGIN_PREFIX ... " Set view to \x04First-Person");
    return Plugin_Handled;
}

public Action Command_ThirdPerson(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    g_ThirdPerson[client] = true;
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(true);
    
    CReplyToCommand(client, PLUGIN_PREFIX ... " Set view to \x04Third-Person");
    return Plugin_Handled;
}

public Action Command_HintSay(int client, int args)
{
    if (args < 3)
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char targetArg[64];
    GetCmdArg(1, targetArg, sizeof(targetArg));

    char message[256];
    GetCmdArg(2, message, sizeof(message));
    
    if (message[0] == '\0')
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char durationArg[32];
    GetCmdArg(3, durationArg, sizeof(durationArg));
    float duration = StringToFloat(durationArg);
    
    if (duration <= 0.0)
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char icon[64];
    if (args >= 4)
    {
        GetCmdArg(4, icon, sizeof(icon));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        TFPlayer target = Entity(targets[i]);
        if (!IsClientInGame(target.index))
        {
            continue;
        }

        Event event = CreateEvent("instructor_server_hint_create", true);
        if (event == null)
        {
            continue;
        }

        char hintName[64];
        Format(hintName, sizeof(hintName), "sm_hint_%N", target);
        event.SetString("hint_name", hintName);
        event.SetString("hint_replace_key", "sm_hint");
        event.SetInt("hint_target", GetClientUserId(target));
        event.SetInt("hint_activator_userid", GetClientUserId(target));
        event.SetInt("hint_timeout", RoundToNearest(duration));
        event.SetString("hint_icon_onscreen", icon);
        event.SetString("hint_icon_offscreen", icon);
        event.SetString("hint_activator_caption", message);
        event.SetString("hint_color", "255,255,255");
        event.SetFloat("hint_icon_offset", 0.0);
        event.SetFloat("hint_range", 0.0);
        event.SetInt("hint_flags", 0);
        event.SetString("hint_binding", "");
        event.SetBool("hint_allow_nodraw_target", true);
        event.SetBool("hint_nooffscreen", false);
        event.SetBool("hint_forcecaption", false);
        event.SetBool("hint_local_player_only", true);
        event.SetString("hint_start_sound", "");
        event.SetInt("hint_target_pos", 0);
        event.SetInt("hint_ent_spawnflags", 0);
        event.SetInt("hint_ent_team", 0);
        event.FireToClient(target);
    }
    return Plugin_Handled;
}

// Target Filters
public bool TargetFilter_RedTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Red)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_BlueTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Blue)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_GreenTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Green)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_YellowTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Yellow)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_Civilians(const char[] pattern, ArrayList clients, int client)
{
    TFPlayer target;
    for (int i = 1; i <= MaxClients; i++)
    {
        target = Entity(i);
        if (target.class == TFClass_Civilian)
        {
            clients.Push(i);
        }
    }
    return true;
}

public Action Command_RemoveAttribute(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_removeattr [target] <attribute>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char attrName[64];

    if (args == 1)
    {
        GetCmdArg(1, attrName, sizeof(attrName));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, attrName, sizeof(attrName));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.RemoveAttribute(attrName);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Removed \x05%s\x01 from \x04%d\x01 players", attrName, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Removed \x05%s\x01 from \x03%N", attrName, target.index);
    }

    return Plugin_Handled;
}

public Action Command_GetAttribute(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_getattr [target] <attribute>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char attrName[64];

    if (args == 1)
    {
        GetCmdArg(1, attrName, sizeof(attrName));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, attrName, sizeof(attrName));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        float value = target.GetAttribute(attrName);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Attribute \x05%s\x01 for \x03%N: \x04%.3f", attrName, target.index, value);
    }

    return Plugin_Handled;
}

public Action Command_AddCondition(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_addcond [target] <condition> [duration]");
        return Plugin_Handled;
    }

    char targetArg[64];
    char condArg[16];
    char durationArg[32] = "-1.0";

    switch (args)
    {
        case 1:
        {
            GetCmdArg(1, condArg, sizeof(condArg));
            strcopy(targetArg, sizeof(targetArg), "@me");
        }
        case 2:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, condArg, sizeof(condArg));
        }
        default:
        {
            GetCmdArg(1, targetArg, sizeof(targetArg));
            GetCmdArg(2, condArg, sizeof(condArg));
            GetCmdArg(3, durationArg, sizeof(durationArg));
        }
    }

    int condition = StringToInt(condArg);
    float duration = StringToFloat(durationArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.AddCond(condition, duration);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Added condition \x05%d\x01 to \x04%d\x01 players", condition, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Added condition \x05%d\x01 to \x03%N", condition, target.index);
    }

    return Plugin_Handled;
}

public Action Command_RemoveCondition(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_removecond [target] <condition>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char condArg[16];

    if (args == 1)
    {
        GetCmdArg(1, condArg, sizeof(condArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, condArg, sizeof(condArg));
    }

    int condition = StringToInt(condArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.RemoveCond(condition);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Removed condition \x05%d\x01 from \x04%d\x01 players", condition, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Removed condition \x05%d\x01 from \x03%N", condition, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Currency(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_currency [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.currency = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set currency to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set currency to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Scale(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_scale [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    float value = StringToFloat(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.scale = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set scale to \x05%.2f\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set scale to \x05%.2f\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Health(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_health [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.health = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set health to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set health to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_MaxHealth(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_maxhealth [target] <amount>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char valueArg[16];

    if (args == 1)
    {
        GetCmdArg(1, valueArg, sizeof(valueArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, valueArg, sizeof(valueArg));
    }

    int value = StringToInt(valueArg);

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.max_health = value;
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Set max health to \x05%d\x01 for \x04%d\x01 players", value, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Set max health to \x05%d\x01 for \x03%N", value, target.index);
    }

    return Plugin_Handled;
}

public Action Command_SetClass(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_setclass [target] <class>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char className[32];

    if (args == 1)
    {
        GetCmdArg(1, className, sizeof(className));
        GetCmdArgString(targetArg, sizeof(targetArg));
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
        GetCmdArg(2, className, sizeof(className));
    }

    TFClassType classType;
    if (StrContains(className, "sc", false) == 0)
    {
        classType = TFClass_Scout;
        className = "Scout";
    }
    else if (StrContains(className, "sn", false) == 0)
    {
        classType = TFClass_Sniper;
        className = "Sniper";
    }
    else if (StrContains(className, "so", false) == 0)
    {
        classType = TFClass_Soldier;
        className = "Soldier";
    }
    else if (StrContains(className, "d", false) == 0)
    {
        classType = TFClass_DemoMan;
        className = "Demoman";
    }
    else if (StrContains(className, "m", false) == 0)
    {
        classType = TFClass_Medic;
        className = "Medic";
    }
    else if (StrContains(className, "h", false) == 0)
    {
        classType = TFClass_Heavy;
        className = "Heavy";
    }
    else if (StrContains(className, "p", false) == 0)
    {
        classType = TFClass_Pyro;
        className = "Pyro";
    }
    else if (StrContains(className, "sp", false) == 0)
    {
        classType = TFClass_Spy;
        className = "Spy";
    }
    else if (StrContains(className, "e", false) == 0)
    {
        classType = TFClass_Engineer;
        className = "Engineer";
    }
    else if (StrContains(className, "c", false) == 0)
    {
        classType = TFClass_Civilian;
        className = "Civilian";
    }
    else
    {
        classType = TFClass_Unknown;
        className = "Undefined";
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    if (targetCount > 1)
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.class = classType;
        }
        CReplyToCommand(client, PLUGIN_PREFIX ... " Changed \x04%d\x01 players into \x05%s", targetCount, className);
    }
    else
    {
        for (int i = 0; i < targetCount; i++)
        {
            target = Entity(targets[i]);
            target.class = classType;
            CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Changed \x03%N\x01 into \x05%s", target.index, className);
        }
    }

    target.ForceRespawn();

    float origin[3];
    GetClientAbsOrigin(target.index, origin);
    TeleportEntity(target.index, origin);

    return Plugin_Handled;
}

public Action Command_FireInput(int client, int args)
{
    if (args < 3)
    {
        ReplyToCommand(client, "Usage: sm_fireinput <target> <input> <value>");
        return Plugin_Handled;
    }

    char targetArg[64];
    char entityInput[64];
    char entityValue[64];

    GetCmdArg(1, targetArg, sizeof(targetArg));
    GetCmdArg(2, entityInput, sizeof(entityInput));
    GetCmdArg(3, entityValue, sizeof(entityValue));

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        int intValue;
        if (entityValue[0] != '\0' && StringToIntEx(entityValue, intValue) > 0)
        {
            SetVariantInt(intValue);
        }
        else
        {
            SetVariantString(entityValue);
        }
        AcceptEntityInput(target.index, entityInput);
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Fired \x05%s\x01 on \x04%d\x01 players", entityInput, targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Fired \x05%s\x01 on \x03%N", entityInput, target.index);
    }

    return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
    char targetArg[64];
    if (args == 0)
    {
        strcopy(targetArg, sizeof(targetArg), "@me");
    }
    else
    {
        GetCmdArg(1, targetArg, sizeof(targetArg));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    TFPlayer target;
    for (int i = 0; i < targetCount; i++)
    {
        target = Entity(targets[i]);
        target.ForceRespawn();
    }

    if (targetCount > 1)
    {
        CReplyToCommand(client, PLUGIN_PREFIX ... " Respawned \x04%d\x01 players", targetCount);
    }
    else
    {
        target = Entity(targets[0]);
        CReplyToCommandEx(client, target.index, PLUGIN_PREFIX ... " Respawned \x03%N", target.index);
    }

    return Plugin_Handled;
}

public Action Command_FirstPerson(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    g_ThirdPerson[client] = false;
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(false);
    
    CReplyToCommand(client, PLUGIN_PREFIX ... " Set view to \x04First-Person");
    return Plugin_Handled;
}

public Action Command_ThirdPerson(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    g_ThirdPerson[client] = true;
    TFPlayer player = Entity(client);
    player.SetForcedTauntCam(true);
    
    CReplyToCommand(client, PLUGIN_PREFIX ... " Set view to \x04Third-Person");
    return Plugin_Handled;
}

public Action Command_HintSay(int client, int args)
{
    if (args < 3)
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char targetArg[64];
    GetCmdArg(1, targetArg, sizeof(targetArg));

    char message[256];
    GetCmdArg(2, message, sizeof(message));
    
    if (message[0] == '\0')
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char durationArg[32];
    GetCmdArg(3, durationArg, sizeof(durationArg));
    float duration = StringToFloat(durationArg);
    
    if (duration <= 0.0)
    {
        ReplyToCommand(client, "Usage: sm_hint <target> <message> <duration> [icon]");
        return Plugin_Handled;
    }

    char icon[64];
    if (args >= 4)
    {
        GetCmdArg(4, icon, sizeof(icon));
    }

    int targets[MAXPLAYERS];
    int targetCount;
    char targetName[MAX_TARGET_LENGTH];
    bool tn_is_ml;

    targetCount = ProcessTargetString(targetArg, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);

    if (targetCount <= 0)
    {
        ReplyToTargetError(client, targetCount);
        return Plugin_Handled;
    }

    for (int i = 0; i < targetCount; i++)
    {
        TFPlayer target = Entity(targets[i]);
        if (!IsClientInGame(target.index))
        {
            continue;
        }

        Event event = CreateEvent("instructor_server_hint_create", true);
        if (event == null)
        {
            continue;
        }

        char hintName[64];
        Format(hintName, sizeof(hintName), "sm_hint_%N", target);
        event.SetString("hint_name", hintName);
        event.SetString("hint_replace_key", "sm_hint");
        event.SetInt("hint_target", GetClientUserId(target));
        event.SetInt("hint_activator_userid", GetClientUserId(target));
        event.SetInt("hint_timeout", RoundToNearest(duration));
        event.SetString("hint_icon_onscreen", icon);
        event.SetString("hint_icon_offscreen", icon);
        event.SetString("hint_activator_caption", message);
        event.SetString("hint_color", "255,255,255");
        event.SetFloat("hint_icon_offset", 0.0);
        event.SetFloat("hint_range", 0.0);
        event.SetInt("hint_flags", 0);
        event.SetString("hint_binding", "");
        event.SetBool("hint_allow_nodraw_target", true);
        event.SetBool("hint_nooffscreen", false);
        event.SetBool("hint_forcecaption", false);
        event.SetBool("hint_local_player_only", true);
        event.SetString("hint_start_sound", "");
        event.SetInt("hint_target_pos", 0);
        event.SetInt("hint_ent_spawnflags", 0);
        event.SetInt("hint_ent_team", 0);
        event.FireToClient(target);
    }
    return Plugin_Handled;
}

// Target Filters
public bool TargetFilter_RedTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Red)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_BlueTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Blue)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_GreenTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Green)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_YellowTeam(const char[] pattern, ArrayList clients, int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (TF2_GetClientTeam(i) == TFTeam_Yellow)
        {
            clients.Push(i);
        }
    }
    return true;
}

public bool TargetFilter_Civilians(const char[] pattern, ArrayList clients, int client)
{
    TFPlayer target;
    for (int i = 1; i <= MaxClients; i++)
    {
        target = Entity(i);
        if (target.class == TFClass_Civilian)
        {
            clients.Push(i);
        }
    }
    return true;
}
