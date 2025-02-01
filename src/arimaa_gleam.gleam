import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

import game_engine

pub type Model {
  Model(
    game: game_engine.Game,
    opting_piece: Option(game_engine.Piece),
    enemy_opting_piece: Option(game_engine.Piece),
    error: Option(String),
  )
}

fn init(_flags) -> Model {
  Model(
    game: game_engine.new_debug_game(),
    opting_piece: None,
    enemy_opting_piece: None,
    error: None,
  )
}

pub opaque type Msg {
  Opting(piece: game_engine.Piece)
  EnemyOpting(piece: game_engine.Piece)
  PlacePiece(target_square: game_engine.Square)
  MovePiece(target_square: game_engine.Square)
  RepositionPiece(target_square: game_engine.Square)
}

pub fn update(model: Model, msg: Msg) -> Model {
  io.println("Updating model with msg: ")
  // Don't process any messages if game is won
  case model.game.win {
    True -> model
    False -> {
      case msg {
        Opting(piece) -> {
          Model(..model, opting_piece: Some(piece), error: None)
        }
        EnemyOpting(piece) -> {
          Model(..model, enemy_opting_piece: Some(piece), error: None)
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
      }
    }
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
            fn(piece) { piece_view(piece) },
          ),
        ),
        html.div(
          [attribute.class("available-pieces silver")],
          list.map(
            list.filter(available_pieces, fn(piece) {
              piece.color == game_engine.Silver
            }),
            fn(piece) { piece_view(piece) },
          ),
        ),
        board_view,
      ])
    }
    False -> board_view
  }
}

fn render_square(
  square: game_engine.Square,
  model: Model,
) -> element.Element(Msg) {
  let piece_element = case square.piece {
    Some(piece) -> {
      let asset_name = game_engine.get_piece_asset_name(piece)

      html.div([attribute.class("piece")], [
        html.img([attribute.src(asset_name), attribute.alt("Piece")]),
      ])
    }
    None -> html.div([], [])
  }

  let piece_event = case square.piece, model.game.current_player_color {
    Some(piece), color if piece.color == color -> event.on_click(Opting(piece))

    Some(piece), _ -> event.on_click(EnemyOpting(piece))
    None, _ ->
      event.on_click(case model.game.positioning {
        True -> PlacePiece(square)
        False ->
          case model.opting_piece, model.enemy_opting_piece {
            Some(_), Some(_) -> RepositionPiece(square)
            _, _ -> MovePiece(square)
          }
      })
  }

  let square_id = case square.piece {
    Some(piece) -> build_piece_id(piece)
    None -> build_square_id(square)
  }

  html.div(
    [
      attribute.id(square_id),
      attribute.class("square"),
      attribute.class(case
        list.contains(game_engine.trap_squares, #(square.x, square.y))
      {
        True -> "trap"
        False -> ""
      }),
      piece_event,
    ],
    [piece_element],
  )
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn piece_view(piece: game_engine.Piece) {
  html.button([event.on_click(Opting(piece))], [
    html.img([
      attribute.src(game_engine.get_piece_asset_name(piece)),
      attribute.alt("Piece"),
    ]),
  ])
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
  delta_coords: game_engine.Coords,
) -> Model {
  case game_engine.move_piece(model.game, piece, delta_coords) {
    Ok(game) -> {
      let game =
        game
        |> game_engine.perform_captures()
        |> game_engine.pass_turn()
        |> game_engine.check_win()

      Model(
        game: game,
        error: None,
        opting_piece: None,
        enemy_opting_piece: None,
      )
    }
    Error(error) ->
      Model(
        ..model,
        error: Some(error),
        opting_piece: None,
        enemy_opting_piece: None,
      )
  }
}

fn reposition_piece(
  model: Model,
  strong_piece: game_engine.Piece,
  weak_piece: game_engine.Piece,
  target_square: game_engine.Coords,
) -> Model {
  case
    game_engine.reposition_piece(
      model.game,
      strong_piece,
      weak_piece,
      target_square,
    )
  {
    Ok(game) -> {
      let game =
        game
        |> game_engine.perform_captures()
        |> game_engine.pass_turn()
        |> game_engine.check_win()

      Model(
        game: game,
        error: None,
        opting_piece: None,
        enemy_opting_piece: None,
      )
    }
    Error(error) ->
      Model(
        ..model,
        error: Some(error),
        opting_piece: None,
        enemy_opting_piece: None,
      )
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
