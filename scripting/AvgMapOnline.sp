#include <sourcemod>

#pragma newdecls required

Database Db;
char Map[64];
bool DatabaseIsLoaded;
int Clients, Online, Count, Time, CD, CommandCoolDown;

public Plugin myinfo = 
{
	name = "AvgMapOnline",
	version = "1.0",
	description = "Counts average online on maps",
	author = "hEl",
	url = ""
};

public void OnPluginStart()
{
	char szBuffer[256];
	Db = SQLite_UseDatabase("avgonline", szBuffer, 256);
	ConnectCallBack(Db, szBuffer, 0);
	
	RegAdminCmd("sm_avgonline_dump", Command_Dump, ADMFLAG_GENERIC);
}

public Action Command_Dump(int iClient, int iArgs)
{
	if(iClient && !IsFakeClient(iClient))
	{
		if(DatabaseIsLoaded)
		{
			int iTime = GetTime(), iDifferent = CommandCoolDown - iTime;
			if(iDifferent <= 0)
			{
				CommandCoolDown = iTime + 30;
				char szBuffer[256];
				int iDays = 1;
				
				if(iArgs)
				{
					GetCmdArg(1, szBuffer, 256);
					if((iDays = StringToInt(szBuffer)) < 1)
						iDays = 1;
				}
				DataPack hPack = new DataPack();
				hPack.WriteCell(iClient);
				hPack.WriteCell(iDays);
				Db.Format(szBuffer, 256, "SELECT * FROM `avgonline` WHERE %i - `lastplayed` <= %i ORDER BY `lastplayed` DESC", iTime, iDays * 86400);
				Db.Query(SQL_Callback_Dump, szBuffer, hPack);
			}
			else
			{
				PrintToChat(iClient, "[SM] Avg Online: Next dump will availbale in %i seconds", iDifferent);
			}
		}
		else
		{
			PrintToChat(iClient, "[SM] Avg Online: The database is still being loaded");
			
		}

	}
	
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	OnMapEnd();
}

public void SQL_Callback_Dump(Database hDatabase, DBResultSet hResults, const char[] szError, DataPack hPack)
{
	hPack.Reset();
	int iClient = hPack.ReadCell(), iDays = hPack.ReadCell();
	delete hPack;
	if(szError[0])
	{
		LogError("SQL_Callback_Dump: %s", szError);
		return;
	}
	if(!iClient || !IsClientInGame(iClient))
	{
		return;
	}
	
	int iCount = hResults.RowCount;
	if(iCount)
	{
		int Players;
		PrintToChat(iClient, "[SM] Avg Online: %i maps were played in %i %s", iCount, iDays, iDays == 1 ? "day":"days");
		PrintToChat(iClient, "=============================================");
		
		while(hResults.FetchRow())
		{
			int iPlayers = hResults.FetchInt(1);
			char szBuffer[2][64];
			hResults.FetchString(0, szBuffer[0], 64);
			FormatTime(szBuffer[1], 64, "%F %X", hResults.FetchInt(3));
			
			PrintToChat(iClient, "[SM] Avg Online: Map %s (%s) | Players: %i | Play time: %i", szBuffer[0], szBuffer[1], iPlayers, hResults.FetchInt(2));
			Players += iPlayers;
		}
		PrintToChat(iClient, "=============================================");
		
		PrintToChat(iClient, "Avg Online: %i clients", Players / iCount);
	}
}


public void ConnectCallBack(Database hDatabase, const char[] sError, any data)
{
	if (!hDatabase)
	{
		SetFailState("Database failure: %s", sError);
	}
	
	Db = hDatabase;
	
	SQL_LockDatabase(Db);
	Db.Query(SQL_Callback_CreateTables, "CREATE TABLE IF NOT EXISTS `avgonline` (\
															`name` VARCHAR(64) NOT NULL,\
															`online` INTEGER NOT NULL default '0',\
															`playtime` INTEGER NOT NULL default '0',\
															`lastplayed` INTEGER UNSIGNED NOT NULL);");
							  
	SQL_UnlockDatabase(Db);
	Db.SetCharset("utf8");

}

public void SQL_Callback_CreateTables(Database hDatabase, DBResultSet results, const char[] szError, int iData)
{
	if(szError[0])
	{
		LogError("SQL_Callback_CreateTables: %s", szError);
		return;
	}
	DatabaseIsLoaded = true;
	Clients = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		EditClients(i);
	}
	OnMapStart();
	CreateTimer(10.0, Timer_GetOnline, _, TIMER_REPEAT);
}



public void OnMapEnd()
{
	if(!DatabaseIsLoaded)
		return;
	
	int Playtime = GetTime() - Time;
	if(Map[0] && Count && Playtime > 300)
	{
		Online /= Count;
		char szBuffer[256];
		Db.Format(szBuffer, 256, "INSERT INTO `avgonline` (`name`, `online`, `playtime`, `lastplayed`) VALUES ('%s', %i, %i, %i);", Map, Online, Playtime, Time);
		Db.Query(SQL_Callback_CheckError, szBuffer);
		
		LogMessage("Map: %s | Average online = %i players | playtime = %i", Map, Online, Playtime);
	}
	
	ClearData();
}

public void OnMapStart()
{
	if(!DatabaseIsLoaded)
		return;
		
	ClearData();
	
	CD = 30;
	Time = GetTime();
	
	GetCurrentMap(Map, 64);
	StringToLowercase(Map);
}


public void OnClientPutInServer(int iClient)
{
	EditClients(iClient);
}

public void OnClientDisconnect(int iClient)
{
	EditClients(iClient, false);
}

bool EditClients(int iClient, bool bToggle = true)
{
	if(IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		if(bToggle)
		{
			Clients++;
		}
		else
		{
			Clients--;
		}
	}
}


stock void StringToLowercase(char[] sText)
{
	int iLen = strlen(sText);
	for(int i; i < iLen; i++)
	{
		if(IsCharUpper(sText[i]))
		{
			sText[i] = CharToLower(sText[i]);
		}
	}
}

public Action Timer_GetOnline(Handle hTimer)
{
	if(CD <= 0)
	{
		Count++;
		Online += Clients;
	}
	else
	{
		CD -= 10;
	}

}

public void SQL_Callback_CheckError(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("SQL_Callback_CheckError: %s", szError);
	}
}

void ClearData()
{
	Map[0] = 
	Time = 
	Count = 
	Online = 0;
}