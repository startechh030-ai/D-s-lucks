// D's Luck extension entry point.
// The Wren runtime is embedded at M6 — this file is the shape of it:
// a class per extension, lifecycle methods matching the .ds.
class FpsLogger {
  static onLoad() {
    // subscribe to core stats, draw overlay text via debug API
  }

  static tick(dt) {
    // accumulate; log once per second via Dsl.debug
  }
}
