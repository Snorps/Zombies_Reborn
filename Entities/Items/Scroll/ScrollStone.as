// scroll script that converts stone ore into thick stone

#include "GenericButtonCommon.as";
#include "Zombie_Translation.as";

const int radius = 10;

void onInit(CBlob@ this)
{
	this.addCommandID("stone");
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller) || (this.getPosition() - caller.getPosition()).Length() > 50.0f) return;

	caller.CreateGenericButton(11, Vec2f_zero, this, this.getCommandID("stone"), ZombieDesc::scroll_stone);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("stone"))
	{
		bool acted = false;
		CMap@ map = getMap();
		Vec2f pos = this.getPosition();
		const f32 radsq = radius * 8 * radius * 8;

		for (int x_step = -radius; x_step < radius; ++x_step)
		{
			for (int y_step = -radius; y_step < radius; ++y_step)
			{
				Vec2f off(x_step * map.tilesize, y_step * map.tilesize);
				if (off.LengthSquared() > radsq) continue;

				Vec2f tpos = pos + off;

				TileType t = map.getTile(tpos).type;
				if (map.isTileStone(t) && !map.isTileThickStone(t))
				{
					map.server_SetTile(tpos, CMap::tile_thickstone);
					acted = true;
				}
				else if (map.isTileGround(t) && XORRandom(4) == 0)
				{
					map.server_SetTile(tpos, CMap::tile_stone);
					acted = true;
				}
			}
		}


		if (acted)
		{
			Sound::Play("MagicWand.ogg", pos);
			this.server_Die();
		}
	}
}
