module GnuplotRB
  ##
  # === Overview
  # Multiplot allows to place several plots on one layout.
  # It's usage is covered in {multiplot notebook}[http://nbviewer.ipython.org/github/dilcom/gnuplotrb/blob/master/notebooks/multiplot_layout.ipynb].
  class Multiplot
    include Plottable
    ##
    # Array of plots contained by this object.
    attr_reader :plots

    ##
    # ====== Arguments
    # * *plots* are Plot or Splot objects which should be placed
    #   on this multiplot layout
    # * *options* will be considered as 'settable' options of gnuplot
    #   ('set xrange [1:10]' for { xrange: 1..10 } etc) just as in Plot.
    #   Special options of Multiplot are :layout and :title.
    def initialize(*plots, **options)
      @plots = plots[0].is_a?(Hamster::Vector) ? plots[0] : Hamster::Vector.new(plots)
      @options = Hamster.hash(options)
      OptionHandling.validate_terminal_options(@options)
    end

    ##
    # ====== Overview
    # This outputs all the plots to term (if given) or to this
    # Multiplot's own terminal.
    # ====== Arguments
    # * *term* - Terminal to plot to
    # * *options* - will be considered as 'settable' options of gnuplot
    #   ('set xrange [1:10]', 'set title 'plot'' etc)
    # Options passed here have priority over already existing.
    # Inner options of Plots have the highest priority (except
    # :term and :output which are ignored in this case).
    def plot(term = nil, multiplot_part: false, **options)
      plot_options = mix_options(options) do |plot_opts, mp_opts|
        plot_opts.merge(multiplot: mp_opts.to_h)
      end
      terminal = term || (plot_options[:output] ? Terminal.new : own_terminal)
      multiplot(terminal, plot_options)
      if plot_options[:output]
        # guaranteed wait for plotting to finish
        terminal.close unless term
        # not guaranteed wait for plotting to finish
        # work bad with terminals like svg and html
        sleep 0.01 until File.size?(plot_options[:output])
      end
      self
    end

    ##
    # ====== Overview
    # Create new Multiplot object where plot (Plot or Splot object)
    # at *position* will
    # be replaced with the new one created from it by updating.
    # To update a plot you can pass some options for it or a
    # block, that should take existing plot (with new options if
    # you gave them) and return a plot too.
    # ====== Arguments
    # * *position* - position of plot which you need to update
    #   (by default first plot is updated)
    # * *options* - options to update plot with
    # * *&block* - method also may take a block which returns a plot
    # ====== Example
    #   mp = Multiplot.new(Plot.new('sin(x)'), Plot.new('cos(x)'), layout: [2,1])
    #   updated_mp = mp.update_plot(title: 'Sin(x) and Exp(x)') { |sinx| sinx.add('exp(x)') }
    def update_plot(position = 0, **options)
      return self unless block_given? if options.empty?
      replacement = @plots[position].options(options)
      replacement = yield(replacement) if block_given?
      replace_plot(position, replacement)
    end

    alias_method :update, :update_plot

    ##
    # ====== Overview
    # Create new Multiplot object where plot (Plot or Splot object)
    # at *position* will be replaced with the given one.
    # ====== Arguments
    # * *position* - position of plot which you need to update
    #   (by default first plot is updated)
    # * *plot* - replacement for existing plot
    # ====== Example
    #   mp = Multiplot.new(Plot.new('sin(x)'), Plot.new('cos(x)'), layout: [2,1])
    #   mp_with_replaced_plot = mp.replace_plot(Plot.new('exp(x)', title: 'exp instead of sin'))
    def replace_plot(position = 0, plot)
      self.class.new(@plots.set(position, plot), @options)
    end

    alias_method :replace, :replace_plot

    ##
    # ====== Overview
    # Create new Multiplot with given *plots* added before plot at given *position*.
    # (by default it adds plot at the front).
    # ====== Arguments
    # * *position* - position before which you want to add a plot
    # * *plots* - sequence of plots you want to add
    # ====== Example
    #   mp = Multiplot.new(Plot.new('sin(x)'), Plot.new('cos(x)'), layout: [2,1])
    #   enlarged_mp = mp.add_plots(Plot.new('exp(x)')).layout([3,1])
    def add_plots(*plots)
      plots.unshift(0) unless plots[0].is_a?(Numeric)
      self.class.new(@plots.insert(*plots), @options)
    end

    alias_method :add_plot, :add_plots
    alias_method :<<, :add_plots
    alias_method :add, :add_plots

    ##
    # ====== Overview
    # Create new Multiplot without plot at given position
    # (by default last plot is removed).
    # ====== Arguments
    # * *position* - position of plot you want to remove
    # ====== Example
    #   mp = Multiplot.new(Plot.new('sin(x)'), Plot.new('cos(x)'), layout: [2,1])
    #   mp_with_only_cos = mp.remove_plot(0)
    def remove_plot(position = -1)
      self.class.new(@plots.delete_at(position), @options)
    end

    alias_method :remove, :remove_plot

    ##
    # ====== Overview
    # Equal to #plots[*args]
    def [](*args)
      @plots[*args]
    end

    private

    ##
    # Default options to be used for that plot
    def default_options
      {
        layout: [2, 2],
        title: 'Multiplot'
      }
    end

    ##
    # This plot have some specific options which
    # should be handled different way than others.
    # Here are keys of this options.
    def specific_keys
      %w(
        title
        layout
      )
    end

    ##
    # Create new Multiplot object with the same set of plots and
    # given options.
    # Used in OptionHandling module.
    def new_with_options(options)
      self.class.new(@plots, options)
    end

    ##
    # Check if given options corresponds to multiplot.
    # Uses #specific_keys to check.
    def specific_option?(key)
      specific_keys.include?(key.to_s)
    end

    ##
    # Takes all options and splits them into specific and
    # others. Requires a block where this two classes should
    # be mixed.
    def mix_options(options)
      all_options = @options.merge(options)
      specific_options, plot_options = all_options.partition { |key, _value| specific_option?(key) }
      yield(plot_options, default_options.merge(specific_options))
    end

    ##
    # Just a part of #plot.
    def multiplot(terminal, options)
      terminal.set(options)
      @plots.each { |graph| graph.plot(terminal, multiplot_part: true) }
      terminal.unset(options.keys)
    end
  end
end
