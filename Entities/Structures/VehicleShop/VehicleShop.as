﻿// Vehicle Workshop

#include "Requirements.as"
#include "Requirements_Tech.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "TeamIconToken.as"
#include "Zombie_Translation.as";

void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;
	
	this.getCurrentScript().tickFrequency = 90;

	//INIT COSTS
	InitCosts();

	// SHOP
	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(6, 6));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	const u8 team_num = this.getTeamNum();

	{
		const string cata_icon = getTeamIcon("catapult", "VehicleIcons.png", team_num, Vec2f(32, 32), 0);
		ShopItem@ s = addShopItem(this, "Catapult", cata_icon, "catapult", cata_icon + "\n\n\n" + Descriptions::catapult, false, true);
		s.crate_icon = 4;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::catapult);
	}
	{
		const string ballista_icon = getTeamIcon("ballista", "VehicleIcons.png", team_num, Vec2f(32, 32), 1);
		ShopItem@ s = addShopItem(this, "Ballista", ballista_icon, "ballista", ballista_icon + "\n\n\n" + ZombieDesc::ballista, false, true);
		s.crate_icon = 5;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista);
	}
	{
		const string bomber_icon = getTeamIcon("bomber", "Icon_Bomber.png", team_num, Vec2f(44, 74), 0);
		ShopItem@ s = addShopItem(this, "Bomber", bomber_icon, "bomber", ZombieDesc::bomber, false, true);
		s.crate_icon = 7;
		AddRequirement(s.requirements, "coin", "", "Coins", 150);
		AddRequirement(s.requirements, "blob", "mat_gold", "Gold", 50);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 200);
	}
	{
		const string bow_icon = getTeamIcon("mounted_bow", "MountedBow.png", team_num, Vec2f(16, 16), 6);
		ShopItem@ s = addShopItem(this, "Mounted Bow", bow_icon, "mounted_bow", ZombieDesc::mounted_bow, false, true);
		s.crate_icon = 6;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 2;
		AddRequirement(s.requirements, "coin", "", "Coins", 85);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 100);
	}
	{
		ShopItem@ s = addShopItem(this, "Ballista Ammo", "$mat_bolts$", "mat_bolts", "$mat_bolts$\n\n\n" + Descriptions::ballista_ammo, false, false);
		s.crate_icon = 5;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista_ammo);
	}
	{
		ShopItem@ s = addShopItem(this, "Ballista Shells", "$mat_bomb_bolts$", "mat_bomb_bolts", "$mat_bomb_bolts$\n\n\n" + Descriptions::ballista_bomb_ammo, false, false);
		s.crate_icon = 5;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista_bomb_ammo);
	}
	{
		string outpost_icon = getTeamIcon("outpost", "VehicleIcons.png", team_num, Vec2f(32, 32), 6);
		ShopItem@ s = addShopItem(this, "Outpost", outpost_icon, "outpost", outpost_icon + "\n\n\n" + Descriptions::outpost, false, true);
		s.crate_icon = 7;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::outpost_coins);
		AddRequirement(s.requirements, "blob", "mat_gold", "Gold", CTFCosts::outpost_gold);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	this.set_bool("shop available", this.isOverlapping(caller));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item"))
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
		u16 caller, item;
		if (!params.saferead_netid(caller) || !params.saferead_netid(item))
		{
			return;
		}
		string name = params.read_string();
		{
			if (name == "bomber")
			{
				// makes crate still drop gold if it breaks before it's unpacked
				// Crate.as prevents gold from dropping if it dies after unpack
				CBlob@ box = getBlobByNetworkID(item);
				if (box !is null) box.set_s32("gold building amount", 50);
			}
		}
	}
}

void onTick(CBlob@ this)
{
	if (!isServer()) return;
	
	//heal overlapping vehicles
	CBlob@[] overlapping;
	if (this.getOverlapping(@overlapping))
	{
		const u8 blobsLength = overlapping.length;
		for (u8 i = 0; i < blobsLength; ++i)
		{
			CBlob@ blob = overlapping[i];
			const f32 initialHealth = blob.getInitialHealth();
			if (blob.hasTag("vehicle") && blob.getHealth() < initialHealth)
			{
				blob.server_SetHealth(Maths::Min(blob.getHealth() + initialHealth / 15, initialHealth));
			}
		}
	}
}
