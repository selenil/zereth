import gleam/list
import gleam/option.{type Option, None}

import debug
import game_engine
import presets

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
    debug_mode: Bool,
    debug_opting_piece: Option(game_engine.Piece),
    debug_hovered_square: Option(game_engine.Square),
    debug_mouse_position: Option(debug.MousePosition),
    presets: List(presets.Preset),
    hovered_preset: Option(presets.Preset),
  )
}

pub fn init(_flags) -> Model {
  let debug_mode = debug.is_debug_mode()
  let loaded_presets = load_presets()

  Model(
    game: case debug_mode {
      True -> game_engine.new_debug_game()
      False -> game_engine.new_game()
    },
    opting_piece: None,
    enemy_opting_piece: None,
    valid_coords: None,
    error: None,
    opting_square: None,
    debug_mode: debug_mode,
    debug_opting_piece: None,
    debug_hovered_square: None,
    debug_mouse_position: None,
    presets: loaded_presets,
    hovered_preset: None,
  )
}

// Load all presets we have
fn load_presets() -> List(presets.Preset) {
  presets.preset_names
  |> list.filter_map(fn(name) {
    case load_preset(name) {
      Ok(preset) -> Ok(preset)
      Error(_) -> Error(Nil)
    }
  })
}

// Load a single preset 
fn load_preset(name: String) -> Result(presets.Preset, String) {
  case presets.preset_content(name) {
    Ok(content) -> presets.parse_preset(name, content)
    Error(err) -> Error(err)
  }
}
