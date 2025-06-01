import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode

/// Checks if debug mode is enabled via URL parameters
@external(javascript, "./ffi/browser_ffi.mjs", "isDebugMode")
pub fn is_debug_mode() -> Bool {
  panic as "Not valid outside browser"
}

/// Gets mouse position for tooltips
@external(javascript, "./ffi/browser_ffi.mjs", "getMousePosition")
fn get_mouse_position_ffi(_event: dynamic.Dynamic) -> dynamic.Dynamic {
  panic as "Not valid outside browser"
}

pub type MousePosition {
  MousePosition(x: Int, y: Int)
}

pub fn get_mouse_position(event: Dynamic) -> MousePosition {
  let pos = get_mouse_position_ffi(event)
  let decoder = {
    use x <- decode.field("x", decode.int)
    use y <- decode.field("y", decode.int)
    decode.success(#(x, y))
  }

  case decode.run(pos, decoder) {
    Ok(#(x, y)) -> MousePosition(x, y)
    _ -> MousePosition(0, 0)
  }
}
