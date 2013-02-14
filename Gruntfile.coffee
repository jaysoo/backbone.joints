path = require 'path'
livereloadSnippet = require('grunt-contrib-livereload/lib/utils').livereloadSnippet

folderMount = (connect, point) -> connect.static(path.resolve(point))

module.exports = (grunt) ->
  # Grunt configuration:
  #
  # https://github.com/cowboy/grunt/blob/master/docs/getting_started.md
  #
  grunt.initConfig

    # Project configuration
    # ---------------------
    project:
      src: 'src'
      components: 'components'
      release: 'lib'
      test: 'test'


    # Task configurations
    # -------------------

    # Compiles source
    coffee:
      compile:
        files:
          '<%= project.release %>/backbone.relmodel.js': '<%= project.src %>/backbone.relmodel.coffee'
          '<%= project.test %>/spec/backbone.relmodel.spec.js': '<%= project.test %>/spec/backbone.relmodel.spec.coffee'

    # Runs a test server
    connect:
      server:
        options:
          port: 9001
          middleware: (connect, options) -> [livereloadSnippet, folderMount(connect, '.')]

    # Headless testing through PhantomJS
    mocha:
      test:
        src: ['test/index.html']
        options:
          run: true

    # Watch configuration
    regarde:
      scripts:
        files: ['**/*.coffee']
        tasks: ['coffee', 'livereload']
        spawn: true
      html:
        files: '**/*.html'
        tasks: ['livereload']

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-livereload'
  grunt.loadNpmTasks 'grunt-mocha'
  grunt.loadNpmTasks 'grunt-regarde'


  # Aliases
  # -------
  grunt.registerTask 'build', ['coffee']
  grunt.registerTask 'test', ['build', 'mocha']
  grunt.registerTask 'default', ['build', 'livereload-start', 'connect', 'regarde']
