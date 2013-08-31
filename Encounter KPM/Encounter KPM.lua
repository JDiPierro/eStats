-- Imports
require 'string';
require "lib/lib_Callback2"

-- Constants
local eKPM_Version = '0.1';
local TIME_UNTIL_OUT_OF_COMBAT	= 15;		-- In seconds, change to whatever

-- Player Info
local playerName;
local frameName;

-- Per-Life Stats:
local Life = {};
Life.kills 				= 0;
Life.kpm 				= 0;
Life.xp 				= 0;

-- Encounter Stats:
local Encounter = {};
Encounter.timer 				= Callback2.Create();
Encounter.timerUpdate 			= 5;
Encounter.kills 				= 0;
Encounter.kpm 					= 0;
Encounter.xp					= 0;

--Timer Vars
local lastCombatEvent;
local startTime;
local aliveTime;

--[[====================================]]
--[[==== Helper and Debug Functions ====]]
--[[====================================]]

function msg(message)
	Component.GenerateEvent('MY_SYSTEM_MESSAGE', {text=message});
end

function DBG_OUTPUTKILLDATA()
	log("This Encounter Kills: " .. Encounter.kills);
	log("This Life's kills: " .. Life.kills);
end

--[[======================]]
--[[==== Calculations ====]]
--[[======================]]

function CalculateKPM()
	-- Calculate elapsed time since battleframe initialization
	local elapsedMins = (System.GetElapsedTime(startTime) + 1) / 60;
	-- Session Level KPM
	Encounter.kpm = Encounter.kills / (elapsedMins);
end

function addKill()
	Life.kills = Life.kills + 1;
	Encounter.kills = Encounter.kills + 1;
end

--[[======================]]
--[[==== Timer Events ====]]
--[[======================]]

function cb_UpdateEncounterKPM()
	-- log("Elapsed since LCE is: " .. tostring(System.GetElapsedTime(lastCombatEvent)));
	if (lastCombatEvent ~= nil) and (System.GetElapsedTime(lastCombatEvent) > TIME_UNTIL_OUT_OF_COMBAT) then
		OutOfCombat();
	else
		if(lastCombatEvent ~= nil) then
			CalculateKPM();

			log("Encounter KPM: " ..tostring(Encounter.kpm));
			
			Encounter.timer:Reschedule(Encounter.timerUpdate);
		end
	end
end

--[[=======================]]
--[[==== Combat Events ====]]
--[[=======================]]

function StartOfCombat()
	log("Start of Combat... set startTime to now and start timers");
	startTime = System.GetClientTime();
	Encounter.timer:Schedule(Encounter.timerUpdate);
end

function OnCombatEvent(args)
	--Negative damage is a heal. We don't want to continue an encounter once all enemies are defeated and the user is getting passively healed.
	if (args.type == "eKPM_Kill") or (args.damage > 0)then
		if(startTime == nil) then
			StartOfCombat();
			lastCombatEvent = System.GetClientTime();
		else
			lastCombatEvent = System.GetClientTime();
		end
	end
end

function OutOfCombat()
	log("Out of combat. Set startTime to nil and reset Encounter stats.");
	local elapsedMins = ((System.GetElapsedTime(startTime) - TIME_UNTIL_OUT_OF_COMBAT) + 1) / 60;
	Encounter.kpm = Encounter.kills / elapsedMins;
	local XPPM = Encounter.xp / elapsedMins;
	msg("eKPM: That encounter you had " .. string.format("%d",Encounter.kills) .. " kills over " .. string.format("%0.1f", elapsedMins) .. " minutes, and earned "..Encounter.xp.."xp. KPM: " .. string.format("%0.2f",Encounter.kpm) .. "XP/Min: " .. string.format("%0.2f", XPPM));
	
	startTime = nil;
	Encounter.kills = 0;
	Encounter.kpm = 0;
	Encounter.xp = 0;
	
	Encounter.timer:Cancel();
end

--[[=====================]]
--[[==== Game Events ====]]
--[[=====================]]

function OnKill(args)
	if (args.SourceName == playerName or string.match(args.SourceName, "Turret") or string.match(args.SourceName, "Sentinel Pod")) then
		OnCombatEvent({type = "eKPM_Kill"});
		addKill();
		-- DBG_OUTPUTKILLDATA();
	end
end

function OnBattleframeChanged()
	aliveTime = System.GetClientTime();
end

function OnDeath()
	--log("He's dead, Jim!");
	OutOfCombat();
	local elapsedMins = (System.GetElapsedTime(aliveTime) + 1) / 60;
	Life.kpm = Life.kills / (elapsedMins);
	msg("eKPM: That life you had " .. string.format("%d",Life.kills) .. " kills over " .. string.format("%0.1f", elapsedMins) .. " minutes. KPM: " .. string.format("%0.2f",Life.kpm));
	Life.kills = 0;
	Life.kpm = 0;
end

function OnAlive()
	--log("IT'S ALLIIIIIVVVE!!");
	aliveTime = System.GetClientTime();
end

function OnXP(args)
	Encounter.xp = Encounter.xp + args.delta;
	Life.xp = Life.xp + args.delta;
end

function OnPlayerReady()
	log("Player Ready!");
	playerName = Player.GetInfo();
	aliveTime = System.GetClientTime();
end

function OnComponentLoad()
	Encounter.timer:Bind(cb_UpdateEncounterKPM);
	msg('eKPM v'..eKPM_Version..' Loaded and Tracking');
end