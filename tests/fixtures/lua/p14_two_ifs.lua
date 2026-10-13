kind = "quest"
id = "p14"
function handle_event(event, payload)
  if event == "quest_completed" then
    api.set_flag("first", true)
  end
  if event == "quest_completed" then
    api.set_flag("second", true)
  end
end
