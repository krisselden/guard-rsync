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
      @input = options[:input]
      @output = options[:output]
      @delete = options[:delete] || false
      raise 'output must be a directory' unless File.directory? @output or @output =~ /^.*:.*$/
      @dirname = File.basename(@input)
      @excludes = options[:excludes]
      if @excludes.is_a? Hash
        raise ":excludes option is no longer a Hash; please check the README"
      end
      @extra = options[:extra] || []
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
      with_exclude_file(@excludes) do |exclude_file|
        extra = @delete ? ['--delete'] : [ ]
        cmd = rsync_cmd(exclude_file, extra)
        return run_cmd(cmd)
      end
    end

    # Called on file(s) removals that the Guard plugin watches.
    #
    # @param [Array<String>] removed_paths the removed files or paths
    # @raise [:task_has_failed] when run_on_removals has failed
    # @return [Boolean] whether rsync was successful
    #
    def run_on_removals(removed_paths)
      # We remove via rsync --delete by including the removed file(s)
      # and excluding '*'.  However, if a file 'foo/bar/baz.rb' is
      # removed, then we need not only '+ /foo/bar/baz.rb' but also '+
      # /foo' and '+ /bar', as documented under the "INCLUDE/EXCLUDE
      # PATTERN RULES" section of the rsync(1) man page.
      includes = removed_paths.inject(Set.new) do |acc, path|
        rel_path = path.sub(@input, '')
        # Annoyingly, Pathname#descend returns nil
        Pathname.new(rel_path).descend { |p| acc.add "+ #{p}" }
        acc
      end

      with_exclude_file(includes.to_a + [ '- *' ]) do |exclude_file|
        cmd = rsync_cmd(exclude_file, [ '--delete' ])
        return run_cmd(cmd)
      end
    end

    private
    def rsync_cmd(exclude_file, extra)
      cmd = %w(rsync -a) + @extra + extra
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

    def with_exclude_file(excludes)
      exclude_file = Tempfile.new('exclude')
      begin
        exclude_file.puts(excludes)
        exclude_file.close
        yield exclude_file
      ensure
        exclude_file.unlink
      end
    end
  end

end

