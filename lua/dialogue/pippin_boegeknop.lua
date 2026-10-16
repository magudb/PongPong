kind = "dialogue"
id = "pippin_boegeknop"
function get_dialogue(context)
  if context.quest_active_lost_cat then
    return {
      speaker = "pippin_boegeknop", speaker_name_key = "NPC_PIPPIN_BOEGEKNOP",
      lines = { { id = "cat_remind", text_key = "DLG_PIPPIN_REMIND", voice_key = "voice/pippin_boegeknop/cat_remind" } },
      choices = { { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
    }
  end
  if not context.quest_done_lost_cat then
    return {
      speaker = "pippin_boegeknop", speaker_name_key = "NPC_PIPPIN_BOEGEKNOP",
      lines = { { id = "cat_offer", text_key = "DLG_PIPPIN_CAT", voice_key = "voice/pippin_boegeknop/cat_offer" } },
      choices = { { id = "find_cat", text_key = "DLG_CHOICE_HELP_FIND_CAT", action = "quest_accept", quest_id = "lost_cat" }, { id = "flea", text_key = "DLG_CHOICE_FLEA", action = "open_shop", shop_id = "flea_market" }, { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
    }
  end
  return {
    speaker = "pippin_boegeknop", speaker_name_key = "NPC_PIPPIN_BOEGEKNOP",
    lines = { { id = "hello", text_key = "DLG_PIPPIN_HELLO", voice_key = "voice/pippin_boegeknop/hello" } },
    choices = { { id = "flea", text_key = "DLG_CHOICE_FLEA", action = "open_shop", shop_id = "flea_market" }, { id = "bye", text_key = "DLG_CHOICE_GOODBYE", action = "close" } },
  }
end
