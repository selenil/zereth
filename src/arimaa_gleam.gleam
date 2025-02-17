import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import game_engine
import logger

pub type Model {
  Model(
    game: game_engine.Game,
    opting_piece: Option(game_engine.Piece),
    enemy_opting_piece: Option(game_engine.Piece),
    valid_coords: Option(List(game_engine.Coords)),
    error: Option(String),
    opting_square: Option(game_engine.Square),
  )
}

fn init(_flags) -> Model {
  Model(
    game: game_engine.new_debug_game(),
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
  )
}

pub opaque type Msg {
  Opting(piece: game_engine.Piece)
  EnemyOpting(piece: game_engine.Piece)
  SquareOpting(square: game_engine.Square)
  PlacePiece(target_square: game_engine.Square)
  MovePiece(target_square: game_engine.Square)
  RepositionPiece(target_square: game_engine.Square)
  Undo
  PassTurn
  Nothing
}

pub fn update(model: Model, msg: Msg) -> Model {
  // Don't process any messages if game is won
  use <- bool.guard(model.game.win, model)

  case msg {
    Undo -> set_game(model, game_engine.undo_last_move(model.game))
    PassTurn -> Model(..model, game: game_engine.pass_turn(model.game))

    Opting(piece) -> {
      // deselect if the user touches the same piece twice
      let opting_piece = case model.opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      let valid_coords = case opting_piece {
        Some(p) -> {
          let source_square =
            game_engine.retrieve_square_from_piece(model.game.board, p)

          Some(game_engine.valid_coords_for_piece(
            model.game.board,
            model.game.remaining_moves,
            #(source_square.x, source_square.y),
            p,
          ))
        }
        _ -> None
      }

      Model(..model, opting_piece:, valid_coords:, error: None)
    }

    EnemyOpting(piece) -> {
      // deselect if the user touches the same piece twice
      let enemy_opting_piece = case model.enemy_opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      Model(..model, enemy_opting_piece:, error: None)
    }

    SquareOpting(square) -> {
      case model.valid_coords {
        Some(coords) -> {
          case list.contains(coords, #(square.x, square.y)) {
            True -> {
              Model(..model, opting_square: Some(square))
            }
            _ -> Model(..model, opting_square: None)
          }
        }
        None -> Model(..model, opting_square: None)
      }
    }

    PlacePiece(target_square) -> {
      case model.opting_piece {
        Some(piece) -> {
          case
            list.find(model.game.board, fn(square) {
              square.piece == Some(piece)
            })
          {
            Ok(dest_square) ->
              place_piece(
                model,
                #(target_square.x, target_square.y),
                piece,
                Some(#(dest_square.x, dest_square.y)),
              )
            Error(_) ->
              place_piece(
                model,
                #(target_square.x, target_square.y),
                piece,
                None,
              )
          }
        }
        None -> model
      }
    }

    MovePiece(target_square) ->
      case model.opting_piece {
        Some(piece) ->
          move_piece(model, piece, #(target_square.x, target_square.y))

        None -> model
      }

    RepositionPiece(target_square) ->
      case model.opting_piece, model.enemy_opting_piece {
        Some(strong_piece), Some(weak_piece) ->
          reposition_piece(model, strong_piece, weak_piece, #(
            target_square.x,
            target_square.y,
          ))
        _, _ -> model
      }
    Nothing -> model
  }
}

pub fn view(model: Model) -> element.Element(Msg) {
  let board_view =
    html.div([], [
      html.div([attribute.class("game-status")], [
        case model.error {
          Some(error) ->
            html.div([attribute.class("error-message")], [
              html.text("⚠ " <> error),
            ])
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
          html.text(
            " | Moves remaining: " <> int.to_string(model.game.remaining_moves),
          ),
        ]),
      ]),
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
              render_square(square, model)
            })
          ]
          False ->
            list.map(model.game.board, fn(square) {
              render_square(square, model)
            })
        },
      ),
    ])

  case model.game.positioning {
    True -> {
      let available_pieces =
        game_engine.get_aviable_pieces_to_place(model.game.board)

      html.div([], [
        html.h2([attribute.class("phase-title")], [
          html.text("Positioning Phase"),
          html.br([]),
          html.span([attribute.style([#("font-size", "1rem")])], [
            html.text("Place your pieces on the board"),
          ]),
        ]),
        html.div(
          [attribute.class("available-pieces gold")],
          list.map(
            list.filter(available_pieces, fn(piece) {
              piece.color == game_engine.Gold
            }),
            fn(piece) { render_piece(piece) },
          ),
        ),
        html.div(
          [attribute.class("available-pieces silver")],
          list.map(
            list.filter(available_pieces, fn(piece) {
              piece.color == game_engine.Silver
            }),
            fn(piece) { render_piece(piece) },
          ),
        ),
        board_view,
      ])
    }
    False ->
      html.div([], [
        board_view,
        html.div([attribute.class("player-controls")], [
          html.button(
            [
              attribute.class("undo-button"),
              attribute.disabled(!could_undo(model.game)),
              event.on_click(Undo),
            ],
            [html.text("Undo")],
          ),
          html.button(
            [
              attribute.class("pass-turn-button"),
              attribute.disabled(model.game.remaining_moves != 0),
              event.on_click(PassTurn),
            ],
            [html.text("Pass turn")],
          ),
        ]),
      ])
  }
}

fn render_square(
  square: game_engine.Square,
  model: Model,
) -> element.Element(Msg) {
  let piece_element = case
    model.opting_square,
    model.opting_piece,
    square.piece
  {
    Some(opting_square), Some(opting_piece), None if opting_square == square -> {
      let asset_name = get_piece_asset_name(opting_piece)
      html.div([attribute.class("piece"), attribute.class("ghost")], [
        html.img([attribute.src(asset_name), attribute.alt("Ghost Piece")]),
      ])
    }

    _, _, Some(piece) -> {
      let asset_name = get_piece_asset_name(piece)
      html.div(
        [
          attribute.class("piece"),
          attribute.attribute("draggable", "true"),
          case model.opting_piece, model.enemy_opting_piece {
            Some(p), _ if p == piece -> attribute.class("opting")
            _, Some(p) if p == piece -> attribute.class("enemy-opting")
            _, _ -> attribute.none()
          },
        ],
        [html.img([attribute.src(asset_name), attribute.alt("Piece")])],
      )
    }

    _, _, _ -> html.div([], [])
  }

  let piece_events = case square.piece, model.game.current_player_color {
    Some(piece), color if piece.color == color -> [
      event.on_click(Opting(piece)),
      event.on_mouse_down(Opting(piece)),
      on_dragstart(Nothing),
    ]

    Some(piece), _ -> [event.on_click(EnemyOpting(piece))]

    None, _ -> {
      let message = case model.game.positioning {
        True -> PlacePiece(square)
        False ->
          case model.opting_piece, model.enemy_opting_piece {
            Some(_), Some(_) -> RepositionPiece(square)
            _, _ -> MovePiece(square)
          }
      }

      [event.on_click(message), on_drop(message)]
    }
  }

  let square_id = case square.piece {
    Some(piece) -> build_piece_id(piece)
    None -> build_square_id(square)
  }

  let valid_coords_class = case model.valid_coords {
    Some(coords) ->
      case list.any(coords, fn(c) { c.0 == square.x && c.1 == square.y }) {
        True -> attribute.class("valid")
        False -> attribute.none()
      }
    None -> attribute.none()
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
      on_dragover(SquareOpting(square)),
      ..piece_events
    ],
    [piece_element],
  )
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn render_piece(piece: game_engine.Piece) {
  let piece_alt =
    game_engine.piece_color_to_string(piece.color)
    <> "_"
    <> game_engine.piece_kind_to_string(piece.kind)

  html.div(
    [
      attribute.class("piece"),
      attribute.attribute("draggable", "true"),
      event.on_click(Opting(piece)),
    ],
    [
      html.img([
        attribute.src(get_piece_asset_name(piece)),
        attribute.alt(piece_alt),
      ]),
    ],
  )
}

fn place_piece(
  model: Model,
  coords: game_engine.Coords,
  piece: game_engine.Piece,
  dest_coords: Option(game_engine.Coords),
) -> Model {
  case game_engine.place_piece(model.game, coords, piece, dest_coords) {
    Ok(game) -> Model(..model, game: game, error: None, opting_piece: None)
    Error(error) -> Model(..model, error: Some(error), opting_piece: None)
  }
}

fn move_piece(
  model: Model,
  piece: game_engine.Piece,
  target_coords: game_engine.Coords,
) -> Model {
  case game_engine.move_piece(model.game, piece, target_coords) {
    Ok(game) -> set_game(model, game)
    Error(error) -> {
      logger.print_move_error(error, piece, target_coords)
      set_error(model, error)
    }
  }
}

fn reposition_piece(
  model: Model,
  strong_piece: game_engine.Piece,
  weak_piece: game_engine.Piece,
  target_coords: game_engine.Coords,
) -> Model {
  case
    game_engine.reposition_piece(
      model.game,
      strong_piece,
      weak_piece,
      target_coords,
    )
  {
    Ok(game) -> set_game(model, game)

    Error(error) -> {
      logger.print_reposition_error(
        error,
        strong_piece,
        weak_piece,
        target_coords,
      )
      set_error(model, error)
    }
  }
}

fn set_game(_model: Model, game: game_engine.Game) -> Model {
  Model(
    game:,
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
  )
}

fn set_error(model: Model, error: String) -> Model {
  Model(
    ..model,
    error: Some(error),
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    opting_square: None,
  )
}

fn could_undo(game: game_engine.Game) -> Bool {
  list.length(game.history) > 0
  && game.positioning == False
  && game.remaining_moves != 4
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

fn get_piece_asset_name(piece: game_engine.Piece) {
  let color = game_engine.piece_color_to_string(piece.color)

  let kind = game_engine.piece_kind_to_string(piece.kind)

  "assets/pieces/" <> color <> "_" <> kind <> ".png"
}

fn on_dragstart(msg) {
  use evt <- event.on("dragstart")
  hide_piece_image(evt)
  Ok(msg)
}

fn on_dragover(msg) {
  use evt <- event.on("dragover")
  prevent_default(evt)
  Ok(msg)
}

fn on_drop(msg) {
  use _ <- event.on("drop")
  Ok(msg)
}

@external(javascript, "./browser_ffi.mjs", "preventDefault")
fn prevent_default(_event: Dynamic) -> Nil {
  panic as "Not valid outside browser"
}

@external(javascript, "./browser_ffi.mjs", "hideDragImage")
fn hide_piece_image(_event: Dynamic) -> Nil {
  panic as "Not valid outside browser"
}
