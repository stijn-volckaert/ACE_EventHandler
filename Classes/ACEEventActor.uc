// =============================================================================
// AntiCheatEngine - (c) 2009-2019 AnthraX
// =============================================================================
class ACEEventActor extends IACEEventHandler
    config(System);

// =============================================================================
// PostBeginPlay
// =============================================================================
function PostBeginPlay()
{
    ACEPadLog("","-","+",40,true);
    ACEPadLog("ACE EventHandler"," ","|",40,true);
    ACEPadLog(ACEVersion," ","|",40,true);
    ACEPadLog("(c) 2009-2019 - AnthraX"," ","|",40,true);
    ACEPadLog("","-","+",40,true);
    SetTimer(1.0, true);
}

// =============================================================================
// Timer ~ Wait for main actor to spawn, then register
// =============================================================================
function Timer()
{
    local IACEActor A;

    Super.Timer();

    if (ConfigActor == none)
    {
        foreach Level.AllActors(class'IACEActor', A)
        {
            A.RegisterEventHandler(self);
            ConfigActor = A;
            break;
        }
    }
}

// =============================================================================
// ACELogExternal ~ Overridden
// =============================================================================
function ACELogExternal(string LogString)
{
    if (ConfigActor != none && ConfigActor.bExternalLog)
    {
        if (Logger == none)
        {
            Logger = Level.Spawn(class'IACELogger');
            Logger.OpenACELog(ConfigActor.JoinLogPath, ConfigActor.JoinLogPrefix, "");
            SetTimer(0.25, true);
        }

        if (Logger != none)
        {
            Logger.ACELog(LogString);
        }
    }
}

// =============================================================================
// EventCatcher ~ Main event catcher function
// =============================================================================
function EventCatcher(name EventType, IACECheck Check, string EventData)
{
    switch(EventType)
    {
        case 'PlayerConnected':
            PlayerConnected(Check, EventData);
            break;
        case 'PlayerInitialized':
            PlayerInitialized(Check, EventData);
            break;
        case 'PlayerKicked':
            PlayerKicked(Check, EventData);
            break;
        case 'PlayerDisconnected':
            PlayerDisconnected(Check, EventData);
            break;
        case 'OnDemandScreenshotCompleted':
            OnDemandScreenshotCompleted(Check, EventData);
            break;
        case 'PlayerKickInfo':
            PlayerKickInfo(Check, EventData);
            break;
    }
}

// =============================================================================
// PlayerLog
// =============================================================================
function PlayerLog(IACECheck Check, string LogString)
{
    if (ConfigActor != none)
        ACELog("[" $ Check.PlayerName $ "]: " $ LogString, ConfigActor.bExternalLogJoins);
    else
        ACELog("[" $ Check.PlayerName $ "]: " $ LogString);
}

// =============================================================================
// PlayerConnected ~ Called when a player has connected to the server and the
// ACE Checking object has been spawned.
//
// WARNING: Most of the IACECheck fields are not valid yet!
// The only variables that have been set at this point are PlayerName, PlayerIP,
// PlayerID and Owner.
//
// EventData: ""
// =============================================================================
function PlayerConnected(IACECheck Check, string EventData)
{

}

// =============================================================================
// PlayerInitialized ~ This is called when the player has completed the initial
// check. It is now safe to use the information in the Checking object (e.g.:
// the mac hash)
//
// EventData: ""
// =============================================================================
function PlayerInitialized(IACECheck Check, string EventData)
{
    local string CommandLine, HWID;

    if (Check.UTCommandLine == "")
        CommandLine = "<none>";
    else
        CommandLine = Check.UTCommandLine;

    // WINE does not expose enough hardware info to generate a reliable HWID
    if (Check.bWine)
        Check.HWHash = "N/A";
    HWID = Check.HWHash;

    PlayerLog(Check, "[IP]"    @ Check.PlayerIP);
    PlayerLog(Check, "[OS]"    @ Check.OSString);
	PlayerLog(Check, "[VER]"   @ Check.UTVersion);	
    if (Check.bWine)
    PlayerLog(Check, "[WINE]"  @ true);
    PlayerLog(Check, "[MAC1]"  @ Check.UTDCMacHash);
    PlayerLog(Check, "[MAC2]"  @ Check.MACHash);
    PlayerLog(Check, "[HWID]"  @ HWID);
    PlayerLog(Check, "[TIME]"  @ GetDate() $ " / " $ GetTime());
}

// =============================================================================
// PlayerKicked ~ The specified player should be kicked from the server.
//
// EventData = <KickReason>:::<Path to the logfile>:::<Path to the sshot file (optional)>
// =============================================================================
function PlayerKicked(IACECheck Check, string EventData)
{
    local PlayerPawn Player;
    local string Tmp, Line;
    local int TokenCount, i;

    Player = PlayerPawn(Check.Owner);

    if (Player != none)
    {
        // Parse the kickreason and pass it on to the client
        //
        // Note that the kickreason may consist of multiple lines
        // Lines are delimited by tabs.
        Tmp = xxGetToken(EventData, ":::", 0);
        TokenCount = xxGetTokenCount(Tmp, "" $ chr(9));

        PlayerLog(Check, "Player Kicked");

        for (i = 0; i < TokenCount; ++i)
        {
            Line = xxGetToken(Tmp, "" $ chr(9), i);
            if (Line != "")
			{
                Player.ClientMessage("[ACE" $ ACEVersion $ "]: " $ Line);
				PlayerLog(Check, "Kick Message " $ i $ ": " $ Line);
			}
        }

        if (xxGetToken(EventData, ":::", 1) != "")
            PlayerLog(Check, "[KICKLOG] " $ xxGetToken(EventData, ":::", 1));
        else
            PlayerLog(Check, "[KICKREASON] Connection Problems");
        if (xxGetToken(EventData, ":::", 2) != "")
            PlayerLog(Check, "[SSHOT] " $ xxGetToken(EventData, ":::", 2));

        Check.PlayerKick(true);
    }
}

// =============================================================================
// PlayerDisconnected ~ this event is triggered when a player has disconnected
// from the server. Note that Check.Owner is no longer valid at this point
//
// EventData = ""
// =============================================================================
function PlayerDisconnected(IACECheck Check, string EventData)
{

}

// =============================================================================
// OnDemandScreenshotCompleted ~ this event is triggered when a screenshot that
// was requested by a mod or an admin on the server was completed. This event is
// NOT triggered when a screenshot following a kick was completed.
//
// EventData = <Admin PlayerID>:::<Admin PlayerName>:::<Screenshot Status>:::<Path to the sshot file (optional)>
// =============================================================================
function OnDemandScreenshotCompleted(IACECheck Check, string EventData)
{
    local string PlayerName, AdminName;
    local string ShotStatus, ShotLink;
    local string Line;
    local PlayerPawn Admin;
    local Pawn Tmp;
    local int AdminID, PlayerID, TokenCount, i;

    // Parse the EventData
    AdminID    = int(xxGetToken(EventData, ":::", 0));
    AdminName  = xxGetToken(EventData, ":::", 1);
    ShotStatus = xxGetToken(EventData, ":::", 2);
    ShotLink   = xxGetToken(EventData, ":::", 3);

    if (Check != none)
    {
        PlayerName = Check.PlayerName;
        PlayerID   = Check.PlayerID;
    }
    else
        PlayerName = "(Player is no longer on the server)";

    // Look for the admin that requested the screenshot.
    // Keep in mind that it might be a mod!
    for (Tmp = Level.PawnList; Tmp != none; Tmp = Tmp.NextPawn)
    {
        if (Tmp.IsA('PlayerPawn') && Tmp.PlayerReplicationInfo != none)
        {
            if (Tmp.PlayerReplicationInfo.PlayerID == AdminID)
            {
                if (NetConnection(PlayerPawn(Tmp).Player) != none
                    || (AdminID == 0 && AdminName ~= Tmp.PlayerReplicationInfo.PlayerName))
                {
                    Admin = PlayerPawn(Tmp);
                    break;
                }
            }
        }
    }

    // Inform the admin. Once again, the status may consist of multiple lines,
    // delimited by a tab character
    if (Admin != none)
    {

        Admin.ClientMessage("Screenshot status for Player " $ PlayerID $ " - " $ PlayerName $ ":");

        TokenCount = xxGetTokenCount(ShotStatus, "" $ chr(9));
        for (i = 0; i < TokenCount; ++i)
        {
            Line = xxGetToken(ShotStatus, "" $ chr(9), i);
            if (Line != "")
                Admin.ClientMessage(Line);
        }

        if (ShotLink != "")
            Admin.ClientMessage("The screenshot has been stored at: " $ ShotLink);
    }
}

// =============================================================================
// PlayerKickInfo ~ reimplemented in v0.9d to restore mod compatibility
// =============================================================================
function PlayerKickInfo(IACECheck Check, string EventData)
{
    local string InfoType;
    local string RealEventData;

    InfoType      = xxGetToken(EventData, ":::", 0);
    RealEventData = Mid(EventData, InStr(EventData, ":::") + 3);

    // The events below got reimplemented in ACE v0.9d
    switch (CAPS(InfoType))
    {
        case "UNEXPECTEDPACKAGE":
            PlayerUnexpectedPackage(Check, RealEventData);
            break;
        case "ILLEGALPACKAGE":
            PlayerIllegalPackage(Check, RealEventData);
            break;
        case "UNEXPECTEDLIBRARY":
            PlayerUnexpectedLibrary(Check, RealEventData);
            break;
        case "ILLEGALLIBRARY":
            PlayerIllegalLibrary(Check, RealEventData);
            break;
        case "HOOKEDMODULE":
            PlayerHookedModule(Check, RealEventData);
            break;
        case "HOOKEDMODULEEXTRA":
            PlayerHookedModuleExtra(Check, RealEventData);
            break;
        case "HOOKEDPACKAGE":
            PlayerHookedPackage(Check, RealEventData);
            break;
        case "HOOKEDPACKAGEEXTRA":
            PlayerHookedPackageExtra(Check, RealEventData);
            break;
        case "ILLEGALUFUNCTIONCALL":
            PlayerIllegalUFunctionCall(Check, RealEventData);
            break;
        case "ILLEGALUFUNCTIONCALLEXTRA":
            PlayerIllegalUFunctionCallExtra( Check, RealEventData);
            break;
        case "OBJECTREPLACED":
            PlayerObjectReplaced(Check, RealEventData);
            break;
        case "VTABLEHOOK":
            PlayerVTableHook(Check, RealEventData);
            break;
        case "GNATHOOK":
            PlayerGNatHook(Check, RealEventData);
            break;
        case "HOSTILETHREAD":
            PlayerHostileThread(Check, RealEventData);
            break;
    }
}

// =============================================================================
// PlayerUnexpectedPackage ~ An illegal package has been found during the initial check
// =============================================================================
function PlayerUnexpectedPackage(IACECheck Check, string EventData)
{
/*
    local string PackageName;
    local string PackagePath;
    local int    PackageSize;
    local string PackageHash;
    local string PackageVersion;

    PackageName    = xxGetToken(EventData, ":::", 0);
    PackagePath    = xxGetToken(EventData, ":::", 1);
    PackageSize    = int(xxGetToken(EventData, ":::", 2));
    PackageHash    = xxGetToken(EventData, ":::", 3);
    PackageVersion = xxGetToken(EventData, ":::", 4);

    if (PackageVersion == "")
        PackageVersion = "Unknown Package";

    Log("UnexpectedPackage"@PackageName@PackagePath@PackageSize@PackageHash@PackageVersion);
*/
}

// =============================================================================
// PlayerIllegalPackage ~ An illegal package has been found during the initial check
// =============================================================================
function PlayerIllegalPackage(IACECheck Check, string EventData)
{
/*
    local string PackageName;
    local string PackagePath;
    local int    PackageSize;
    local string PackageHash;
    local string PackageVersion;

    // Parse event Data
    PackageName    = xxGetToken(EventData, ":::", 0);
    PackagePath    = xxGetToken(EventData, ":::", 1);
    PackageSize    = int(xxGetToken(EventData, ":::", 2));
    PackageHash    = xxGetToken(EventData, ":::", 3);
    PackageVersion = xxGetToken(EventData, ":::", 4);

    if (PackageVersion == "")
        PackageVersion = "Unknown Package";

    Log("IllegalPackage"@PackageName@PackagePath@PackageSize@PackageHash@PackageVersion);
*/
}

// =============================================================================
// PlayerUnexpectedLibrary ~ An illegal library has been found during the checks
// =============================================================================
function PlayerUnexpectedLibrary(IACECheck Check, string EventData)
{
/*
    local string LibraryName;
    local string LibraryPath;
    local int    LibrarySize;
    local string LibraryHash;
    local string LibraryVersion;

    LibraryName    = xxGetToken(EventData, ":::", 0);
    LibraryPath    = xxGetToken(EventData, ":::", 1);
    LibrarySize    = int(xxGetToken(EventData, ":::", 2));
    LibraryHash    = xxGetToken(EventData, ":::", 3);
    LibraryVersion = xxGetToken(EventData, ":::", 4);

    if (LibraryVersion == "")
        LibraryVersion = "Unknown File";

    Log("UnexpectedLibrary"@LibraryName@LibraryPath@LibrarySize@LibraryHash@LibraryVersion);
*/
}

// =============================================================================
// PlayerIllegalLibrary ~ An illegal library has been found during the checks
// =============================================================================
function PlayerIllegalLibrary(IACECheck Check, string EventData)
{
/*
    local string LibraryName;
    local string LibraryPath;
    local int    LibrarySize;
    local string LibraryHash;
    local string LibraryVersion;

    // NOTE: This file is not necessarily hacked. ACE just didn't expect it to
    // be loaded. Check if LibraryVersion begins with "HACKED"
    LibraryName    = xxGetToken(EventData, ":::", 0);
    LibraryPath    = xxGetToken(EventData, ":::", 1);
    LibrarySize    = int(xxGetToken(EventData, ":::", 2));
    LibraryHash    = xxGetToken(EventData, ":::", 3);
    LibraryVersion = xxGetToken(EventData, ":::", 4);

    // Even unknown files are not necessarily hacked!
    if (LibraryVersion == "")
        LibraryVersion = "Unknown File";

    Log("IllegalLibrary"@LibraryName@LibraryPath@LibrarySize@LibraryHash@LibraryVersion);
*/
}

// =============================================================================
// PlayerHookedModule ~ A hooked module means:
// * The disk version of the module (dll) was legit
// * The disk version was not mapped correctly into the memory
// OR
//   The memory version of the module was illegaly altered
// =============================================================================
function PlayerHookedModule(IACECheck Check, string EventData)
{
/*
    local string LibraryAddress;
    local string LibraryName;
    local string LibraryPath;
    local string LibraryHash;
    local int    LibrarySize;
    local string LibraryVersion;

    // Parse Event Data
    LibraryAddress = xxGetToken(EventData, ":::", 0);
    LibraryName    = xxGetToken(EventData, ":::", 1);
    LibraryPath    = xxGetToken(EventData, ":::", 2);
    LibraryHash    = xxGetToken(EventData, ":::", 3);
    LibrarySize    = int(xxGetToken(EventData, ":::", 4));
    LibraryVersion = xxGetToken(EventData, ":::", 5);

    if (LibraryVersion == "")
        LibraryVersion = "Unknown File";

    Log("HookedModule"@LibraryAddress@LibraryName@LibraryPath@LibraryHash@LibrarySize@LibraryVersion);
*/
}

// =============================================================================
// PlayerHookedModuleExtra ~ Logs detailed information about a hook kick
// =============================================================================
function PlayerHookedModuleExtra(IACECheck Check, string EventData)
{
/*
    local string HookType;
    local string HookedFunction;
    local string HookOffset;
    local string HookDescription;
    local string HookDesc;
    local string ImportedLib;
    local string ExpectedTarget;
    local string RealTarget;

    HookType = xxGetToken(EventData, ":::", 0);

    switch (HookType)
    {
        case "CODE":
            HookedFunction = xxGetToken(EventData, ":::", 1);
            HookOffset     = xxGetToken(EventData, ":::", 2);
            HookDesc       = xxGetToken(EventData, ":::", 3);
            Log("CodeHook"@HookedFunction@HookOffset@HookDesc);
            break;

        case "IMPORT":
            HookType       = "IMPORT ADDRESS TABLE";
            ImportedLib    = xxGetToken(EventData, ":::", 1);
            ExpectedTarget = xxGetToken(EventData, ":::", 2) $ " -> " $ xxGetToken(EventData, ":::", 3) $ "!" $ xxGetToken(EventData, ":::", 4);
            RealTarget     = xxGetToken(EventData, ":::", 5) $ " -> " $ xxGetToken(EventData, ":::", 6) $ "!" $ xxGetToken(EventData, ":::", 7) $ "+" $ xxGetToken(EventData, ":::", 8);
            Log("IATHook"@ImportedLib@ExpectedTarget@RealTarget);
            break;

        case "EXPORT":
            HookType       = "EXPORT ADDRESS TABLE";
            ExpectedTarget = xxGetToken(EventData, ":::", 1) $ " -> " $ xxGetToken(EventData, ":::", 2);
            RealTarget     = xxGetToken(EventData, ":::", 3) $ " -> " $ xxGetToken(EventData, ":::", 4) $ "!" $ xxGetToken(EventData, ":::", 5);
            Log("EATHook"@ExpectedTarget@RealTarget);
            break;
    }
*/
}

// =============================================================================
// PlayerHookedPackage ~ The disk version of the package is legal but it wasn't
// mapped into the memory correctly!
// =============================================================================
function PlayerHookedPackage(IACECheck Check, string EventData)
{
/*
    local string PackageName;
    local string PackagePath;
    local string PackageHash;
    local string PackageSize;
    local string PackageVersion;

    // Parse event Data
    PackageName    = xxGetToken(EventData, ":::", 0);
    PackagePath    = xxGetToken(EventData, ":::", 1);
    PackageHash    = xxGetToken(EventData, ":::", 2);
    PackageSize    = xxGetToken(EventData, ":::", 3);
    PackageVersion = xxGetToken(EventData, ":::", 4);

    if (PackageVersion == "")
        PackageVersion = "Unknown Package";

    Log("HookedPackage"@PackageName@PackagePath@PackageHash@PackageSize@PackageVersion);
*/
}

// =============================================================================
// PlayerHookedPackageExtra ~ Extra information
// =============================================================================
function PlayerHookedPackageExtra(IACECheck Check, string EventData)
{
/*
    local string HookType;
    local string HookFunc;
    local int    HookedEntry;
    local string Target;
    local string HookChecksum;

    HookType    = xxGetToken(EventData, ":::", 0);
    HookedEntry = int(xxGetToken(EventData, ":::", 1));
    HookFunc    = xxGetToken(EventData, ":::", 2);

    // Function Hooked (pointer override)
    if (HookType == "FH")
    {
        Target = xxGetToken(EventData, ":::", 3) $ " -> " $ xxGetToken(EventData, ":::", 4) $ "!" $ xxGetToken(EventData, ":::", 5) $ "+" $ xxGetToken(EventData, ":::", 6);
        Log("HookedPackageExtra"@HookType@HookedEntry@HookFunc@Target);
    }
    // Bytecode Hack
    else if (HookType == "BH")
    {
        HookChecksum = xxGetToken(EventData, ":::", 3);
        Log("HookedPackageExtra"@HookType@HookedEntry@HookFunc@HookChecksum);
    }
*/
}

// =============================================================================
// PlayerIllegalUFunctionCall ~ Illegal UScript Function Call
// =============================================================================
function PlayerIllegalUFunctionCall(IACECheck Check, string EventData)
{
/*
    local string IllegallyCalledFunction;
    IllegallyCalledFunction = EventData;
    Log("IllegalUFunctionCall"@IllegallyCalledFunction);
*/
}

// =============================================================================
// PlayerIllegalUFunctionCallExtra ~ Extra Information for an illegal UFunction
// Call
// =============================================================================
function PlayerIllegalUFunctionCallExtra(IACECheck Check, string EventData)
{
/*
    local int    CalleeDepth; // depth in the call stack
    local string CalleeName;

    if (EventData != "")
    {
        CalleeDepth = int(xxGetToken(EventData, ":::", 0));
        CalleeName  = xxGetToken(EventData, ":::", 1);
        Log("IllegalUFunctionCallExtra"@CalleeDepth@CalleeName);
    }
*/
}

// =============================================================================
// PlayerObjectReplaced ~ an engine object has been replaced
// =============================================================================
function PlayerObjectReplaced(IACECheck Check, string EventData)
{
/*
    local string ReplacedObject;
    local string ReplacedObjectPointer;
    local string HookModuleHandle;
    local string HookModuleName;
    local string HookFunction;
    local string HookFunctionOffset;

    ReplacedObject        = xxGetToken(EventData, ":::", 0);
    ReplacedObjectPointer = xxGetToken(EventData, ":::", 1);
    HookModuleHandle      = xxGetToken(EventData, ":::", 2);
    HookModuleName        = xxGetToken(EventData, ":::", 3);
    HookFunction          = xxGetToken(EventData, ":::", 4);
    HookFunctionOffset    = xxGetToken(EventData, ":::", 5);

    Log("ObjectReplaced"@ReplacedObject@ReplacedObjectPointer@HookModuleHandle@HookModuleName@HookFunction@HookFunctionOffset);
*/
}

// =============================================================================
// PlayerVTableHook ~ Virtual function Table Hook
// =============================================================================
function PlayerVTableHook(IACECheck Check, string EventData)
{
/*
    local string HookedObject;
    local string HookedObjectPointer;
    local string HookedVTable;
    local string HookedVTableEntry;
    local string HookAddress;
    local string HookModuleName;
    local string HookFunction;

    HookedObject        = xxGetToken(EventData, ":::", 0);
    HookedObjectPointer = xxGetToken(EventData, ":::", 1);
    HookedVTable        = xxGetToken(EventData, ":::", 2);
    HookedVTableEntry   = xxGetToken(EventData, ":::", 3);
    HookAddress         = xxGetToken(EventData, ":::", 4);
    HookModuleName      = xxGetToken(EventData, ":::", 5);
    HookFunction        = xxGetToken(EventData, ":::", 6);

    Log("VTableHook"@HookedObject@HookedObjectPointer@HookedVTable@HookedVTableEntry@HookAddress@HookModuleName@HookFunction);
*/
}

// =============================================================================
// PlayerGNatHook ~ GNativesHook
// =============================================================================
function PlayerGNatHook(IACECheck Check, string EventData)
{
/*
    local string HookedEntry;
    local string ExpectedAddress;
    local string ExpectedModuleName;
    local string ExpectedFunction;
    local string ActualAddress;
    local string ActualModuleName;
    local string ActualFunction;

    HookedEntry        = xxGetToken(EventData, ":::", 0);
    ExpectedAddress    = xxGetToken(EventData, ":::", 1);  // might be empty
    ExpectedModuleName = xxGetToken(EventData, ":::", 2);  // might be empty
    ExpectedFunction   = xxGetToken(EventData, ":::", 3);  // might be empty
    ActualAddress      = xxGetToken(EventData, ":::", 4);
    ActualModuleName   = xxGetToken(EventData, ":::", 5);
    ActualFunction     = xxGetToken(EventData, ":::", 6);

    Log("GNatHook"@HookedEntry@ExpectedAddress@ExpectedModuleName@ExpectedFunction@ActualAddress@ActualModuleName@ActualFunction);
*/
}

// =============================================================================
// PlayerHostileThread ~
// =============================================================================
function PlayerHostileThread(IACECheck Check, string EventData)
{
/*
    local string ThreadId;
    local string ThreadStartAddress;
    local string ThreadInfo;

    ThreadId            = xxGetToken(EventData, ":::", 0);
    ThreadStartAddress  = xxGetToken(EventData, ":::", 1);
    ThreadInfo          = xxGetToken(EventData, ":::", 2);

    Log("HostileThread"@ThreadId@ThreadStartAddress@ThreadInfo);
*/
}

// =============================================================================
// defaultproperties
// =============================================================================
defaultproperties
{
    ACEVersion="@ACESHORTVERLOWER@"
}
