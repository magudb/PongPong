kind = "quest"
id = "p17"
function handle_event(event, payload)
  if api.has_flag("bonus") then
    api.add_gold(50)
  else
    api.add_gold(5)
  end
end
