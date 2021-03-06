require 'benchmark'

class TourBus < Monitor
  attr_reader :host, :concurrency, :number, :tour_names, :tours, :runs, :tests, :passes, :fails, :errors, :benchmarks
  
  def initialize(host="localhost", concurrency=1, number=1, tour_names=[], test_list=nil)
    @host, @concurrency, @number, @tour_names, @test_list = host, concurrency, number, tour_names, test_list
    @runner_id = 0
    @runs, @tests, @passes, @fails, @errors = 0,0,0,0,0
    @tours = []
    super()
  end
  
  def next_runner_id
    synchronize do
      @runner_id += 1
    end 
  end
  
  def update_stats(runs,tests,passes,fails,errors)
    synchronize do
      @runs += runs
      @tests += tests
      @passes += passes
      @fails += fails
      @errors += errors
    end
  end
  
  def update_benchmarks(bm)
    synchronize do
      @benchmarks = @benchmarks.zip(bm).map { |a,b| a+b}
    end 
  end
  
  def runners(filter=[])
    # All files in tours folder, stripped to basename, that match any item in filter
    Dir[File.join('.', 'tours', '**', '*.rb')].map {|fn| File.basename(fn, ".rb")}.select {|fn| filter.size.zero? || filter.any?{|f| fn =~ /#{f}/}}
  end
  
  def total_runs
    tour_names.size * concurrency * number    
  end
  
  def run
    threads = []
    threads_ready = 0
    start_running = false
    mutex = Mutex.new
    tour_name = "#{total_runs} runs: #{concurrency}x#{number} of #{tour_names * ','}"
    progress_bar = CommandLine::ProgressBar.new(tour_name, (number * concurrency) + concurrency, STDOUT)
    progress_bar.inc

    started = Time.now.to_f
    

    
    concurrency.times do |conc|
      #log "Starting #{tour_name}"
      threads << Thread.new do
        runner_id = next_runner_id
        mutex.lock
        threads_ready += 1
        if threads_ready == concurrency
          #log "All Runners are ready -- STARTING!"
          start_running = true
        end
        
        mutex.unlock
        sleep 0.05 until start_running
        runs,tests,passes,fails,errors,start,local_tours = 0,0,0,0,0,Time.now.to_f, []
        bm = Benchmark.measure do
          runner = Runner.new(@host, @tour_names, @number, runner_id, @test_list, progress_bar)
          runs,tests,passes,fails,errors,local_tours = runner.run_tours
          update_stats runs, tests, passes, fails, errors
          @tours += local_tours
        end
        #log "Runner Finished!"
        #log "Runner finished in %0.3f seconds" % (Time.now.to_f - start)
        #log "Runner Finished! runs,passes,fails,errors: #{runs},#{passes},#{fails},#{errors}"
        #log "Benchmark for runner #{runner_id}: #{bm}"
        
      end
    end
    #log "Initializing #{concurrency} Runners..."
    threads.each {|t| t.join }
    finished = Time.now.to_f

    progress_bar.finish


    #
    # Post process the tour data into metrics
    #
    codes = {}
    resp_times = {}
    @tours.each do |t|

      t.requests.each_with_index do |r, i|
        resp_times[r] ||= [0, 0] # [total, count]
        resp_times[r][1] = resp_times[r][1] + 1
        resp_times[r][0] = resp_times[r][0] + t.response_times[i]
      end

      t.response_headers.each_with_index do |h, i|
        if !h['status'].nil?
          codes[h['status']] ||= 0
          codes[h['status']] = codes[h['status']] + 1
        end
      end
    end

    #Response Times
    response_times_table = Output::FixedWidth.new(STDOUT, { :color => true })
    response_times_table.title("Response Times by URL")

    total_response_times = resp_times.inject(0) {|result, element| result + element.last.first}
    
    response_times_table.table({}, {:align => :right}, {:type => :ratio, :width => :rest, :treshold => 0.15}) do |rows|
      resp_times.each do |rt|
        ratio = rt.last.first.to_f / total_response_times.to_f
        rows << [rt.first, "%f s avg. resp. time." % (rt.last.first.to_f / rt.last.last.to_f).round(3), ratio]
      end
    end
        

    # Header Types
    header_table = Output::FixedWidth.new(STDOUT, { :color => true })
    header_table.title("Response HTTP Status Codes")

    total_response_codes = codes.inject(0) {|result, element| result + element.last}
    
    header_table.table({}, {:align => :right}, {:type => :ratio, :width => :rest, :treshold => 0.15}) do |rows|
      codes.each do |c|
        ratio = c.last.to_f / total_response_codes.to_f
        rows << [c.first, "%d occurances." % c.last, ratio]
      end
    end

    # Closing Stats
    error_color = @errors < 1 ? :green : :red
    fail_color = @fails < 1 ? :green : :red
    log '-' * 80
    log tour_name
    log "All Runners finished."
    log "Total Tours: #{@runs}"
    log "Total Tests: #{@tests}"
    log "Total Passes: #{@passes}", :green
    log "Total Fails: #{@fails}", fail_color
    log "Total Errors: #{@errors}", error_color
    log "Elapsed Time: #{finished - started}", :yellow
    log "Speed: %5.3f tours/sec" % (@runs / (finished-started))
    log '-' * 80
    if @fails > 0 || @errors > 0
      log '********************************************************************************', :red
      log '********************************************************************************', :red
      log '                            !! THERE WERE FAILURES !!', 'red'
      log '********************************************************************************', :red
      log '********************************************************************************', :red
    end
  end
  
  def log(message, color = :white)
    puts Output::Color.colorize(message, color)
    #puts "#{Time.now.strftime('%F %H:%M:%S')} TourBus: #{message}"
  end

end

