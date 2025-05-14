import gleam/option.{type Option, None}

import game_engine

pub type Model {
  Model(
    game: game_engine.Game,
    opting_piece: Option(game_engine.Piece),
    enemy_opting_piece: Option(game_engine.Piece),
    valid_coords: Option(
      List(#(game_engine.Coords, game_engine.ValidCoordsKind)),
    ),
    error: Option(String),
    opting_square: Option(game_engine.Square),
  )
}

pub fn init(_flags) -> Model {
  Model(
    game: game_engine.new_debug_game(),
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
  )
}
