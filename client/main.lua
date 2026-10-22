-- Initiate the pool tables
voice = {
  CallPool = {},
  RadioPool = {},
  PlayerPool = {},
};

-- Game Natives
local GetPlayerPed = GetPlayerPed;
local PlayerPedId = PlayerPedId;
local GetEntityCoords = GetEntityCoords;
local GetPlayerServerId = GetPlayerServerId;
local GetPlayerFromServerId = GetPlayerFromServerId;
local GetGameplayCamRot = GetGameplayCamRot;
local AddEventHandler = AddEventHandler;
local RegisterNetEvent = RegisterNetEvent;
local RegisterCommand = RegisterCommand;
local TriggerServerEvent = TriggerServerEvent;
local RegisterKeyMapping = RegisterKeyMapping;
local SendNUIMessage = SendNUIMessage;
local RegisterNUICallback = RegisterNUICallback;
local PlayerId = PlayerId;
local PlayFacialAnim = PlayFacialAnim;
local IsPedMale = IsPedMale;
local SetPlayerTalkingOverride = SetPlayerTalkingOverride;
local NetworkIsPlayerActive = NetworkIsPlayerActive;
local DoesEntityExist = DoesEntityExist;
local CreateThread = CreateThread;
local GetEntityForwardVector = GetEntityForwardVector;

-- Lua Globals
local math_cos = math.cos;
local math_sin = math.sin;
local math_pi = math.pi;
local table_insert = table.insert;
local pairs = pairs;
local tostring = tostring;

-- Variables
local Config = nil;
local UserName = '';
local UserPlayerId = PlayerId();
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
    debug = false,
    channelName = Config.ChannelName,
    channelPassword = Config.ChannelPassword,
    username = tostring(UserName),
    swissChannels = json.encode({ channels = Config.SwissChannels })
  });
end);

RegisterNUICallback('Connected', function(_, resp)
  loop = true;

  CreateThread(function()
    while loop do
      -- Update Values like PlayerPedId
      UpdateValuesTick();
      -- trigger main voice function
      OnVoiceTick();
      Citizen.Wait(500);
    end
  end)

  resp('OK');
end);

RegisterNUICallback('Talking', function(data, resp)
  SetPlayerTalkingOverride(UserPlayerId, data.state);

  if data.state then
    PlayFacialAnim(Player, 'mic_chatter', 'mp_facial');
  else
    local animName = 'facials@gen_female@variations@normal';

    if IsPedMale(Player) then
      animName = 'facials@gen_male@variations@normal';
    end

    PlayFacialAnim(Player, 'mood_normal_1', animName);
  end

  resp('OK');
end);

RegisterNUICallback('Disconnected', function(_, resp)
  loop = false;

  resp('OK');
end);

-- Functions
function UpdateValuesTick()
  if Player ~= PlayerPedId() then
    Player = PlayerPedId();
  end;

  if UserPlayerId ~= PlayerId() then
    UserPlayerId = PlayerId();
  end;

  if UserId ~= GetPlayerServerId(UserId) then
    UserId = GetPlayerServerId(UserId);
  end;
end;

function OnVoiceTick()
  -- define player position, ped, etc
  -- used to compare distance, etc
  local PlayerPos = GetEntityCoords(Player);
  local PlayerForwardVector = GetEntityForwardVector(Player);
  local Rotation = math_pi / 180 * (GetGameplayCamRot(2).z * -1);

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
          if (Distance <= TargetVoiceRange) then
            local VolumeModifier = 1;
            local percent = TargetVoiceRange / 100 * Distance;
            VolumeModifier = VolumeModifier - percent;

            if (TargetVoiceRange == 15.0) then
              VolumeModifier = VolumeModifier * 1.3;
            elseif (TargetVoiceRange == 8.0) then
              VolumeModifier = VolumeModifier * 0.9;
            end

            -- define a table including the distance on x and y from the current client to the current player
            local SubPos = {
              X = TargetPos.x - PlayerPos.x,
              Y = TargetPos.y - PlayerPos.y
            };

            -- do some math sh*t to define where the audio is coming from, etc
            local x = SubPos.X * math_cos(Rotation) - SubPos.Y * math_sin(Rotation) * 10 / TargetVoiceRange;
            local y = SubPos.X * math_cos(Rotation) + SubPos.Y * math_sin(Rotation) * 10 / TargetVoiceRange;

            -- insert it to the PlayerNames table, which we created before
            table_insert(PlayerNames, {
              name = PoolData.name,
              x = x + 0.0,
              y = y + 0.0,
              z = 0.0,
              distance = Distance + 0.0,
              voiceRange = TargetVoiceRange + 0.0,
              volumeModifier = VolumeModifier + 0.0
            });
          else
            -- if the player isn't anywhere near us, or we aren't able to hear him,
            -- because our distance exceeds his voice range,
            -- then check if the client and the player are connected in a call and in the same call
            if
                (PoolData.callId and PoolData.callId == MyPool.callId and PoolData.callActive) or
                (PoolData.radioId and PoolData.radioId == MyPool.radioId and PoolData.radioActive)
            then
              -- if so then insert him to the PlayerNames table
              table_insert(PlayerNames,
                {
                  name = PoolData.name,
                  x = 10.0,
                  y = 0.0,
                  z = 0.0,
                  distance = 0.0,
                  voiceRange = 5.0,
                  volumeModifier = 3.0
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
        PlayerPosX = PlayerPos.x + 0.0,
        PlayerPosY = PlayerPos.y + 0.0,
        PlayerPosZ = PlayerPos.z + 0.0,
        PlayerForwardVectorX = PlayerForwardVector.x + 0.0,
        PlayerForwardVectorY = PlayerForwardVector.y + 0.0,
        PlayerForwardVectorZ = PlayerForwardVector.z + 0.0
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
