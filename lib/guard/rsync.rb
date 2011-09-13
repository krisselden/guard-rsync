require 'guard'
require 'guard/guard'
require 'guard/watcher'
require 'tempfile'

module Guard

  # The CoffeeScript guard that gets notifications about the following
  # Guard events: `start`, `stop`, `reload`, `run_all` and `run_on_change`.
  #
  class Rsync < Guard
    # Initialize Guard::Sync.
    #
    # @param [Array<Guard::Watcher>] watchers the watchers in the Guard block
    # @param [Hash] options the options for the Guard
    # @option options [String] :input the input directory
    # @option options [String] :output the output directory
    # @option options [Hash] :excludes the map of excludes patterns in the
    #         input directory to exclude files in the output directory.
    def initialize(watchers = [], options = { })
      @input = ensure_no_trailing_slash(options[:input])
      @output = options[:output]
      raise 'input must be a directory' unless File.directory? @input
      raise 'output must be a directory' unless File.directory? @output
      @dirname = File.basename(@input)
      @excludes = options[:excludes]
      @run_group_on_start = options[:run_group_on_start]
      super
    end

    # Call once when guard starts
    def start
      run_all
      if @run_group_on_start
        ::Guard.guards.each do |guard|
          guard.run_all if self != guard && group == guard.group
        end
      end
    end

    # Gets called when rsync should be run.
    #
    # @return [Boolean] rsync was successful
    def run_all
      run_on_change([])
    end

    # Gets called when watched paths and files have changes.
    #
    # @param [Array<String>] paths the changed paths and files
    # @return [Boolean] rsync was successful
    def run_on_change(paths)
      input_excludes = []
      output_excludes = []
      Dir.chdir(@input) do
        Dir.glob('**/*').each do |file|
          @excludes.each do |pattern, transform|
            matches = file.match(pattern)
            if matches
              input_excludes << File.join('/', @dirname, file)
              output_excludes << File.join('/', @dirname, transform.call(matches)) if transform
            end
          end
        end
      end
      exclude_file = Tempfile.new('exclude')
      begin
        exclude_file.puts(input_excludes)
        exclude_file.puts(output_excludes)
        ::Guard.listener.ignore_paths.each do |dir|
          next if dir == '.' or dir == '..'
          exclude_file.puts(ensure_trailing_slash(File.basename(dir)))
        end
        exclude_file.flush
        UI.info `rsync -av --delete --exclude-from "#{exclude_file.path}" "#{@input}" "#{@output}"`
        success = $?.success?
        return success
      ensure
         exclude_file.close
         exclude_file.unlink
      end
    end

    private
    def ensure_trailing_slash(path)
      path.gsub(/(.*[^\/])\Z/,'\1/')
    end

    def ensure_no_trailing_slash(path)
      path.gsub(/\/\Z/,'')
    end
  end

end

