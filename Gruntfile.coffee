LIVERELOAD_PORT = 35729
lrSnippet = require('connect-livereload')({port: LIVERELOAD_PORT})
mountFolder = (connect, dir) -> connect.static(require('path').resolve(dir));

# Project configuration
# ---------------------
projectConfig =
  app: 'app'
  components: 'components'
  release: 'lib'
  test: 'test'


module.exports = (grunt) ->
  # Shows time elapsed
  require('time-grunt')(grunt)

  # Loads tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  # Grunt configuration:
  #
  # https://github.com/cowboy/grunt/blob/master/docs/getting_started.md
  #
  grunt.initConfig
    project: projectConfig

    # Task configurations
    # -------------------

    # Compiles source
    coffee:
      compile:
        files:
          '<%= project.release %>/backbone.joints.js': '<%= project.app %>/backbone.joints.coffee'
          '<%= project.test %>/spec/backbone.joints.spec.js': '<%= project.test %>/spec/backbone.joints.spec.coffee'

    # Runs a test server
    open:
      server:
        path: 'http://0.0.0.0:<%= connect.options.port %>/example'

    # Headless testing through PhantomJS
    mocha:
      test:
        src: ['test/index.html']
        options:
          run: true

    connect:
      options:
        port: 9000,
        hostname: '0.0.0.0'
      livereload:
        options:
          middleware: (connect) -> [
              lrSnippet,
              mountFolder(connect, '.')
            ]

    # Watch configuration
    watch:
      options:
        nospawn: true
      scripts:
        files: ['**/*.coffee']
        tasks: ['coffee']
        spawn: true
      livereload:
        options:
          livereload: LIVERELOAD_PORT
        files: [
          '<%= project.app %>/*.html'
          '<%= project.components %>/scripts/{,*/}*.js'
          '<%= project.test %>/scripts/{,*/}*.js'
        ]


  # Aliases
  # -------
  grunt.registerTask 'build', ['coffee']
  grunt.registerTask 'test', ['build', 'mocha']
  grunt.registerTask 'default', ['build', 'connect:livereload', 'open', 'watch']
