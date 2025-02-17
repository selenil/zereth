import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

import game_engine
import logger
import model

pub type Msg {
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

pub fn process_msg(model: model.Model, msg: Msg) {
  case msg {
    Undo -> set_game(model, game_engine.undo_last_move(model.game))
    PassTurn -> model.Model(..model, game: game_engine.pass_turn(model.game))

    Opting(piece) -> {
      // deselect if the user touches the same piece twice
      let opting_piece = case model.opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      // we cannot opt for a piece that is frozen
      use <- bool.guard(
        game_engine.is_piece_frozen(
          model.game.board,
          piece,
          game_engine.retrieve_square_from_piece(model.game.board, piece),
        ),
        model,
      )

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

      model.Model(..model, opting_piece:, valid_coords:, error: None)
    }

    EnemyOpting(piece) -> {
      // deselect if the user touches the same piece twice
      let enemy_opting_piece = case model.enemy_opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      model.Model(..model, enemy_opting_piece:, error: None)
    }

    SquareOpting(square) -> {
      case model.valid_coords {
        Some(coords) -> {
          case list.contains(coords, #(square.x, square.y)) {
            True -> {
              model.Model(..model, opting_square: Some(square))
            }
            _ -> model.Model(..model, opting_square: None)
          }
        }
        None -> model.Model(..model, opting_square: None)
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

fn place_piece(
  model: model.Model,
  coords: game_engine.Coords,
  piece: game_engine.Piece,
  dest_coords: Option(game_engine.Coords),
) -> model.Model {
  case game_engine.place_piece(model.game, coords, piece, dest_coords) {
    Ok(game) ->
      model.Model(..model, game: game, error: None, opting_piece: None)
    Error(error) -> model.Model(..model, error: Some(error), opting_piece: None)
  }
}

fn move_piece(
  model: model.Model,
  piece: game_engine.Piece,
  target_coords: game_engine.Coords,
) -> model.Model {
  case game_engine.move_piece(model.game, piece, target_coords) {
    Ok(game) -> set_game(model, game)
    Error(error) -> {
      logger.print_move_error(error, piece, target_coords)
      set_error(model, error)
    }
  }
}

fn reposition_piece(
  model: model.Model,
  strong_piece: game_engine.Piece,
  weak_piece: game_engine.Piece,
  target_coords: game_engine.Coords,
) -> model.Model {
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

fn set_game(_model: model.Model, game: game_engine.Game) -> model.Model {
  model.Model(
    game:,
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
  )
}

fn set_error(model: model.Model, error: String) -> model.Model {
  model.Model(
    ..model,
    error: Some(error),
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    opting_square: None,
  )
}
