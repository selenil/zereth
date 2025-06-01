import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import events.{
  type Msg, DebugClearBoard, DebugResetBoard, SquareHover, SquareUnhover,
}
import game_engine
import model

/// Renders a debug tooltip when hovering over a square
pub fn render_debug_tooltip(model: model.Model) -> Element(Msg) {
  case model.debug_hovered_square, model.debug_mouse_position {
    Some(square), Some(mouse_pos) -> {
      let tooltip_content = [
        html.div([attribute.class("tooltip-line")], [
          html.strong([], [html.text("Coordinates: ")]),
          html.text(
            "("
            <> int.to_string(square.x)
            <> ", "
            <> int.to_string(square.y)
            <> ")",
          ),
        ]),
        case square.piece {
          Some(piece) ->
            html.div([attribute.class("tooltip-line")], [
              html.strong([], [html.text("Piece: ")]),
              html.text(
                game_engine.piece_color_to_string(piece.color)
                <> " "
                <> game_engine.piece_kind_to_string(piece.kind)
                <> " #"
                <> int.to_string(piece.id),
              ),
            ])
          None ->
            html.div([attribute.class("tooltip-line")], [
              html.text("Empty square"),
            ])
        },
        case list.contains(game_engine.trap_squares, #(square.x, square.y)) {
          True ->
            html.div([attribute.class("tooltip-line trap-info")], [
              html.text("⚠️ Trap square"),
            ])
          False -> html.text("")
        },
      ]

      html.div(
        [
          attribute.class("debug-tooltip"),
          attribute.style([
            #("position", "fixed"),
            #("left", int.to_string(mouse_pos.x + 10) <> "px"),
            #("top", int.to_string(mouse_pos.y - 10) <> "px"),
            #("z-index", "1000"),
            #("background", "rgba(0, 0, 0, 0.9)"),
            #("color", "white"),
            #("padding", "8px"),
            #("border-radius", "4px"),
            #("font-size", "12px"),
            #("pointer-events", "none"),
          ]),
        ],
        tooltip_content,
      )
    }
    _, _ -> html.text("")
  }
}

/// Renders the debug control panel
pub fn render_debug_panel(model: model.Model) -> Element(Msg) {
  html.div([attribute.class("debug-panel")], [
    html.h3([], [html.text("Debug Mode")]),
    html.div([attribute.class("debug-section")], [
      html.h4([], [html.text("Board Controls")]),
      html.button(
        [attribute.class("debug-button"), event.on_click(DebugResetBoard)],
        [html.text("Reset to Debug Board")],
      ),
      html.button(
        [attribute.class("debug-button"), event.on_click(DebugClearBoard)],
        [html.text("Clear Board")],
      ),
    ]),
    html.div([attribute.class("debug-section")], [
      html.h4([], [html.text("Game State")]),
      html.div([attribute.class("debug-info")], [
        html.div([], [
          html.strong([], [html.text("Current Player: ")]),
          html.text(game_engine.piece_color_to_string(
            model.game.current_player_color,
          )),
        ]),
        html.div([], [
          html.strong([], [html.text("Remaining Moves: ")]),
          html.text(int.to_string(model.game.remaining_moves)),
        ]),
        html.div([], [
          html.strong([], [html.text("Positioning Phase: ")]),
          html.text(case model.game.positioning {
            True -> "Yes"
            False -> "No"
          }),
        ]),
        html.div([], [
          html.strong([], [html.text("Game Won: ")]),
          html.text(case model.game.win {
            True -> "Yes"
            False -> "No"
          }),
        ]),
      ]),
    ]),
    html.div([attribute.class("debug-section")], [
      html.h4([], [html.text("Quick Piece Placement")]),
      render_piece_palette(),
    ]),
    html.div([attribute.class("debug-section")], [
      html.h4([], [html.text("Move History")]),
      render_move_history(model.game.history),
    ]),
  ])
}

/// Renders a palette of pieces for quick placement
fn render_piece_palette() -> Element(Msg) {
  let piece_kinds = [
    game_engine.Elephant,
    game_engine.Camel,
    game_engine.Horse,
    game_engine.Dog,
    game_engine.Cat,
    game_engine.Rabbit,
  ]

  let colors = [game_engine.Gold, game_engine.Silver]

  html.div([attribute.class("piece-palette")], [
    html.div([attribute.class("palette-note")], [
      html.text("Click a piece, then click a square to place it"),
    ]),
    ..list.flat_map(colors, fn(color) {
      [
        html.div([attribute.class("palette-color-label")], [
          html.text(string.uppercase(game_engine.piece_color_to_string(color))),
        ]),
        html.div(
          [attribute.class("palette-row")],
          list.map(piece_kinds, fn(kind) {
            let piece =
              game_engine.Piece(kind, color, game_engine.piece_strength(kind))
            html.button(
              [
                attribute.class("palette-piece"),
                attribute.title(game_engine.piece_kind_to_string(kind)),
                event.on_click(events.DebugPlacementOpting(piece)),
              ],
              [piece_symbol(piece)],
            )
          }),
        ),
      ]
    })
  ])
}

fn render_move_history(history: List(game_engine.Delta)) -> Element(Msg) {
  case list.length(history) {
    0 ->
      html.div([attribute.class("history-empty")], [html.text("No moves yet")])
    _ -> {
      let recent_moves = list.take(history, 10)
      // Show last 10 moves
      html.div(
        [attribute.class("move-history")],
        list.map(recent_moves, render_move),
      )
    }
  }
}

fn render_move(delta: game_engine.Delta) -> Element(Msg) {
  let move_text = case delta {
    game_engine.Move(source, target) ->
      "Move: " <> coords_to_string(source) <> " → " <> coords_to_string(target)

    game_engine.Reposition(strong_source, weak_source, target, reposition_type) ->
      case reposition_type {
        game_engine.Pull -> "Pull: "
        game_engine.Push -> "Push: "
      }
      <> coords_to_string(strong_source)
      <> " + "
      <> coords_to_string(weak_source)
      <> " → "
      <> coords_to_string(target)

    game_engine.Capture(piece, trap_coords) ->
      "Capture: "
      <> game_engine.piece_color_to_string(piece.color)
      <> " "
      <> game_engine.piece_kind_to_string(piece.kind)
      <> " at "
      <> coords_to_string(trap_coords)
  }

  html.div([attribute.class("history-move")], [html.text(move_text)])
}

fn piece_symbol(piece: game_engine.Piece) {
  let piece_name =
    game_engine.piece_color_to_string(piece.color)
    <> "_"
    <> game_engine.piece_kind_to_string(piece.kind)
  html.img([
    attribute.src("assets/pieces/" <> piece_name <> ".png"),
    attribute.style([#("width", "25px"), #("height", "25px")]),
    attribute.alt(piece_name),
  ])
}

fn coords_to_string(coords: game_engine.Coords) -> String {
  let #(x, y) = coords
  "(" <> int.to_string(x) <> "," <> int.to_string(y) <> ")"
}

pub fn add_debug_hover_events(
  square: game_engine.Square,
) -> List(attribute.Attribute(Msg)) {
  [
    {
      use evt <- event.on("mouseenter")
      Ok(SquareHover(square, evt))
    },
    event.on_mouse_leave(SquareUnhover),
  ]
}
