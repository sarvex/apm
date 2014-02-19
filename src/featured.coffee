_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

auth = require './auth'
Command = require './command'
config = require './config'
tree = require './tree'

module.exports =
class Featured extends Command
  @commandNames: ['featured']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm featured
             apm featured --themes
             apm featured --compatible 0.49.0

      List the Atom packages/themes that are currently featured in the atom.io
      registry.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('c', 'compatible').string('compatible').describe('compatible', 'Only list packages/themes compatitle with this Atom version')
    options.boolean('json').describe('json', 'Output featured packages as JSON array')

  getFeaturedPackages: (atomVersion, callback) ->
    [callback, atomVersion] = [atomVersion, null] if _.isFunction(atomVersion)

    auth.getToken (error, token) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: "#{config.getAtomPackagesUrl()}/featured"
          json: true
          proxy: process.env.http_proxy || process.env.https_proxy
          headers:
            authorization: token
        requestSettings.qs = engine: atomVersion if atomVersion

        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else if response.statusCode is 200
            packages = body.filter (pack) -> pack.releases?.latest?
            packages = packages.map ({readme, metadata}) -> _.extend({}, metadata, {readme})
            packages = _.sortBy(packages, 'name')
            callback(null, packages)
          else
            message = body.message ? body.error ? body
            callback("Requesting packages failed: #{message}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @getFeaturedPackages options.argv.compatible, (error, packages) ->
      if error?
        callback(error)
        return

      if options.argv.json
        console.log(JSON.stringify(packages))
      else
        if options.argv.themes
          packages = packages.filter ({theme}) -> theme
          console.log "#{'Featured Atom Themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Featured Atom Packages'.cyan} (#{packages.length})"


        tree packages, ({name, version, description}) ->
          label = name.yellow
          label += " #{description.replace(/\s+/g, ' ')}" if description
          label

        console.log()
        console.log "Use `apm install` to install them or visit #{'http://atom.io/packages'.underline} to read more about them."
        console.log()

      callback()
