module GnuplotRB
  ##
  # Just a new error name
  class GnuplotError < ArgumentError
  end

  ##
  # Mixin for classes that need to run subprocess and
  # handle errors from its stderr.
  module ErrorHandling
    ##
    # Check if there were errors in previous commands.
    # Throws GnuplotError in case of any errors.
    def check_errors(raw: false)
      return if @err_array.empty?
      command = ''
      rest = ''
      @semaphore.synchronize do
        command = @err_array.first
        rest = @err_array[1..-1].join('; ')
        @err_array.clear
      end
      message = if raw
        "#{command};#{rest}}"
      else
        "Error in previous command (\"#{command}\"): \"#{rest}\""
      end
      fail GnuplotError, message
    end

    private

    ##
    # Start new thread that will read stderr given as stream
    # and add errors into @err_array.
    def handle_stderr(stream)
      @err_array = []
      # synchronize access to @err_array
      @semaphore = Mutex.new
      Thread.new do
        until (line = stream.gets).nil?
          line.strip!
          @semaphore.synchronize { @err_array << line if line.size > 3 }
        end
      end
    end
  end
end
