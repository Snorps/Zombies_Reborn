// Zombie Fortress generic rules
#include "MakeCrate.as";
#include "TeamIconToken.as"


#define SERVER_ONLY

u8 warmup_days = 2;          //days of warmup-time we give to players
u8 days_to_survive = 15;     //days players must survive to win, use 0 for no win condition
f32 game_difficulty = 2.5f;  //zombie spawnrate multiplier
u16 maximum_zombies = 400;   //maximum amount of zombies that can be on the map at once

const u8 GAME_WON = 5;
const u8 nextmap_seconds = 15;
u8 seconds_till_nextmap = nextmap_seconds;

void onInit(CRules@ this)
{
	Reset(this);
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void Reset(CRules@ this)
{
	ConfigFile cfg;
	const string file = "../Cache/Zombie_Vars.cfg";
	if (CFileMatcher(file).hasMatch() ? cfg.loadFile(file) : cfg.loadFile("Zombie_Vars.cfg"))
	{
		//edit these vars in Zombie_Vars.cfg
		warmup_days     = cfg.exists("warmup_days")     ? cfg.read_u8("warmup_days")      : 2;
		days_to_survive = cfg.exists("days_to_survive") ? cfg.read_u8("days_to_survive")  : 15;
		game_difficulty = cfg.exists("game_difficulty") ? cfg.read_f32("game_difficulty") : 2.5f;
		maximum_zombies = cfg.exists("maximum_zombies") ? cfg.read_u16("maximum_zombies") : 400;
	}
	
	this.set_u8("day_number", 1);
	this.set_u8("message_timer", 1);
	
	seconds_till_nextmap = nextmap_seconds;
	this.SetCurrentState(WARMUP);
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	//set new player to survivors
	player.server_setTeamNum(0);
}

u32 getZombieSpawnDelay(u8 dayNumber) {
	//linear
	const f32 difficulty = days_to_survive / (dayNumber * game_difficulty);
	//wavey
	//const f32 difficulty = days_to_survive / (dayNumber * (game_difficulty + Maths::Sin(dayNumber)));

	return getTicksASecond() * difficulty;
}

bool debugShowZombieDays = true;
bool showNightStart = true;
bool makeOutpostCrate = true;
void onTick(CRules@ this)
{
	CMap@ map = getMap();
	
	const u32 gameTime = getGameTime();
	const u32 day_cycle = this.daycycle_speed * 60;
	const u8 dayNumber = (gameTime / getTicksASecond() / day_cycle) + 1;
	
	//debug stuff
	if (g_debug == 1 && debugShowZombieDays)
	{
		debugShowZombieDays = false;
		for (u8 i = 1; i < days_to_survive; i++)
		{
			printf("zombie spawn delay at day " + i + ": " + getZombieSpawnDelay(i));
		}
	}

	const u32 spawnDelay = getZombieSpawnDelay(dayNumber);

	const Vec2f dim = getMap().getMapDimensions();
	if (gameTime % 150 == 0 && makeOutpostCrate) {	
		CBlob@ crate = server_MakeCrateOnParachute("outpost", "Outpost", 11, 0, Vec2f(dim.x/2, -1));
		makeOutpostCrate = false;
	}

	if (map.getDayTime() > 0.85f) {
		if (showNightStart) {
			string text = "Zombies are coming. Survive.";
			setTimedGlobalMessage(this, text, 10);
			showNightStart = false;
		}
	}
	else {
		showNightStart = true;
	}

	if (gameTime % spawnDelay == 0)
	{
		spawnZombie(this, map);
	}
	
	if (gameTime % getTicksASecond() == 0) //once every second
	{
		checkDayChange(this, dayNumber);
		
		onGameEnd(this);
		
		resetTimedGlobalMessage(this);
	}
}

// Spawn various zombie blobs on the map
void spawnZombie(CRules@ this, CMap@ map)
{
	if (map.getDayTime() > 0.9f || map.getDayTime() < 0.1f)
	{
		if (maximum_zombies != 999 && this.get_u16("undead count") >= maximum_zombies) return;
		
		const u32 r = XORRandom(100);
		
		string blobname = "skeleton"; //leftover       // 40%
		
		if (r >= 95)       blobname = "greg";          // 5%
		else if (r >= 90)  blobname = "wraith";        // 5%
		else if (r >= 75)  blobname = "zombieknight";  // 15%
		else if (r >= 40)  blobname = "zombie";        // 35%
		
		server_CreateBlob(blobname, -1, getZombieSpawnPos(map));
	}
}

// Decide where zombies spawn
Vec2f getZombieSpawnPos(CMap@ map)
{
	Vec2f[] spawns;
	map.getMarkers("zombie_spawn", spawns);
	
	if (spawns.length <= 0)
	{
		Vec2f dim = map.getMapDimensions();
		const u32 margin = 10;
		const Vec2f offset = Vec2f(0, -8);
		
		Vec2f side;
		
		map.rayCastSolid(Vec2f(margin, 0.0f), Vec2f(margin, dim.y), side);
		spawns.push_back(side + offset);
		
		map.rayCastSolid(Vec2f(dim.x-margin, 0.0f), Vec2f(dim.x-margin, dim.y), side);
		spawns.push_back(side + offset);
	}
	
	return spawns[XORRandom(spawns.length)];
}

// Protocols when the day changes
void checkDayChange(CRules@ this, const u8&in dayNumber)
{
	//has the day changed?
	if (dayNumber != this.get_u8("day_number"))
	{
		string dayMessage = "Day "+dayNumber;
		
		//end warmup phase
		if (dayNumber == warmup_days)
		{
			dayMessage = "Warmup over. Day "+dayNumber+"\n\nYou can no longer respawn without an outpost.";
			this.SetCurrentState(GAME);
		}
		
		setTimedGlobalMessage(this, dayMessage, 10);
		
		//end game if we reached the last day
		if (dayNumber >= days_to_survive && days_to_survive != 0)
		{
			dayMessage = "Day "+days_to_survive+" Reached! You win!";
			this.SetCurrentState(GAME_WON);
			
			setTimedGlobalMessage(this, dayMessage, nextmap_seconds);
		}
		
		this.set_u8("day_number", dayNumber);
		this.Sync("day_number", true);
	}
}

// Set a global message with a timer to remove itself
void setTimedGlobalMessage(CRules@ this, const string&in text, const u8&in seconds)
{
	this.SetGlobalMessage(text);
	this.set_u8("message_timer", seconds);
}

// See if the global message should be cleared
void resetTimedGlobalMessage(CRules@ this)
{
	u8 message_time = this.get_u8("message_timer");
	if (message_time > 0)
	{
		message_time--;
		
		if (message_time == 0)
			this.SetGlobalMessage("");
		
		this.set_u8("message_timer", message_time);
	}
}

// Protocols for when the game ends
void onGameEnd(CRules@ this)
{
	const u8 GAME_STATE = this.getCurrentState();
	
	//timer till next map
	if (GAME_STATE == GAME_OVER || GAME_STATE == GAME_WON)
	{
		seconds_till_nextmap--;
		if (seconds_till_nextmap == 0)
		{
			LoadNextMap();
		}
	}
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	if (this.isWarmup()) return;
	
	//have all players died?
	if (!isGameLost()) return;
	
	this.SetCurrentState(GAME_OVER);
	setTimedGlobalMessage(this, "Game over! All survivors perished! You lasted "+this.get_u8("day_number")+" days.", nextmap_seconds);
}

// Check if we lost the game
const bool isGameLost()
{
	CMap@ map = getMap();

	/*if (map.getDayTime() > 0.0f && map.getDayTime() < 0.9f) { //if daytime, game is not lost
		return false;
	}*/

	CBlob@[] posts;
	getBlobsByTag("respawn", @posts);
	if (posts.length() > 0) { //if outpost exists, game is not lost
		return false;
	}


	bool noAlivePlayers = true;
	
	const u8 playerCount = getPlayerCount();
	for (u8 i = 0; i < playerCount; i++)
	{
		CPlayer@ ply = getPlayer(i);
		if (ply is null) continue;
		
		CBlob@ plyBlob = ply.getBlob();
		if (plyBlob !is null && !plyBlob.hasTag("undead") && !plyBlob.hasTag("dead"))
		{
			noAlivePlayers = false;
			break;
		}
	}

	
	return noAlivePlayers;
}
