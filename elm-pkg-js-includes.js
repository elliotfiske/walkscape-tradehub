const analytics = require('./elm-pkg-js/analytics.js')
const screenshots = require('./elm-pkg-js/screenshots.js')

exports.init = async function init(app) {
  analytics.init(app)
  screenshots.init(app)
}
