class MyExperiment < Experiment::Base
  
  def run_the_experiment(output)
    # TODO: Define how you will run the experiment
    # Remeber, each seperate experiment inherits from this base class and includes
    # it's own files, so this should be a rather generic implementation
    
    # 1. prepare any nessecary setup like I/O lists, etc...
    
    # 2. do the experiment
    benchmark do
      output << # run your code here
    end
    
    # 3. clean up
    
  end
  
  def analyze_result!(input, output)
    # TODO perform an analysis of what your program did
    
    # remember to return a hash of meaningful data, best of all a summary
  end
  
  # you might want to override this method as well:
  # def summarize_results!(results)
  #   super(results)
  # end
  
end