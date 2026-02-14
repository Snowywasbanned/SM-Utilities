#include <sourcemod>

//ConVar sm_crash_salvage_mode;

public Plugin myinfo = 
{
    name = "SM Utilities | Server Utilities",
    author = "Heapons",
    description = "Tools and utilities for managing servers",
    version = "26w07a",
    url = "https://github.com/Heapons/SM-Utilities"
};

public void OnPluginStart()
{
    //sm_crash_salvage_mode = CreateConVar("sm_crash_salvage_mode", "0", "Crash salvage mode: 0=disabled, 1=randommap, 2=randommap+delete current map", _, true, 0.0, true, 2.0);
    //AutoExecConfig(true, "sm_crashutils");

    RegServerCmd("_restart", Command_Restart);
}

public Action Command_Restart(int args)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsFakeClient(i))
        {
            ClientCommand(i, "retry");
        }
    }
    return Plugin_Handled;
}
/*
public void OnClientDisconnect_Post(int client)
{
    if (IsFakeClient(client))
        return;
    
    CreateTimer(0.2, Timer_CheckForCrash, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckForCrash(Handle timer)
{
    int humans = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            humans++;
        }
    }
    
    if (humans == 0)
    {
        int salvageMode = sm_crash_salvage_mode.IntValue;
        
        if (salvageMode > 0)
        {            
            char map[PLATFORM_MAX_PATH];
            GetCurrentMap(map, sizeof(map));
            if (salvageMode == 2)
            {
                char oldPath[PLATFORM_MAX_PATH], newPath[PLATFORM_MAX_PATH];
                Format(oldPath, sizeof(oldPath), "maps/%s.bsp", map); Format(newPath, sizeof(newPath), "maps/%s.bsp.disabled", map);
                if (FileExists(oldPath))
                {
                    RenameFile(oldPath, newPath);
                }
            }
            ServerCommand("randommap");
        }
    }
    
    return Plugin_Stop;
}
*/