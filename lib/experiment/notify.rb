require "drb/drb"
module Experiment
  # This class is responsible for UI goodness in letting you know 
  # about the progress of your experiments
  # @private
  class Notify
  
    class << self
      include DRb::DRbUndumped

      # initialize display
      def init(total, out = STDERR, growl = true, mode = :normal)
        @curent_experiment = ""
        @current_cv = 0
        @cv_prog = {}
        @total = total
        @out = out
        @terminal_width = 80
        @bar_mark = "o"
        @current = 0
        @previous = 0
        @finished_p = false
        @start_time = Time.now
        @previous_time = @start_time
        @growl = growl
        @mode = mode
        show if @mode == :normal && @out
      end
    
      # Called when starting work on a particular experiment
      def started(experiment)
        @curent_experiment = experiment
        @current_cv = 1
        @cv_prog[experiment] = []
        show_if_needed
      end
    
      # Called when experiment completed. 
      # Shows a Growl notification on OSX.
      # The message can be expanded by overriding the result_line 
      # method in the experiment class
      def completed(experiment, msg = "")
        if @growl
          begin
            `G_TITLE="Experiment Complete" #{File.dirname(__FILE__)}/../../bin/growl.sh -nosticky "Experimental condition #{experiment} complete. #{msg}"`
          rescue
            # probably not on OSX
          end
        end
        m = "Condition #{experiment} complete. #{msg}"
        puts m + " " * @terminal_width
        @curent_experiment = nil
      end
    
      # called after a crossvalidation has completed
      def cv_done(experiment, num)
        @cv_prog[experiment][num] ||= 0
        inc(1 - @cv_prog[experiment][num])
        #@cv_prog = 0
      end
    
      # Wrap up
      def done
        @current = @total
        @finished_p = true
        #show
      end
    
      # Use this in experiment after each (potentially time consuming) task
      # The argument should be a fraction (0 < num < 1) which tells 
      # how big a portion the task was of the complete run (eg. your 
      # calls should sum up to 1).
      def step(experiment, cv, num)
        if @mode == :normal
          if num > 1
            num = num / 100
          end
          inc(num)
          @cv_prog[experiment][cv] ||= 0
          @cv_prog[experiment][cv] += num
        else
          @mode.notify.step(experiment, cv, num)
        end
      end
    
    end
  
    # a big part of this module is copied/inspired by Satoru Takabayashi's <satoru@namazu.org> ProgressBar class at http://0xcc.net/ruby-progressbar/index.html.en
    module ProgressBar #:nodoc
      def inc(step = 1)
        @current += step
        @current = @total if @current > @total
        show_if_needed
        @previous = @current
      end
    
      def show_if_needed
        return unless @out
        if @total.zero?
          cur_percentage = 100
          prev_percentage = 0
        else
          cur_percentage  = (@current  * 100 / @total).to_i
          prev_percentage = (@previous * 100 / @total).to_i
        end
        @finished_p = cur_percentage == 100
        # Use "!=" instead of ">" to support negative changes
        if cur_percentage != prev_percentage || 
            Time.now - @previous_time >= 1 || @finished_p
          show
        end
      end
    
    
    
      def show
        percent = @current  * 100.0 / @total
        bar_width = percent * @terminal_width / 100.0
        line = sprintf "%3d%% |%s%s| %s", percent, "=" * bar_width.floor, "-" * (@terminal_width - bar_width.ceil), stat
      

        #width = get_width
        #if line.length == width - 1 
          @out.print(line +  (@finished_p ? "\n" : "\r"))
          @out.flush
        #elsif line.length >= width
        #  @terminal_width = [@terminal_width - (line.length - width + 1), 0].max
        #  if @terminal_width == 0 then @out.print(line + (@finished_p ? "\n" : "\r")) else show end
        #else # line.length < width - 1
        #  @terminal_width += width - line.length + 1
        #  show
        #end
        @previous_time = Time.now
      end
    
      def stat
        if @finished_p then elapsed else eta end
      end
    
      def eta
        if @current == 0
          "ETA:  --:--:--"
        else
          elapsed = Time.now - @start_time
          eta = elapsed * @total / @current - elapsed;
          sprintf("ETA:  %s", format_time(eta))
        end
      end

      def elapsed
        elapsed = Time.now - @start_time
        sprintf("Time: %s", format_time(elapsed))
      end
    
      def format_time (t)
        t = t.to_i
        sec = t % 60
        min  = (t / 60) % 60
        hour = t / 3600
        sprintf("%02d:%02d:%02d", hour, min, sec);
      end
    
    
      def get_width
         # FIXME: I don't know how portable it is.
         default_width = 80
         begin
           tiocgwinsz = 0x5413
           data = [0, 0, 0, 0].pack("SSSS")
           if @out.ioctl(tiocgwinsz, data) >= 0 then
             rows, cols, xpixels, ypixels = data.unpack("SSSS")
             if cols >= 0 then cols else default_width end
           else
             default_width
           end
         rescue Exception
           default_width
         end
       end
    end
  
    extend ProgressBar
  
  end
end