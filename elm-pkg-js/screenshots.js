/* elm-pkg-js
import Json.Encode
import Json.Decode
port downscaleScreenshot : Json.Encode.Value -> Cmd msg
port screenshotDownscaled : (Json.Decode.Value -> msg) -> Sub msg
*/

// Shrinks a screenshot picked on the report form: at most `longSide` pixels on
// its long side, re-encoded as JPEG, lowering the quality (then the size) until
// the data URL fits in `maxLength` characters. The backend refuses anything
// bigger, so this has to get under the cap.
exports.init = function init(app) {
  if (!app.ports || !app.ports.downscaleScreenshot) return

  function reply(message) {
    app.ports.screenshotDownscaled.send(message)
  }

  app.ports.downscaleScreenshot.subscribe(function (request) {
    var img = new Image()
    img.onload = function () {
      try {
        var scale = Math.min(1, request.longSide / Math.max(img.naturalWidth, img.naturalHeight))
        var width = Math.max(1, Math.round(img.naturalWidth * scale))
        var height = Math.max(1, Math.round(img.naturalHeight * scale))
        var canvas = document.createElement('canvas')
        var ctx = canvas.getContext('2d')
        var quality = 0.85
        var out

        function draw() {
          canvas.width = width
          canvas.height = height
          // JPEG has no transparency, so give see-through screenshots a dark background.
          ctx.fillStyle = '#0b1416'
          ctx.fillRect(0, 0, width, height)
          ctx.drawImage(img, 0, 0, width, height)
          out = canvas.toDataURL('image/jpeg', quality)
        }

        draw()
        while (out.length > request.maxLength && quality > 0.45) {
          quality -= 0.1
          out = canvas.toDataURL('image/jpeg', quality)
        }
        while (out.length > request.maxLength && width > 320) {
          width = Math.round(width * 0.8)
          height = Math.round(height * 0.8)
          draw()
        }

        if (out.length > request.maxLength) reply({ error: "That image is too big, even after shrinking it." })
        else reply({ ok: out })
      } catch (e) {
        console.warn('screenshot downscale failed', e)
        reply({ error: "Something went wrong with that image." })
      }
    }
    img.onerror = function () {
      reply({ error: "That file isn't an image I can read." })
    }
    img.src = request.dataUrl
  })
}
