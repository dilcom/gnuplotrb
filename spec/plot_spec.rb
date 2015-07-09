require 'spec_helper.rb'

describe Plot do
  before(:all) do
    @tmp_dir = File.join('spec', 'tmp')
    Dir.mkdir(@tmp_dir)
    @datafile_path = File.join('spec', 'points.data')
  end

  after(:all) do
    FileUtils.rm_r(@tmp_dir)
  end

  context 'creation' do
    before do
      @title = 'Awesome spec'
      @formula =  %w(sin(x) cos(x) exp(-x))
      @options = { title: @title, term: 'dumb' }
      @df = Daru::DataFrame.new(
        Build: [312, 630, 315, 312],
        Test: [525, 1050, 701, 514],
        Deploy: [215, 441, 370, 220]
      )
    end

    it 'should be created out of sequence of datasets' do
      datasets = @formula.map { |formula| Dataset.new(formula) }
      expect(Plot.new(*datasets)).to be_an_instance_of(Plot)
    end

    it 'should be created out of sequence of arrays' do
      expect(Plot.new(*@formula)).to be_an_instance_of(Plot)
    end

    it 'should set options passed to constructor' do
      plot = Plot.new(*@formula, **@options)
      expect(plot).to be_an_instance_of(Plot)
      expect(plot.title).to eql(@title)
    end

    it 'should be created out of Daru::DataFrame' do
      p = Plot.new(@df)
      expect(p).to be_an_instance_of(Plot)
      expect(p.datasets.size).to be_eql(3)
    end
  end

  context 'options handling' do
    before do
      @options = Hamster.hash(title: 'GnuplotRB::Plot', yrange: 0..3)
      @plot = Plot.new(**@options)
    end

    it 'should allow to get option value by name' do
      expect(@plot.title).to eql(@options[:title])
    end

    it 'should allow to safely set option value by name' do
      another_title = 'Some new titile'
      new_plot = @plot.title(another_title)
      expect(@plot).not_to equal(new_plot)
      expect(new_plot.title).to eql(another_title)
      expect(@plot.title).to eql(@options[:title])
    end

    it 'should allow to get terminal' do
      expect(@plot.own_terminal).to be_an_instance_of(Terminal)
    end

    it 'should allow to get all the options' do
      expect(@plot.options).to eql(@options)
    end

    it 'should allow to safely set several options at once' do
      new_options = { title: 'Another title', xrange: 1..5 }
      new_plot = @plot.options(new_options)
      expect(new_plot).to_not equal(@plot)
      expect(new_plot).to be_an_instance_of(Plot)
      expect(new_plot.options).to eql(@options.merge(new_options))
    end
  end

  context 'modifying datasets' do
    before do
      @plot_math = Plot.new(['sin(x)', title: 'Just a sin'])
      @dataset = Dataset.new('exp(-x)')
      @plot_two_ds = Plot.new(['cos(x)'], ['x*x'])
      @options = { title: 'Example dataset' }
      @plot_datafile = Plot.new([@datafile_path])
      @data = [1, 2, 3, 4]
      @plot_data_inmemory = Plot.new([@data])
      @plot_data_tempfile = Plot.new([@data, file: true])
    end

    it 'should create new Plot when user adds a dataset' do
      new_plot = @plot_math.add_dataset(@dataset)
      expect(new_plot).to_not be_equal(@plot_math)
    end

    it 'should create new Plot when user adds a dataset using #<<' do
      new_plot = @plot_math << @dataset
      expect(new_plot).to_not be_equal(@plot_math)
    end

    it 'should create new Plot when user removes a dataset' do
      new_plot = @plot_two_ds.remove_dataset
      expect(new_plot).to_not be_equal(@plot_two_ds)
    end

    it 'should remove dataset exactly at given position' do
      (0..1).each do |i|
        j = i == 0 ? 1 : 0
        new_plot = @plot_two_ds.remove_dataset(i)
        expect(new_plot.datasets[0].data).to be_eql(@plot_two_ds.datasets[j].data)
      end
    end

    it 'should create new Plot when user replaces a dataset' do
      new_plot = @plot_two_ds.replace_dataset(@dataset)
      expect(new_plot).to_not be_equal(@plot_two_ds)
    end

    it 'should remplace dataset exactly at given position' do
      (0..1).each do |i|
        new_plot = @plot_two_ds.replace_dataset(i, @dataset)
        expect(new_plot.datasets[i].data).to be_eql(@dataset.data)
      end
    end

    it 'should allow to update dataset at given position with options' do
      (0..1).each do |i|
        new_plot = @plot_two_ds.update_dataset(i, @options)
        expect(new_plot.datasets[i].options.to_h).to be_eql(@options)
        expect(new_plot.datasets[i]).to_not equal(@plot_two_ds.datasets[i])
      end
    end

    it 'should not update Plot if neither data nor options update needed' do
      # data and options are empty so no update needed
      expect(@plot_math.update_dataset).to be_equal(@plot_math)
      # dataset with math formula could not to be updated
      expect(@plot_math.update_dataset(data: @data)).to be_equal(@plot_math)
      # dataset with data from existing file could not to be updated
      expect(@plot_datafile.update_dataset(data: @data)).to be_equal(@plot_datafile)
    end

    it 'should create new Plot (and new datablock) if you update data stored in memory' do
      current = File.join(@tmp_dir, 'plot.png')
      updated = File.join(@tmp_dir, 'updated_plot.png')
      new_plot = @plot_data_inmemory.update_dataset(data: @data)
      expect(new_plot).to_not be_equal(@plot_data_inmemory)
      @plot_data_inmemory.to_png(current, size: [200, 200])
      new_plot.to_png(updated, size: [200, 200])
      expect(same_images?(current, updated)).to be_falsy
    end

    it 'should not create new Plot (and new datablock) if you update data stored in temp file' do
      old = File.join(@tmp_dir, 'old_plot.png')
      current = File.join(@tmp_dir, 'plot.png')
      updated = File.join(@tmp_dir, 'updated_plot.png')
      @plot_data_tempfile.to_png(old, size: [200, 200])
      new_plot = @plot_data_tempfile.update_dataset(data: @data)
      expect(new_plot).to be_equal(@plot_data_tempfile)
      @plot_data_tempfile.to_png(current, size: [200, 200])
      new_plot.to_png(updated, size: [200, 200])
      expect(same_images?(current, updated)).to be_truthy
      expect(same_images?(current, old)).to be_falsy
    end

    it 'should allow to get datasets using []' do
      (0..1).each { |i| expect(@plot_two_ds[i]).to be_equal(@plot_two_ds.datasets[i]) }
      expect(@plot_two_ds[0..-1]).to be_eql(@plot_two_ds.datasets)
    end
  end
end
