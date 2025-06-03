import gleam/bool

import lustre

import lustre/attribute
import lustre/element
import lustre/element/html

import events.{type Msg}
import model
import ui

pub fn init(flags) -> model.Model {
  model.init(flags)
}

pub fn update(model: model.Model, msg: Msg) -> model.Model {
  // Don't process any messages if game is won
  use <- bool.guard(model.game.win, model)
  events.process_msg(model, msg)
}

pub fn view(model: model.Model) -> element.Element(Msg) {
  let board_view = ui.board(model, model.game.positioning)
  let game_status_view = ui.game_status(model)

  html.div([attribute.class("game-container")], [
    game_status_view,
    html.div([attribute.class("main-content")], [
      case model.game.positioning {
        True ->
          html.div([attribute.class("positioning-layout")], [
            ui.preset_buttons(model),
            board_view,
          ])
        False -> board_view
      },
      case model.debug_mode {
        True -> ui.debug_panel(model)
        False -> html.text("")
      },
    ]),
    case model.game.positioning {
      True -> html.text("")
      False -> ui.player_controls(model, events.Undo, events.PassTurn)
    },
    case model.debug_mode {
      True -> ui.debug_tooltip(model)
      False -> html.text("")
    },
    ui.preset_tooltip(model),
  ])
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
