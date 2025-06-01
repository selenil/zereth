import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element/html
import lustre/event

import events.{
  EnemyOpting, MovePiece, Nothing, Opting, PlacePiece, RepositionPiece,
  SquareHover, SquareOpting, SquareUnhover,
}
import game_engine
import model
import ui/piece.{render as render_piece}

pub fn render(model: model.Model, positioning: Bool) {
  case positioning {
    True -> render_positioning_board(model)
    False -> render_board(model)
  }
}

fn render_positioning_board(model: model.Model) {
  let available_pieces =
    game_engine.get_aviable_pieces_to_place(model.game.board)

  html.div([], [
    html.div(
      [attribute.class("available-pieces silver")],
      list.map(
        list.filter(available_pieces, fn(piece) {
          piece.color == game_engine.Silver
        }),
        fn(piece) {
          html.div(
            [
              event.on_click(Opting(piece)),
              event.on_mouse_down(Opting(piece)),
              on_dragstart(Nothing),
            ],
            [render_piece(piece, "", False)],
          )
        },
      ),
    ),
    render_board(model),
    html.div(
      [attribute.class("available-pieces gold")],
      list.map(
        list.filter(available_pieces, fn(piece) {
          piece.color == game_engine.Gold
        }),
        fn(piece) {
          html.div(
            [
              event.on_click(Opting(piece)),
              event.on_mouse_down(Opting(piece)),
              on_dragstart(Nothing),
            ],
            [render_piece(piece, "", False)],
          )
        },
      ),
    ),
  ])
}

fn render_board(model: model.Model) {
  html.div(
    [
      attribute.class("board"),
      attribute.class(case model.game.win {
        True -> "game-over"
        False -> ""
      }),
    ],
    case model.game.win {
      True -> [
        html.div([attribute.class("winner-overlay")], [
          html.h2([attribute.class("winner-message")], [
            html.text("Game Over!"),
            html.br([]),
            html.text(
              case model.game.current_player_color {
                game_engine.Gold -> "Silver"
                game_engine.Silver -> "Gold"
              }
              <> " wins!",
            ),
          ]),
        ]),
        ..list.map(model.game.board, fn(square) {
          render_square(
            square: square,
            current_player_color: model.game.current_player_color,
            positioning: model.game.positioning,
            opting_square: model.opting_square,
            opting_piece: model.opting_piece,
            enemy_opting_piece: model.enemy_opting_piece,
            valid_coords: model.valid_coords,
            debug_mode: model.debug_mode,
            debug_opting_piece: model.debug_opting_piece,
          )
        })
      ]
      False ->
        list.map(model.game.board, fn(square) {
          render_square(
            square: square,
            current_player_color: model.game.current_player_color,
            positioning: model.game.positioning,
            opting_square: model.opting_square,
            opting_piece: model.opting_piece,
            enemy_opting_piece: model.enemy_opting_piece,
            valid_coords: model.valid_coords,
            debug_mode: model.debug_mode,
            debug_opting_piece: model.debug_opting_piece,
          )
        })
    },
  )
}

fn render_square(
  square square: game_engine.Square,
  current_player_color current_player_color: game_engine.PieceColor,
  positioning positioning: Bool,
  opting_square opting_square: Option(game_engine.Square),
  opting_piece opting_piece: Option(game_engine.Piece),
  debug_opting_piece debug_opting_piece: Option(game_engine.Piece),
  enemy_opting_piece enemy_opting_piece: Option(game_engine.Piece),
  valid_coords valid_coords: Option(
    List(#(game_engine.Coords, game_engine.ValidCoordsKind)),
  ),
  debug_mode debug_mode: Bool,
) {
  let piece_additional_classes = case
    square.piece,
    opting_piece,
    enemy_opting_piece
  {
    Some(p1), Some(p2), _ if p1 == p2 -> "opting"
    Some(p1), _, Some(p2) if p1 == p2 -> "enemy-opting"
    _, _, _ -> ""
  }

  let is_ghost = opting_square == Some(square)
  let piece_element = case square.piece, opting_piece, is_ghost {
    Some(piece), _, False -> [
      render_piece(piece, piece_additional_classes, is_ghost),
    ]

    None, Some(opt_piece), True -> [
      render_piece(opt_piece, piece_additional_classes, is_ghost),
    ]

    _, _, _ -> []
  }

  let piece_events = case positioning {
    True -> []
    False -> piece_events(square, current_player_color)
  }

  let square_id = case square.piece {
    Some(piece) -> build_piece_id(piece)
    None -> build_square_id(square)
  }

  let valid_coords_class = case valid_coords {
    Some(valid_coords) ->
      case
        list.find(valid_coords, fn(tuple) {
          let #(pos, _kind) = tuple
          pos.0 == square.x && pos.1 == square.y
        })
      {
        Ok(coords) -> {
          let #(_, kind) = coords
          case kind {
            game_engine.GoodToGo -> attribute.class("valid good-to-go")
            game_engine.Danger -> attribute.class("valid danger")
          }
        }
        Error(_) -> attribute.none()
      }
    None -> attribute.none()
  }

  let interaction_message = case
    positioning || { debug_mode && debug_opting_piece != None }
  {
    True -> PlacePiece(square)
    False ->
      case opting_piece, enemy_opting_piece {
        Some(_), Some(_) -> RepositionPiece(square)
        _, _ -> MovePiece(square)
      }
  }

  let debug_events = case debug_mode {
    True -> [
      {
        use evt <- event.on("mouseenter")
        Ok(SquareHover(square, evt))
      },
      event.on_mouse_leave(SquareUnhover),
    ]
    False -> []
  }

  html.div(
    [
      attribute.id(square_id),
      attribute.class("square"),
      case list.contains(game_engine.trap_squares, #(square.x, square.y)) {
        True -> attribute.class("trap")
        False -> attribute.none()
      },
      valid_coords_class,
      event.on_mouse_over(SquareOpting(square)),
      event.on_click(interaction_message),
      on_dragover(SquareOpting(square)),
      on_drop(interaction_message),
      ..list.append(piece_events, debug_events)
    ],
    piece_element,
  )
}

fn piece_events(
  square: game_engine.Square,
  current_player_color: game_engine.PieceColor,
) {
  case square.piece, current_player_color {
    Some(piece), color if piece.color == color -> [
      event.on_click(Opting(piece)),
      on_dragstart(Opting(piece)),
    ]

    Some(piece), _ -> [event.on_click(EnemyOpting(piece))]

    _, _ -> []
  }
}

fn build_piece_id(piece: game_engine.Piece) -> String {
  "piece-"
  <> game_engine.piece_color_to_string(piece.color)
  <> "-"
  <> game_engine.piece_kind_to_string(piece.kind)
  <> "-"
  <> int.to_string(piece.id)
}

fn build_square_id(square: game_engine.Square) -> String {
  "square-" <> int.to_string(square.x) <> "-" <> int.to_string(square.y)
}

fn on_dragstart(msg) {
  use evt <- event.on("dragstart")
  hide_piece_image(evt)
  Ok(msg)
}

fn on_dragover(msg) {
  use evt <- event.on("dragover")
  event.prevent_default(evt)
  Ok(msg)
}

fn on_drop(msg) {
  use _ <- event.on("drop")
  Ok(msg)
}

@external(javascript, "../ffi/browser_ffi.mjs", "hideDragImage")
fn hide_piece_image(_event: Dynamic) -> Nil {
  panic as "Not valid outside browser"
}
