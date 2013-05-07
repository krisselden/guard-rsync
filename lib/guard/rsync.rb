require 'guard'
require 'guard/guard'
require 'guard/watcher'
require 'tempfile'
require 'open3'
require 'io/wait'

module Guard

  # The guard gets notifications about the following Guard events:
  # `start`, `stop`, `reload`, `run_all` and `run_on_change`.
  #
  class Rsync < Guard
    # Initialize Guard::Sync.
    #
    # @param [Array<Guard::Watcher>] watchers the watchers in the Guard block
    # @param [Hash] options the options for the Guard
    # @option options [String] :input the input directory
    # @option options [String] :output the output directory
    # @option options [Array]  :excludes the list of rsync exclude patterns
    def initialize(watchers = [], options = { })
      @input = ensure_no_trailing_slash(options[:input])
      @output = options[:output]
      @delete = options[:delete] || false
      raise 'input must be a directory' unless File.directory? @input
      raise 'output must be a directory' unless File.directory? @output or @output =~ /^.*:.*$/
      @dirname = File.basename(@input)
      @excludes = options[:excludes]
      if @excludes.is_a? Hash
        raise ":excludes option is no longer a Hash; please check the README"
      end
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

    # Gets called when watched paths and files are modified or added,
    # but *not* on removals (unlike run_on_changes - note the extra 's')
    #
    # @param [Array<String>] changed_paths the changed paths and files
    # @return [Boolean] rsync was successful
    def run_on_change(changed_paths)
      with_exclude_file do |exclude_file|
        cmd = rsync_cmd(exclude_file)
        return run_cmd(cmd)
      end
    end

    private
    def rsync_cmd(exclude_file)
      cmd = %w(rsync -av)
      cmd.push '--delete' if @delete
      cmd += ['--exclude-from', exclude_file.path ]
      cmd += [ @input, @output ]
      cmd
    end

    def run_cmd(cmd)
      UI.info "running: #{cmd.join ' '}"
      Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        readers = [stdout, stderr]
        while not readers.empty?
          rs, = IO.select(readers)
          break if rs.empty?
          rs.each do |r|
            begin
              got = r.readpartial(1024)
              out = (r == stdout) ? $stdout : $stderr
              out.print got
            rescue EOFError
              readers.delete_if { |s| r == s }
            end
          end
        end
        wait_thread.value.success?
      end
    end

    def with_exclude_file
      exclude_file = Tempfile.new('exclude')
      begin
        exclude_file.puts(@excludes)
        exclude_file.close
        yield exclude_file
      ensure
        exclude_file.unlink
      end
    end

    def ensure_no_trailing_slash(path)
      path.gsub(/\/\Z/,'')
    end
  end

end

