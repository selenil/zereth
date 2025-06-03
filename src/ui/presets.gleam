import gleam/list
import gleam/option.{Some}
import lustre/attribute
import lustre/element/html
import lustre/event

import events.{ApplyPreset, PresetHover, PresetUnhover}
import game_engine
import model
import presets

pub fn render_preset_buttons(model: model.Model) {
  case model.game.positioning {
    True -> {
      html.div([attribute.class("preset-buttons")], [
        html.h3([attribute.class("preset-title")], [
          html.text("Quick Setup Presets"),
        ]),
        html.div(
          [attribute.class("preset-grid")],
          list.map(model.presets, fn(preset) {
            render_preset_button(preset, model.game.current_player_color)
          }),
        ),
      ])
    }
    False -> html.text("")
  }
}

fn render_preset_button(
  preset: presets.Preset,
  current_color: game_engine.PieceColor,
) {
  let color_class = case current_color {
    game_engine.Gold -> "gold"
    game_engine.Silver -> "silver"
  }

  html.button(
    [
      attribute.class("preset-button"),
      attribute.class(color_class),
      attribute.title(preset.description),
      event.on_click(ApplyPreset(preset)),
      //event.on_mouse_over(PresetHover(preset)),
    //event.on_mouse_leave(PresetUnhover),
    ],
    [
      html.div([attribute.class("preset-name")], [html.text(preset.name)]),
      html.div([attribute.class("preset-description")], [
        html.text(preset.description),
      ]),
    ],
  )
}

pub fn render_preset_tooltip(model: model.Model) {
  case model.hovered_preset, model.game.positioning {
    Some(hovered_preset), True -> {
      html.div([attribute.class("preset-tooltip")], [
        html.h4([], [html.text(hovered_preset.name)]),
        html.p([], [html.text(hovered_preset.description)]),
        html.div([attribute.class("preset-preview")], [
          render_preset_preview(hovered_preset, model.game.current_player_color),
        ]),
      ])
    }
    _, _ -> html.text("")
  }
}

fn render_preset_preview(preset: presets.Preset, color: game_engine.PieceColor) {
  let preview_rows = case color {
    game_engine.Gold -> [1, 2]
    game_engine.Silver -> [7, 8]
  }

  html.div(
    [attribute.class("preset-preview-board")],
    list.flat_map(preview_rows, fn(row) {
      list.map(list.range(1, 8), fn(col) {
        let coords = #(row, col)
        let piece_at_coords =
          list.find(preset.pieces, fn(preset_piece) {
            let converted_coords =
              presets.convert_coords_for_color(preset_piece.coords, color)
            converted_coords == coords
          })

        render_preview_square(coords, piece_at_coords, color)
      })
    }),
  )
}

fn render_preview_square(
  coords: game_engine.Coords,
  piece_at_coords: Result(presets.PresetPiece, Nil),
  color: game_engine.PieceColor,
) {
  let #(x, y) = coords
  let square_class = case { x + y } % 2 == 0 {
    True -> "preview-square even"
    False -> "preview-square odd"
  }

  let piece_element = case piece_at_coords {
    Ok(preset_piece) -> [render_preview_piece(preset_piece.kind, color)]
    Error(_) -> []
  }

  html.div([attribute.class(square_class)], piece_element)
}

fn render_preview_piece(
  kind: game_engine.PieceKind,
  color: game_engine.PieceColor,
) {
  let piece_name =
    game_engine.piece_color_to_string(color)
    <> "_"
    <> game_engine.piece_kind_to_string(kind)

  html.img([
    attribute.src("assets/pieces/" <> piece_name <> ".png"),
    //attribute.style([#("width", "25px"), #("height", "25px")]),
    attribute.alt(piece_name),
  ])
}
