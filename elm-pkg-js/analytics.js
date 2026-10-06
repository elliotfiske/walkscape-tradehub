/* elm-pkg-js
import Json.Encode
port analyticsEvent : Json.Encode.Value -> Cmd msg
*/

// Forwards `Analytics.track` events to Simple Analytics. `sa_event` is a queue
// stub from head.html until latest.js loads, and missing if an ad blocker
// stops it, so a failed call must never break the app.
exports.init = function init(app) {
  if (!app.ports || !app.ports.analyticsEvent) return

  app.ports.analyticsEvent.subscribe(function (event) {
    try {
      if (typeof window.sa_event !== 'function') return
      if (Object.keys(event.metadata).length === 0) window.sa_event(event.name)
      else window.sa_event(event.name, event.metadata)
    } catch (e) {
      console.warn('analytics event failed', e)
    }
  })
}
