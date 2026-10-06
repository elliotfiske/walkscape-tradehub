const analytics = require('./elm-pkg-js/analytics.js')

exports.init = async function init(app) {
  analytics.init(app)
}
