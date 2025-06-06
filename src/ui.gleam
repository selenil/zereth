import events.{type Msg}
import model
import ui/board
import ui/debug
import ui/game_status
import ui/player_controls
import ui/presets

pub fn board(model: model.Model) {
  board.render(model)
}

pub fn game_status(model: model.Model) {
  game_status.render(model)
}

pub fn player_controls(model: model.Model, undo_msg: Msg, pass_turn_msg: Msg) {
  player_controls.render(model, undo_msg, pass_turn_msg)
}

pub fn debug_tooltip(model: model.Model) {
  debug.render_debug_tooltip(model)
}

pub fn debug_panel(model: model.Model) {
  debug.render_debug_panel(model)
}

pub fn preset_buttons(model: model.Model) {
  presets.render_preset_buttons(model)
}

pub fn preset_tooltip(model: model.Model) {
  presets.render_preset_tooltip(model)
}
