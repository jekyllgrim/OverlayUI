version "4.10"

class JGP_StateSeqUI
{	
	int ID;
	State curState;
	double ticCounter;
	double alpha;
	bool bright;
}

class JGP_OverlayUI : EventHandler
{
	ui double FRAMERATE;
	array <JGP_StateSeqUI> uiStates;
	ui double prevMS;
	ui double deltaTime;
	ui PlayerInfo CPlayer;
	ui PlayerPawn CPlayerPawn;

	ui PlayerInfo, PlayerPawn GetConsolePlayer()
	{
		if (!PlayerInGame[consoleplayer])
			return null, null;

		if (!CPlayer)
			CPlayer = players[consoleplayer];
		
		if (!CPlayerPawn)
			CPlayerPawn = CPlayer.mo;
		
		return CPlayer, CPlayerPawn;
	}

	// Creates an UI overlay:
	static void CreateOverlayUI(int layer, State st, bool noOverride = false, double alpha = 1.0, bool bright = false)
	{
		let evh = JGP_OverlayUI(EventHandler.Find("JGP_OverlayUI"));
		if(evh)
		{
			JGP_StateSeqUI ssu = evh.FindLayerByID(layer);
			// move existing layer to anoter sequence:
			if (ssu) 
			{
				if (noOverride)
				{
					return;
				}
				ssu.curstate = st;
				ssu.alpha = alpha;
				ssu.bright = bright;
			}
			// otherwise create a new layer:
			else
			{
				console.printf("Creating UI layer %d.", layer);
				ssu = new("JGP_StateSeqUI");
				ssu.ID = layer;
				ssu.curstate = st;
				ssu.alpha = alpha;
				ssu.bright = bright;
				// insert it at the right place
				// so that they're arranged in the array
				// in an ascending order:
				bool inserted;
				for (int i = 0; i < evh.uiStates.Size(); i++)
				{
					let uiState = evh.uiStates[i];
					if (uiState && uiState.ID > ssu.ID)
					{
						inserted = true;
						evh.uiStates.Insert(i, ssu);
						break;
					}
				}
				if (!inserted)
					evh.uiStates.Push(ssu);
			}
		}
	}

	// Finds a UI overlay but a layer number:
	clearscope JGP_StateSeqUI, int FindLayerByID(int ID)
	{
		for (int i = uiStates.Size() - 1; i >= 0; i--)
		{
			let ssu = uiStates[i];
			if (ssu && ssu.ID == ID)
			{
				return ssu, i;
				break;
			}
		}
		return null, uiStates.Size();
	}

	static void SetOverlayUIAlpha(int layer, double alpha)
	{
		let evh = JGP_OverlayUI(EventHandler.Find("JGP_OverlayUI"));
		if(evh)
		{
			let ssu = evh.FindLayerByID(layer);
			if (ssu) 
			{
				ssu.alpha = alpha;
			}
		}
	}

	static void ClearUILayer(int layer)
	{
		let evh = JGP_OverlayUI(EventHandler.Find("JGP_OverlayUI"));
		if(evh)
		{
			JGP_StateSeqUI ssu; int id;
			[ssu, id] = evh.FindLayerByID(layer);
			if (ssu) 
			{
				ssu.curstate = null;
				evh.uiStates.Delete(id);
			}
		}
	}

	// USE WITH CARE!
	// Since the UI overlay states aren't synced,
	// doing anything in play-scope based on the result
	// of this function will cause desyncs:
	static clearscope state GetUILayerState(int layer) 
	{
		let evh = JGP_OverlayUI(EventHandler.Find("JGP_OverlayUI"));
		if(evh)
		{
			let ssu = evh.FindLayerByID(layer);
			if (ssu) 
			{
				return ssu.curstate;
			}
		}
		return null;
	}

	// Modifies overlay's framerate from play any scope.
	// Should be sync-safe:
	static clearscope void SetFramerate(double newFPS)
	{
		SendInterfaceEvent(consoleplayer, "SetOverlayUIFPS", newFPS);
	}

	// This lets us safely modify framerate
	// from play scope:
	override void InterfaceProcess(consoleEvent e)
	{
		if (e.name ~== "SetOverlayUIFPS" && !e.IsManual)
		{
			FRAMERATE = abs(e.args[0]);
		}
	}

	ui double GetFramerate()
	{
		return FRAMERATE;
	}
	
	override void RenderUnderlay(RenderEvent e)
	{
		PlayerInfo player; PlayerPawn ppawn;
		[player, ppawn] = GetConsolePlayer();
		if (!player || !ppawn)
			return;
	
		double cFPS = GetFramerate();

		for (int i = 0; i < uiStates.Size(); i++)
		{
			let uiState = uiStates[i];
			if (uistate && uiState.curstate)
			{
				vector2 baseVres = (320, 200);
			
				TextureID texID; bool xflip; vector2 scale;
				[texID, xflip, scale] = uiState.curState.GetSpriteTexture(0);
				//vector2 texSize;
				//[texsize.x, texsize.y] = TexMan.GetSize(texID);

				vector2 drawPos = (0,0);
				let psp = player.FindPSprite(PSP_WEAPON);
				if (psp)
				{
					vector2 bob = BobWeaponUI();
					drawpos.x = psp.x + bob.x;
					drawpos.y = psp.y + bob.y;
				}

				Screen.DrawTexture(texID, false, drawPos.x, drawPos.y,
					DTA_VirtualWidthF, baseVres.x,
					DTA_VirtualHeightF, baseVres.y,
					DTA_Alpha, uiState.alpha,
					//DTA_DestWidthF, texsize.x * scale.x,
					//DTA_DestHeightF, texsize.y * scale.y,
					DTA_FullScreenScale, FSMode_ScaleToHeight
				);

				
				if (!uiState.bright)
				{
					Sector sec = ppawn.cursector;
					int lightlv = sec.GetLightLevel();
					int shadowAlpha = JGP_Utils.LinearMap(lightlv, 0, 256, 256, 0);
					Screen.DrawTexture(texID, false, drawPos.x, drawPos.y,
						DTA_VirtualWidthF, baseVres.x,
						DTA_VirtualHeightF, baseVres.y,
						DTA_ColorOverlay, color(shadowAlpha, 0, 0, 0),
						DTA_FullScreenScale, FSMode_ScaleToHeight
					);
				}
				
				uiState.ticCounter += deltaTime;
			}

			// Only progress to next state if it exists
			// and framerate is above 0:
			if(cFPS > 0 && uiState.curState && uiState.ticCounter >= uiState.curState.tics)
			{
				uiState.curState = uiState.curState.NextState;
				uiState.ticCounter = 0;
			}
		}

		// Keep track of time, always.
		if(!prevMS)
		{
			prevMS = MSTimeF();
			return;
		}
		if (cFPS > 0) 
		{
			double ftime = MSTimeF()-prevMS;
			prevMS = MSTimeF();		
			double dtime = 1000.0 / cfps * Clamp(i_timescale, 1, 100);
			deltatime = (ftime/dtime);
		}
	}

	ui double curbob;
	ui double prevBob;
	ui Vector2 BobWeaponUI (double ticfrac = 1.)
	{
		Vector2 p1, p2, r;

		PlayerInfo player; PlayerPawn ppawn;
		[player, ppawn] = GetConsolePlayer();
		if (!player || !ppawn)
			return (0, 0);

		// This is where you would either call BobWeapon()
		// (which we can't do because it's a play-scope function),
		// or copy-paste the contents of BobWeapon() (which we
		// can't do under the MIT license).
		// Feel free to copy-paste BobWeapon() yourself,
		// but remember that that would require GPLv3.
		
		return p1 * (1. - ticfrac) + p2 * ticfrac;
	}
}