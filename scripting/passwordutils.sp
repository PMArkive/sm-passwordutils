#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name = "Password Utils", 
    description = "Password utils", 
    author = "ampere", 
    version = "1.1", 
    url = "github.com/maxijabase"
};

#define PW_MAX_LEN 128
#define PW_DATA_FILE "data/passwordutils.txt"

ConVar g_cvPassword;
ConVar g_cvCountdown;
bool g_bIsTimerRunning;
char g_sLockedPassword[PW_MAX_LEN];

public void OnPluginStart()
{
    RegAdminCmd("sm_nopw", Command_NoPW, ADMFLAG_RCON, "Clear server password");
    RegAdminCmd("sm_clearpw", Command_NoPW, ADMFLAG_RCON, "Clear server password");
    RegAdminCmd("sm_pw", Command_PW, ADMFLAG_RCON, "Set server password");
    
    g_cvPassword = FindConVar("sv_password");
    g_cvCountdown = CreateConVar("sm_passwordutils_countdown", "60", "Amount of seconds the server must remain empty before clearing the password.");
    
    LoadLockedPassword();
}

public void OnConfigsExecuted()
{
    if (g_sLockedPassword[0] != '\0')
    {
        g_cvPassword.SetString(g_sLockedPassword, false, false);
    }
}

public Action Command_NoPW(int client, int args)
{
    g_cvPassword.SetString("", false, false);
    g_sLockedPassword[0] = '\0';
    SaveLockedPassword();
    ReplyToCommand(client, "[SM] Password cleared.");
    
    return Plugin_Handled;
}

public Action Command_PW(int client, int args)
{
    if (args != 1)
    {
        char pw[PW_MAX_LEN];
        g_cvPassword.GetString(pw, sizeof(pw));
        if (pw[0] == '\0')
        {
            ReplyToCommand(client, "[SM] The server has no password.");
        }
        else
        {
            ReplyToCommand(client, "[SM] Password: %s", pw);
        }
        return Plugin_Handled;
    }
    
    char password[PW_MAX_LEN];
    GetCmdArg(1, password, sizeof(password));
    strcopy(g_sLockedPassword, sizeof(g_sLockedPassword), password);
    g_cvPassword.SetString(g_sLockedPassword, false, false);
    SaveLockedPassword();
    ReplyToCommand(client, "[SM] Password locked to: %s", g_sLockedPassword);
    
    return Plugin_Handled;
}

public void OnServerEmpty()
{
    if (g_sLockedPassword[0] != '\0')
    {
        PrintToServer("[SM] Starting timer to clear password...");
        CreateTimer(g_cvCountdown.FloatValue, Timer_ClearPassword);
        g_bIsTimerRunning = true;
    }
}

public void OnServerNotEmpty()
{
    if (g_bIsTimerRunning)
    {
        PrintToServer("[SM] Cancelling timer to clear password...");
        g_bIsTimerRunning = false;
    }
}

public Action Timer_ClearPassword(Handle timer)
{
    if (g_bIsTimerRunning)
    {
        g_cvPassword.SetString("", false, false);
        g_sLockedPassword[0] = '\0';
        SaveLockedPassword();
        PrintToServer("[SM] Empty server! Clearing password.");
        g_bIsTimerRunning = false;
    }
    
    return Plugin_Stop;
}

void LoadLockedPassword()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), PW_DATA_FILE);
    
    if (!FileExists(path))
    {
        g_sLockedPassword[0] = '\0';
        return;
    }
    
    File file = OpenFile(path, "r");
    if (file == null)
    {
        g_sLockedPassword[0] = '\0';
        return;
    }
    
    file.ReadLine(g_sLockedPassword, sizeof(g_sLockedPassword));
    TrimString(g_sLockedPassword);
    delete file;
    
    if (g_sLockedPassword[0] != '\0')
    {
        g_cvPassword.SetString(g_sLockedPassword, false, false);
    }
}

void SaveLockedPassword()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), PW_DATA_FILE);
    
    File file = OpenFile(path, "w");
    if (file == null)
    {
        LogError("[PW] Failed to write to data file: %s", path);
        return;
    }
    
    file.WriteLine("%s", g_sLockedPassword);
    delete file;
}
