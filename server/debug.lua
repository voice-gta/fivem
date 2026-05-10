local convar = GetConvar('voice_debug', 'no');

if convar == '\'yes\'' or convar == 'yes' then
  RegisterCommand('debug', function(s, args)
    local action = args[1];
    local value = args[2];
    local value2 = tonumber(args[3]);

    if action == 'radio' then
      if value == 'join' then
        exports.voice:AddPlayerToRadio(s, value2);
      else
        exports.voice:RemovePlayerToRadio(s, value2);
      end
    elseif action == 'call' then
      if value == 'join' then
        exports.voice:AddPlayerToCall(s, value2);
      else
        exports.voice:RemovePlayerToCall(s, value2);
      end
    end

  end, false);
end
