import gleam/bool
import gleam/dynamic
import gleam/list

import lustre

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import events.{type Msg}
import game_engine
import model
import ui
import ui/piece

pub fn init(flags) -> model.Model {
  model.init(flags)
}

pub fn update(model: model.Model, msg: Msg) -> model.Model {
  // Don't process any messages if game is won
  use <- bool.guard(model.game.win, model)
  events.process_msg(model, msg)
}

pub fn view(model: model.Model) -> element.Element(Msg) {
  let board_view = ui.board(model)
  let game_status_view = ui.game_status(model)

  html.div([attribute.class("game-container")], [
    game_status_view,
    html.div([attribute.class("main-content")], [
      html.div(
        [
          attribute.class(
            "game-area "
            <> case model.game.positioning {
              True -> "positioning"
              False -> "playing"
            },
          ),
        ],
        [
          case model.game.positioning {
            True ->
              html.div([attribute.class("available-pieces-container")], [
                ui.preset_buttons(model),
                render_available_pieces(model, game_engine.Silver),
                render_available_pieces(model, game_engine.Gold),
              ])

            False -> html.text("")
          },
          case model.game.positioning {
            True -> {
              html.div([], [
                board_view,
                ui.player_controls(model, events.Undo, events.PassTurn),
              ])
            }
            False -> {
              html.div([], [
                board_view,
                ui.player_controls(model, events.Undo, events.PassTurn),
              ])
            }
          },
        ],
      ),
      case model.debug_mode {
        True -> ui.debug_panel(model)
        False -> html.text("")
      },
    ]),
    case model.debug_mode {
      True -> ui.debug_tooltip(model)
      False -> html.text("")
    },
    ui.preset_tooltip(model),
  ])
}

fn render_available_pieces(model: model.Model, color: game_engine.PieceColor) {
  let available_pieces =
    game_engine.get_aviable_pieces_to_place(model.game.board)
  let pieces_for_color =
    list.filter(available_pieces, fn(piece) { piece.color == color })

  let color_class = case color {
    game_engine.Gold -> "gold"
    game_engine.Silver -> "silver"
  }

  html.div(
    [attribute.class("available-pieces " <> color_class)],
    list.map(pieces_for_color, fn(piece) {
      html.div(
        [
          event.on_click(events.Opting(piece)),
          event.on_mouse_down(events.Opting(piece)),
          on_dragstart(events.Nothing),
        ],
        [piece.render(piece, "")],
      )
    }),
  )
}

fn on_dragstart(msg) {
  use evt <- event.on("dragstart")
  hide_piece_image(evt)
  Ok(msg)
}

@external(javascript, "./ffi/browser_ffi.mjs", "hideDragImage")
fn hide_piece_image(_event: dynamic.Dynamic) -> Nil {
  panic as "Not valid outside browser"
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
