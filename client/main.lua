-- Initiate the pool tables
voice = {
  CallPool = {},
  RadioPool = {},
  PlayerPool = {},
};

-- Citizen Natives
local CreateThread = Citizen.CreateThread;
local Wait = Citizen.Wait;

-- Game Natives
local GetPlayerPed = GetPlayerPed;
local PlayerPedId = PlayerPedId;
local GetEntityCoords = GetEntityCoords;
local GetPlayerServerId = GetPlayerServerId;
local GetPlayerFromServerId = GetPlayerFromServerId;

-- Lua Globals
local math_cos = math.cos;
local math_sin = math.sin;
local table_insert = table.insert;
local pairs = pairs;

-- Variables
local Config = nil;
local UserName = '';
local UserId = GetPlayerServerId(PlayerId());
local loop = false;

local Player = PlayerPedId();

-- Register Events
-- Player Events
RegisterNetEvent('voice:VoiceRangeChanged');
RegisterNetEvent('voice:RadioChannelChanged');
RegisterNetEvent('voice:CallChanged');
RegisterNetEvent('voice:PlayerLoaded');
-- Global Events
RegisterNetEvent('voice:PlayerPoolChanged');
RegisterNetEvent('voice:RadioPoolChanged');
RegisterNetEvent('voice:CallPoolChanged');

-- Event Functions
AddEventHandler('voice:CallPoolChanged', function(Pool)
  voice.CallPool = Pool;
end);

AddEventHandler('voice:RadioPoolChanged', function(Pool)
  voice.RadioPool = Pool;
end);

AddEventHandler('voice:PlayerPoolChanged', function(Pool)
  voice.PlayerPool = Pool;
end);

AddEventHandler('voice:PlayerLoaded', function(Data)
  Config = Data;

  RegisterCommand('toggleVoiceRange', function()
    TriggerServerEvent('voice:cmd:toggleVoiceRange');
  end, false);

  RegisterCommand('+toggleRadio', function()
    TriggerServerEvent('voice:cmd:pressedRadio');
  end, false);

  RegisterCommand('-toggleRadio', function()
    TriggerServerEvent('voice:cmd:releasedRadio');
  end, false);

  -- add key assignment for the voice range command
  RegisterKeyMapping('toggleVoiceRange', 'Toggle Voicerange', 'keyboard', Config.KeyMapper.ToggleVoiceRange);
  RegisterKeyMapping('+toggleRadio', 'Toggle Radio', 'keyboard', Config.KeyMapper.ToggleRadio);

  -- set the clients user name
  UserName = Config.UserPrefix .. UserId;

  -- initiate the main thread
  SendNUIMessage({
    action = 'init',
    debug = true,
    channelName = Config.ChannelName,
    channelPassword = Config.ChannelPassword,
    username = UserName
  });
end);

RegisterNUICallback('Connected', function(_, resp)
  loop = true;

  while loop do
    -- trigger main voice function
    OnVoiceTick();
    Citizen.Wait(1000);
  end

  resp('OK');
end);

RegisterNUICallback('Talking', function(data, resp)
  -- TODO: change this to player data
  local ped = PlayerPedId();

  SetPlayerTalkingOverride(PlayerId(), data.state);

  if data.state then
    PlayFacialAnim(ped, 'mic_chatter', 'mp_facial');
  else
    local animName = 'facials@gen_female@variations@normal';

    if IsPedMale(ped) then
      animName = 'facials@gen_male@variations@normal';
    end

    PlayFacialAnim(ped, 'mood_normal_1', animName);
  end

  resp('OK');
end);

RegisterNUICallback('Disconnected', function(_, resp)
  loop = false;

  resp('OK');
end);

-- Functions
function OnVoiceTick()
  -- define player position, ped, etc
  -- used to compare distance, etc
  local PlayerPos = GetEntityCoords(Player);
  local Rotation = GetGameplayCamRot(2).z;

  -- init the PlayerNames table, were all voice clients get stored
  local PlayerNames = {};
  -- define current client pool data as MyPool
  local MyPool = voice.PlayerPool[GetTableIndexBySource(UserId)];

  -- Loop through the PlayerPool
  for _, PoolData in pairs(voice.PlayerPool) do
    -- check if the current player is the current client
    if PoolData.source ~= UserId then
      -- define the client and server id for the current player
      local Target = GetPlayerFromServerId(PoolData.source);

      -- if the data exists and the player isn't muted then proceed
      if PoolData and not PoolData.muted then
        local TargetPed = GetPlayerPed(Target);

        -- check if the player is in my range/stream (what ever) and if he has a ped
        if NetworkIsPlayerActive(Target) and DoesEntityExist(TargetPed) then
          -- define player pos, distance and voice range
          local TargetPos = GetEntityCoords(TargetPed);
          local Distance = #(PlayerPos - TargetPos);
          local TargetVoiceRange = PoolData.range;

          -- check if the player is hearable for the current client,
          -- by comparing my distance to him with his voice range
          if Distance <= TargetVoiceRange then
            local VolumeModifier = 0;

            -- if the distance is greater or equals 5 then modify the volume to be quieter
            if Distance >= 5 then
              VolumeModifier = (Distance * 35 / 10);
            end

            -- if the volume somehow exceeds 0, reset it to 0
            if VolumeModifier > 0 then
              VolumeModifier = 0;
            end

            -- define a table including the distance on x and y from the current client to the current player
            local SubPos = {
              X = TargetPos.x - PlayerPos.x,
              Y = TargetPos.y - PlayerPos.y,
            };

            -- do some math sh*t to define where the audio is coming from, etc
            local x = SubPos.X * math_cos(Rotation) - SubPos.Y * math_sin(Rotation) * 10 / TargetVoiceRange;
            local y = SubPos.X * math_cos(Rotation) + SubPos.Y * math_sin(Rotation) * 10 / TargetVoiceRange;

            -- insert it to the PlayerNames table, which we created before
            table_insert(PlayerNames, {
              name = PoolData.name,
              x = x,
              y = y,
              z = 0,
              distance = Distance,
              voiceRange = TargetVoiceRange,
              volumeModifier = VolumeModifier
            });
          else
            -- if the player isn't anywhere near us, or we aren't able to hear him,
            -- because our distance exceeds his voice range,
            -- then check if the client and the player are connected in a call and in the same call
            if
                (PoolData.callId and PoolData.callId == MyPool.callId) or
                (PoolData.radioId and PoolData.radioId == MyPool.radioId and PoolData.radioActive)
            then
              -- if so then insert him to the PlayerNames table
              table_insert(PlayerNames,
                {
                  name = PoolData.name,
                  x = 10,
                  y = 0,
                  z = 0,
                  distance = 0,
                  voiceRange = 5,
                  volumeModifier = 3
                });
            end
          end
        end
      end
    end
  end

  SendNUIMessage({
    action = 'send',
    data = {
      method = 'setLocalPosition',
      data = {
        x = PlayerPos.x,
        y = PlayerPos.y,
        z = PlayerPos.z
      }
    }
  });

  SendNUIMessage({
    action = 'send',
    data = {
      method = 'updateTargetPositions',
      data = PlayerNames
    }
  });
end

-- Export Data
exports('getVoiceObject', function()
  return voice;
end);

-- Initiate the client
TriggerServerEvent('voice:PlayerConnected');
