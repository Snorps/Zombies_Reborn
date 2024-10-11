//Gingerbeard @ August 9, 2024

#include "EquipmentCommon.as"

const string[] equipment =
{
	"head",
	"torso"
	//"feet"
};

void onInit(CBlob@ this)
{
	this.addCommandID("server_equip");
	this.addCommandID("client_equip");
	
	for (u8 i = 0; i < equipment.length; i++)
	{
		AddIconToken("$"+equipment[i]+"_empty$", "Equipment.png", Vec2f(24, 24), i, 0);
	}
	
	u16[] ids(equipment.length);
	this.set("equipment_ids", ids);
}

void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu@ gridmenu)
{
	Vec2f MENU_POS = gridmenu.getUpperLeftPosition() + Vec2f(-25, 48);
	CGridMenu@ equipment_menu = CreateGridMenu(MENU_POS, this, Vec2f(1, equipment.length), "equipment_menu");
	if (equipment_menu is null) return;

	equipment_menu.SetCaptionEnabled(false);
	equipment_menu.deleteAfterClick = false;

	u16[] ids;
	if (!this.get("equipment_ids", ids)) return;

	CBlob@ carried = this.getCarriedBlob();

	for (u8 i = 0; i < equipment.length; i++)
	{
		string icon = "$"+equipment[i]+"_empty$";
		string hover = "";
		
		if (carried !is null && canEquip(carried, i))
		{
			hover = "Equip "+carried.getInventoryName();
		}
		CBlob@ equipped = getBlobByNetworkID(ids[i]);
		if (equipped !is null)
		{
			icon = "$"+equipped.getName()+"$";
			hover = "Unequip "+equipped.getInventoryName();
		}

		CBitStream params;
		params.write_netid(this.getNetworkID());
		params.write_u8(i);
		CGridButton@ button = equipment_menu.AddButton(icon, "", "Equipment.as", "Callback_Equip", Vec2f(1, 1), params);
		if (button !is null)
		{
			button.SetHoverText(hover);
		}
	}
}

bool canEquip(CBlob@ blob, const u8&in slot)
{
	return blob.exists("equipment_slot") && blob.get_string("equipment_slot") == equipment[slot];
}

void Callback_Equip(CBitStream@ params)
{
	CBlob@ this = getBlobByNetworkID(params.read_netid());
	if (this is null) return;
	
	getHUD().ClearMenus();
	
	const u8 index = params.read_u8();
	
	CBitStream stream;
	stream.write_u8(index);
	this.SendCommand(this.getCommandID("server_equip"), stream);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("server_equip") && isServer())
	{
		u16[] ids;
		this.get("equipment_ids", ids);
		u16 equipped = 0;
		u16 unequipped = 0;
		const u8 slot = params.read_u8();
		
		//unequip
		CBlob@ equippedblob = getBlobByNetworkID(ids[slot]);
		if (equippedblob !is null)
		{
			unequipped = ids[slot];
			ids[slot] = 0;
			UnequipBlob(this, equippedblob);
		}

		//equip
		CBlob@ carried = this.getCarriedBlob();
		if (carried !is null && canEquip(carried, slot))
		{
			const bool isSameEquipment = equippedblob !is null && equippedblob.getName() == carried.getName();
			if (!isSameEquipment)
			{
				equipped = carried.getNetworkID();
				ids[slot] = equipped;
				EquipBlob(this, carried);
			}
		}
		this.set("equipment_ids", ids);
		
		if (!isClient()) //no need to sync on localhost
		{
			CBitStream stream;
			stream.write_netid(unequipped);
			stream.write_netid(equipped);
			SerializeEquipment(ids, stream);
			this.SendCommand(this.getCommandID("client_equip"), stream);
		}
	}
	else if (cmd == this.getCommandID("client_equip") && isClient())
	{
		CBlob@ unequippedblob = getBlobByNetworkID(params.read_netid());
		if (unequippedblob !is null)
			UnequipBlob(this, unequippedblob);
		CBlob@ equippedblob = getBlobByNetworkID(params.read_netid());
		if (equippedblob !is null)
			EquipBlob(this, equippedblob);

		UnserializeEquipment(this, params);
	}
}

void EquipBlob(CBlob@ this, CBlob@ equippedblob)
{
	//equippedblob.server_RemoveFromInventories();
	equippedblob.server_DetachFromAll();
	equippedblob.setPosition(Vec2f(0,0));
	equippedblob.setVelocity(Vec2f(0,0));
	equippedblob.setAngularVelocity(0.0f);
	equippedblob.SetVisible(false);

	SetBlobActive(equippedblob, false);

	onEquipHandle@ onEquip;
	if (equippedblob.get("onEquip handle", @onEquip)) 
		onEquip(equippedblob, this);
}

void UnequipBlob(CBlob@ this, CBlob@ equippedblob, const bool&in put_in_inventory = true)
{
	equippedblob.SetVisible(true);
	equippedblob.setPosition(this.getPosition());
	if (put_in_inventory)
		this.server_PutInInventory(equippedblob);

	SetBlobActive(equippedblob, true);

	onUnequipHandle@ onUnequip;
	if (equippedblob.get("onUnequip handle", @onUnequip)) 
		onUnequip(equippedblob, this);
}

void SetBlobActive(CBlob@ equippedblob, const bool&in active)
{
	CShape@ shape = equippedblob.getShape();
	shape.server_SetActive(active);
	shape.doTickScripts = active;
	shape.SetGravityScale(active ? 1.0f : 0.0f);
	ShapeConsts@ consts = shape.getConsts();
	consts.collidable = active;
	consts.mapCollisions = active;
}

void onTick(CBlob@ this)
{
	u16[] ids;
	if (!this.get("equipment_ids", ids)) return;
	for (u8 i = 0; i < ids.length; i++)
	{
		CBlob@ equippedblob = getBlobByNetworkID(ids[i]);
		if (equippedblob is null) continue;

		onTickHandle@ onTickEquipped;
		if (equippedblob.get("onTickEquipped handle", @onTickEquipped)) 
			onTickEquipped(equippedblob, this);
	}
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	u16[] ids;
	if (!blob.get("equipment_ids", ids)) return;
	for (u8 i = 0; i < ids.length; i++)
	{
		CBlob@ equippedblob = getBlobByNetworkID(ids[i]);
		if (equippedblob is null) continue;

		onTickSpriteHandle@ onTickSpriteEquipped;
		if (equippedblob.get("onTickSpriteEquipped handle", @onTickSpriteEquipped)) 
			onTickSpriteEquipped(equippedblob, this);
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	u16[] ids;
	if (!this.get("equipment_ids", ids)) return damage;
	for (u8 i = 0; i < ids.length; i++)
	{
		CBlob@ equippedblob = getBlobByNetworkID(ids[i]);
		if (equippedblob is null) continue;

		onHitHandle@ onHitOwner;
		if (equippedblob.get("onHitOwner handle", @onHitOwner))
		{
			damage = onHitOwner(equippedblob, this, worldPoint, velocity, damage, hitterBlob, customData);
		}
	}
	return damage;
}

void onDie(CBlob@ this)
{
	u16[] ids;
	if (!this.get("equipment_ids", ids)) return;
	for (u8 i = 0; i < ids.length; i++)
	{
		CBlob@ equippedblob = getBlobByNetworkID(ids[i]);
		if (equippedblob is null) continue;

		UnequipBlob(this, equippedblob, false);
	}
	
	EquipToNewPlayerBlob(this, ids);
}

void EquipToNewPlayerBlob(CBlob@ this, u16[]@ ids)
{
	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner is null) return;
	
	CBlob@ newPlayerBlob = owner.getBlob();
	if (newPlayerBlob is null) return;
	
	if (newPlayerBlob is this || newPlayerBlob.hasTag("dead")) return;
	
	u16[]@ new_ids;
	if (!newPlayerBlob.get("equipment_ids", @new_ids)) return;

	for (u8 i = 0; i < ids.length; i++)
	{
		CBlob@ equipment = getBlobByNetworkID(ids[i]);
		if (equipment is null) continue;
		
		new_ids[i] = ids[i];

		EquipBlob(newPlayerBlob, equipment);
	}
}

///NETWORK

void SerializeEquipment(u16[] ids, CBitStream@ params)
{
	params.write_u8(ids.length);
	for (u8 i = 0; i < ids.length; i++)
	{
		params.write_netid(ids[i]);
	}
}

bool UnserializeEquipment(CBlob@ this, CBitStream@ params)
{
	u8 ids_length;
	if (!params.saferead_u8(ids_length)) return false;
	
	u16[] ids(ids_length);
	for (u8 i = 0; i < ids_length; i++)
	{
		u16 id;
		if (!params.saferead_netid(id)) return false;
		ids[i] = id; //copy over netids
	}

	this.set("equipment_ids", ids);
	return true;
}

void onSendCreateData(CBlob@ this, CBitStream@ params)
{
	params.write_u32(this.getTickSinceCreated());
	u16[] ids;
	if (this.get("equipment_ids", ids))
		SerializeEquipment(ids, params);
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ params)
{
	u32 ticks_alive;
	if (!params.saferead_u32(ticks_alive)) return false;
	
	if (!UnserializeEquipment(this, params)) return false;

	if (ticks_alive > 0)
	{
		u16[] ids;
		this.get("equipment_ids", ids);
		for (u8 i = 0; i < ids.length; i++)
		{
			CBlob@ equippedblob = getBlobByNetworkID(ids[i]);
			if (equippedblob is null) continue;

			onClientJoinHandle@ onClientJoin;
			if (equippedblob.get("onClientJoin handle", @onClientJoin)) 
				onClientJoin(equippedblob, this);
		}
	}

	return true;
}
