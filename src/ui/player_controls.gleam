import gleam/list
import lustre/attribute
import lustre/element/html
import lustre/event

import events.{type Msg}
import game_engine
import model

pub fn render(model: model.Model, undo_msg: Msg, pass_turn_msg: Msg) {
  html.div([attribute.class("player-controls")], [
    html.button(
      [
        attribute.class("undo-button"),
        attribute.disabled(!could_undo(model.game)),
        event.on_click(undo_msg),
      ],
      [html.text("Undo")],
    ),
    html.button(
      [
        attribute.class("pass-turn-button"),
        attribute.disabled(model.game.remaining_moves != 0),
        event.on_click(pass_turn_msg),
      ],
      [html.text("Pass turn")],
    ),
  ])
}

fn could_undo(game: game_engine.Game) -> Bool {
  list.length(game.history) > 0
  && game.positioning == False
  && game.remaining_moves != 4
}
