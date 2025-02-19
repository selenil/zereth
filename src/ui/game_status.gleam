import gleam/int
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element/html

import game_engine
import model

pub fn render(model: model.Model) {
  html.div([attribute.class("game-status")], [
    case model.error {
      Some(error) ->
        html.div([attribute.class("error-message")], [html.text("⚠ " <> error)])
      None -> html.text("")
    },
    html.div([], [
      html.text("Current player: "),
      html.span(
        [
          attribute.class("current-player"),
          attribute.class(case model.game.current_player_color {
            game_engine.Gold -> "gold"
            game_engine.Silver -> "silver"
          }),
        ],
        [
          html.text(case model.game.current_player_color {
            game_engine.Gold -> "Gold"
            game_engine.Silver -> "Silver"
          }),
        ],
      ),
      case model.game.positioning {
        True -> html.text(" | Positioning")
        False ->
          html.text(
            " | Moves remaining: " <> int.to_string(model.game.remaining_moves),
          )
      },
    ]),
  ])
}
