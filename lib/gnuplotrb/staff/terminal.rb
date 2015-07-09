module GnuplotRB
  ##
  # === Overview
  # Terminal keeps open pipe to gnuplot process, cares about naming in-memory
  # datablocks (just indexing with sequential integers). All the output
  # to gnuplot handled by this class. Terminal also handles options passed
  # to gnuplot as 'set key value'.
  class Terminal
    include ErrorHandling
    OPTION_ORDER = [:term, :output, :multiplot, :timefmt, :xrange]

    class << self
      ##
      # Close given gnuplot pipe
      def close_arg(stream)
        stream.puts
        stream.puts 'exit'
        Process.waitpid(stream.pid)
      end
    end

    ##
    # ====== Overview
    # Creates new Terminal connected with gnuplot.
    # Uses Settings::gnuplot_path to find gnuplot
    # executable. Each time you create Terminal it starts new
    # gnuplot subprocess which is closed after GC deletes
    # linked Terminal object.
    # ====== Arguments
    # * *persist* - gnuplot's -persist option
    def initialize(persist: false)
      @cmd = Settings.gnuplot_path
      @current_datablock = 0
      @cmd += ' -persist' if persist
      @cmd += ' 2>&1'
      stream = IO.popen(@cmd, 'w+')
      handle_stderr(stream)
      ObjectSpace.define_finalizer(self, proc { Terminal.close_arg(stream) })
      @in = stream
      yield(self) if block_given?
    end

    ##
    # ====== Overview
    # Outputs datablock to this gnuplot terminal.
    # ====== Arguments
    # * *data* - data stored in datablock
    # ====== Examples
    #   data = "1 1\n2 4\n3 9"
    #   Terminal.new.store_datablock(data)
    #   #=> returns '$DATA1'
    #   #=> outputs to gnuplot:
    #   #=>   $DATA1 << EOD
    #   #=>   1 1
    #   #=>   2 4
    #   #=>   3 9
    #   #=>   EOD
    def store_datablock(data)
      name = "$DATA#{@current_datablock += 1}"
      stream_puts "#{name} << EOD"
      stream_puts data
      stream_puts 'EOD'
      name
    end

    ##
    # ====== Overview
    # Converts given options to gnuplot format;
    # for {opt1: val1, .. , optN: valN} it returns
    #   set opt1 val1
    #   ..
    #   set optN valN
    # ====== Arguments
    # * *options* - hash of options to convert
    def options_hash_to_string(options)
      result = ''
      options.sort_by { |key, _| OPTION_ORDER.find_index(key) || -1 }.each do |key, value|
        if value
          result += "set #{OptionHandling.option_to_string(key, value)}\n"
        else
          result += "unset #{key}\n"
        end
      end
      result
    end

    ##
    # ====== Overview
    # Applies given options to current gnuplot instance;
    # for {opt1: val1, .. , optN: valN} it will output to gnuplot
    #   set opt1 val1
    #   ..
    #   set optN valN
    # ====== Arguments
    # *options* - hash of options to set
    # ====== Examples
    #   set({term: ['qt', size: [100, 100]]})
    #   #=> outputs to gnuplot: "set term qt size 100,100\n"
    def set(options)
      OptionHandling.validate_terminal_options(options)
      stream_puts(options_hash_to_string(options))
    end

    ##
    # ====== Overview
    # Unset some options
    # ====== Arguments
    # * **options* - Array of options need to unset
    def unset(*options)
      options.flatten
             .sort_by { |key| OPTION_ORDER.find_index(key) || -1 }
             .each { |key| stream_puts "unset #{OptionHandling.string_key(key)}" }
      self
    end

    ##
    # ====== Overview
    # Short way to plot Datablock, Plot or Splot object.
    # Other items will be just piped out to gnuplot.
    def <<(item)
      if item.is_a? Plottable
        item.plot(self)
      else
        stream_print(item.to_s)
      end
      self
    end

    ##
    # ====== Overview
    # Just puts *command* to gnuplot pipe and returns self
    # to allow chaining.
    def stream_puts(command)
      stream_print("#{command}\n")
    end

    ##
    # ====== Overview
    # Just prints *command* to gnuplot pipe and returns self
    # to allow chaining.
    def stream_print(command)
      check_errors
      @in.print(command)
      self
    end

    ##
    # ====== Overview
    # Call replot on gnuplot. This will execute last plot once again
    # with rereading data.
    def replot(**options)
      set(options)
      stream_puts('replot')
      unset(options.keys)
      sleep 0.01 until File.size?(options[:output]) if options[:output]
      self
    end

    ##
    # ====== Overview
    # Send gnuplot command to turn it off and for its Process to quit.
    # Closes pipe so Terminal object should not be used after #close call.
    def close
      check_errors
      Terminal.close_arg(@in)
    end
  end
end
