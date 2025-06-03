import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}

import debug
import game_engine
import logger
import model
import presets

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
  // Debug events
  SquareHover(square: game_engine.Square, mouse_event: Dynamic)
  SquareUnhover
  DebugPlacementOpting(piece: game_engine.Piece)
  DebugPlacePiece(coords: game_engine.Coords)
  DebugClearBoard
  DebugResetBoard
  // Preset events
  ApplyPreset(preset: presets.Preset)
  PresetHover(preset: presets.Preset)
  PresetUnhover
}

pub fn process_msg(model: model.Model, msg: Msg) {
  case msg {
    Undo -> set_game(model, game_engine.undo_last_move(model.game))
    PassTurn -> {
      use <- bool.guard(
        model.game.positioning,
        model.Model(
          ..model,
          game: game_engine.pass_turn_during_positioning(model.game),
        ),
      )

      model.Model(..model, game: game_engine.pass_turn(model.game))
    }

    // Debug events
    SquareHover(square, mouse_event) -> {
      let mouse_position = debug.get_mouse_position(mouse_event)
      model.Model(
        ..model,
        debug_hovered_square: Some(square),
        debug_mouse_position: Some(mouse_position),
      )
    }

    SquareUnhover -> {
      model.Model(
        ..model,
        debug_hovered_square: None,
        debug_mouse_position: None,
      )
    }

    DebugPlacePiece(coords) -> {
      let target_square = game_engine.retrieve_square(model.game.board, coords)
      case model.opting_piece {
        Some(piece) -> {
          let updated_game =
            game_engine.execute_placement(
              model.game,
              None,
              piece,
              target_square,
            )
          set_game(model, updated_game)
        }
        None -> model
      }
    }

    DebugClearBoard -> {
      let empty_game = game_engine.new_game()
      set_game(model, game_engine.Game(..model.game, board: empty_game.board))
    }

    DebugResetBoard -> {
      set_game(model, game_engine.new_debug_game())
    }

    // Preset events
    ApplyPreset(preset) -> {
      case model.game.positioning {
        True -> {
          let updated_game =
            presets.apply_preset_to_game(
              model.game,
              preset,
              model.game.current_player_color,
            )
          set_game(model, updated_game)
        }
        False -> model
      }
    }

    PresetHover(preset) -> {
      model.Model(..model, hovered_preset: Some(preset))
    }

    PresetUnhover -> {
      model.Model(..model, hovered_preset: None)
    }

    Opting(piece) -> {
      // deselect the opting piece if the user touches the same piece twice
      // deselect the enemy piece whenever the user is opting for one of their pieces
      let #(opting_piece, enemy_opting_piece) = case model.opting_piece {
        Some(p) if p == piece && !model.game.positioning -> #(None, None)
        _ -> #(Some(piece), None)
      }

      // we cannot opt for a piece that is frozen
      use <- bool.guard(
        !model.game.positioning
          && !model.debug_mode
          && game_engine.is_piece_frozen(
          model.game.board,
          piece,
          game_engine.retrieve_square_from_piece(model.game.board, piece),
        ),
        model,
      )

      let valid_coords = case opting_piece {
        Some(p) if !model.game.positioning -> {
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

      model.Model(
        ..model,
        opting_piece:,
        enemy_opting_piece:,
        valid_coords:,
        error: None,
      )
    }

    EnemyOpting(piece) -> {
      // deselect if the user touches the same piece twice
      let enemy_opting_piece = case model.enemy_opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      let valid_coords = case model.opting_piece {
        Some(strong_piece) ->
          Some(game_engine.valid_coords_for_reposition_piece(
            model.game.board,
            strong_piece,
            piece,
          ))

        _ -> None
      }

      model.Model(..model, enemy_opting_piece:, valid_coords:, error: None)
    }

    SquareOpting(square) -> {
      case model.valid_coords, model.game.positioning {
        _, True -> {
          case model.opting_piece, square {
            Some(game_engine.Piece(_, game_engine.Gold, _)), square
              if square.x == 1 || square.x == 2
            -> {
              model.Model(..model, opting_square: Some(square))
            }

            Some(game_engine.Piece(_, game_engine.Silver, _)), square
              if square.x == 7 || square.x == 8
            -> {
              model.Model(..model, opting_square: Some(square))
            }

            _, _ -> model.Model(..model, opting_square: None)
          }
        }
        Some(coords), _ -> {
          let coords =
            list.map(coords, fn(tuple) {
              let #(pos, _kind) = tuple
              pos
            })

          case list.contains(coords, #(square.x, square.y)) {
            True -> {
              model.Model(..model, opting_square: Some(square))
            }
            _ -> model.Model(..model, opting_square: None)
          }
        }
        _, _ -> model.Model(..model, opting_square: None)
      }
    }

    DebugPlacementOpting(piece) -> {
      // deselect if the user touches the same piece twice
      let debug_opting_piece = case model.debug_opting_piece {
        Some(p) if p == piece -> None
        _ -> Some(piece)
      }

      model.Model(..model, debug_opting_piece:)
    }

    PlacePiece(target_square) -> {
      use <- bool.guard(model.debug_mode, {
        case model.debug_opting_piece {
          Some(piece) -> {
            let updated_game =
              game_engine.execute_placement(
                model.game,
                None,
                piece,
                target_square,
              )
            set_game(model, updated_game)
          }
          _ -> model
        }
      })

      case model.opting_piece {
        Some(piece) if piece.color == model.game.current_player_color -> {
          let source_coords = case
            list.find(model.game.board, fn(square) {
              square.piece == Some(piece)
            })
          {
            Ok(source_square) -> Some(#(source_square.x, source_square.y))
            Error(_) -> None
          }

          place_piece(
            model,
            #(target_square.x, target_square.y),
            piece,
            source_coords,
          )
        }
        _ -> model
      }
    }

    MovePiece(target_square) -> {
      case model.opting_piece {
        Some(piece) if target_square.piece != Some(piece) ->
          move_piece(model, piece, #(target_square.x, target_square.y))

        _ -> model
      }
    }

    RepositionPiece(target_square) ->
      case model.opting_piece, model.enemy_opting_piece {
        Some(strong_piece), Some(weak_piece)
          if target_square.piece != Some(strong_piece)
          && target_square.piece != Some(weak_piece)
        ->
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
  target_coords: game_engine.Coords,
  piece: game_engine.Piece,
  source_coords: Option(game_engine.Coords),
) -> model.Model {
  use <- bool.guard(model.debug_mode, {
    let game =
      game_engine.execute_placement(
        model.game,
        source_coords,
        piece,
        game_engine.retrieve_square(model.game.board, target_coords),
      )
    set_game(model, game)
  })

  case
    game_engine.place_piece(model.game, target_coords, piece, source_coords)
  {
    Ok(game) -> set_game(model, game)
    Error(error) -> {
      logger.print_placement_error(error, piece, target_coords)
      set_error(model, error)
    }
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

fn set_game(model: model.Model, game: game_engine.Game) -> model.Model {
  model.Model(
    game: game,
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
    debug_mode: model.debug_mode,
    debug_opting_piece: None,
    debug_hovered_square: None,
    debug_mouse_position: None,
    presets: model.presets,
    hovered_preset: None,
  )
}

fn set_error(model: model.Model, error: String) -> model.Model {
  model.Model(
    game: model.game,
    error: Some(error),
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    opting_square: None,
    debug_mode: model.debug_mode,
    debug_opting_piece: None,
    debug_hovered_square: None,
    debug_mouse_position: None,
    presets: model.presets,
    hovered_preset: None,
  )
}
