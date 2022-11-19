//Zombie Fortress player respawning

#define SERVER_ONLY

const string startClass = "builder";   //the class that players will spawn as
const u32 spawnTimeMargin = 8;         //max amount of random seconds we can give to respawns
const u32 baseRespawnTimeDay = 8; //base respawn time during day
const u32 nightRespawnGracePeriod = 10; //number of seconds to secretly delay hardcore respawns after each night starts


shared class Respawn
{
	string username;
	u32 timeStarted;

	Respawn(const string _username, const u32 _timeStarted)
	{
		username = _username;
		timeStarted = _timeStarted;
	}
};

void onInit(CRules@ this)
{
	Respawn[] respawns;
	this.set("respawns", respawns);
}

void onRestart(CRules@ this)
{
	this.clear("respawns");
	
	const u32 gameTime = getGameTime();
	const u8 plyCount = getPlayerCount();
	for (u8 i = 0; i < plyCount; i++)
	{
		CPlayer@ player = getPlayer(i);
		Respawn r(player.getUsername(), gameTime);
		this.push("respawns", r);
		syncRespawnTime(this, player, gameTime);
	}
}

float lastDayTime = 0;
void onTick(CRules@ this)
{
	const u32 gametime = getGameTime();
	if (gametime % 30 == 0 && !this.isGameOver())
	{
		Respawn[]@ respawns;
		if (!this.get("respawns", @respawns)) return;
		
		for (u8 i = 0; i < respawns.length; i++)
		{
			Respawn@ r = respawns[i];
			if (r.timeStarted == 0 || r.timeStarted <= gametime)
			{
				spawnPlayer(this, getPlayerByUsername(r.username));
				respawns.erase(i);
				i = 0;
			}
		}
	}
	if (g_debug == 1) {
		const u32 newTime = Maths::Floor(getMap().getDayTime() * 10);
		if (newTime != lastDayTime) {
			lastDayTime = newTime;
			printf("Day time is " + float(newTime)/10);
		}
	}
}


void onPlayerRequestSpawn(CRules@ this, CPlayer@ player)
{
	if (!isRespawnAdded(this, player.getUsername()))
	{
		CMap@ map = getMap();
		const f32 dayTime = map.getDayTime();
		
		

		const u32 gameTime = getGameTime();
		const u32 day_cycle = this.daycycle_speed * 60;
		const u8 dayNumber = (gameTime / getTicksASecond() / day_cycle) + 1;

		//const u32 timeElapsed = (gametime / getTicksASecond()) % day_cycle;
		//const s32 timeTillDawn = (day_cycle - timeElapsed) / 2;

		const float datetime = dayTime + dayNumber;
		float nextDawn;
		if (dayTime < 0.1) {
			nextDawn = dayNumber + 0.1;
		} else
		{
			nextDawn = dayNumber + 1.1;
		}
		//find difference between current datetime and next increment of 1.1 (i.e next increment - current datetime)
		const float dawnDelta = nextDawn - (dayTime + dayNumber);
		//multiple by day_cycle
		const s32 timeTillDawn = (dawnDelta) * day_cycle;

		if (g_debug == 1) {
			printf("datetime: " + datetime + "    nextDawn: " + nextDawn + "    dawnDelta: " + dawnDelta);
		}

		const float gracePeriod = float(nightRespawnGracePeriod)/float(day_cycle);
		const bool isDay = dayTime > 0.1f && dayTime < 0.9f + gracePeriod;


		const s32 baseTime = isDay ? baseRespawnTimeDay : timeTillDawn;
		const s32 randomTime = (baseTime + XORRandom(spawnTimeMargin));


		bool skipWait = this.isWarmup();
		const s32 timeTillRespawn = skipWait ? 0 : randomTime * getTicksASecond();

		if (g_debug == 1) {
			printf("Skip wait?: " + skipWait + "    timeTillDawn: " + timeTillDawn + "    Base respawn time: " + baseTime);
		}

		Respawn r(player.getUsername(), timeTillRespawn + gameTime);
		this.push("respawns", r);
		syncRespawnTime(this, player, timeTillRespawn + gameTime);
	}
}

const bool isRespawnAdded(CRules@ this, const string&in username)
{
	Respawn[]@ respawns;
	if (this.get("respawns", @respawns))
	{
		const u8 respawnLength = respawns.length;
		for (u8 i = 0; i < respawnLength; i++)
		{
			Respawn@ r = respawns[i];
			if (r.username == username)
				return true;
		}
	}
	return false;
}

CBlob@ spawnPlayer(CRules@ this, CPlayer@ player)
{
	if (player !is null)
	{
		//remove previous players blob
		CBlob@ blob = player.getBlob();
		if (blob !is null)
		{
			blob.server_SetPlayer(null);
			blob.server_Die();
		}

		Vec2f spawnLocation = getSpawnLocation();

		CBlob@ newBlob = server_CreateBlob(startClass, 0, spawnLocation);
		newBlob.server_SetPlayer(player);
		
		if (this.hasCommandID("give_parachute") && spawnLocation.y == 0)
		{
			CBitStream bs;
			bs.write_netid(newBlob.getNetworkID());
			this.SendCommand(this.getCommandID("give_parachute"), bs);
		}
		
		return newBlob;
	}

	return null;
}

Vec2f getSpawnLocation()
{
	const Vec2f dim = getMap().getMapDimensions();
	Vec2f spawn = Vec2f(XORRandom(dim.x), 0);

	CBlob@[] posts;
	getBlobsByTag("respawn", @posts);

	if (posts.length() > 0) {
		spawn = posts[0].getPosition();
	}

	return spawn;
}

void syncRespawnTime(CRules@ this, CPlayer@ player, const u32&in time)
{
	this.set_u32("respawn time", time);
	this.SyncToPlayer("respawn time", player);
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("remove respawn"))
	{
		const string username = params.read_string();
		
		Respawn[]@ respawns;
		if (!this.get("respawns", @respawns)) return;
		
		for (u8 i = 0; i < respawns.length; i++)
		{
			Respawn@ r = respawns[i];
			if (r.username == username)
			{
				respawns.erase(i);
				break;
			}
		}
	}
}
