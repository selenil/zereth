import gleam/bool

import lustre

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

  html.div([], [
    case model.game.positioning {
      True -> html.text("")
      False -> ui.game_status(model)
    },
    board_view,
    ui.player_controls(model, events.Undo, events.PassTurn),
  ])
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
