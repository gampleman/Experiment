= Experiment
* http://github.com/gampleman/experiment

== What's it about?

Experiment is a ruby library and environment for running scientific experiments (eg. AI, GA...), especially good for experiments in optimizing results by variations in algorithm or parameters.

== Installation

    $ sudo gem install experiment

== Getting started

Experiment is modeled after rails and the workflow should be recognizable enough.

First start by generating your project:

    $ experiment new my_project

This will create several files and directories. We will shortly introduce you to these.

First off is the `app` directory. This is where a basic implementation of what you mean to do. You can write your code however you want, just make sure the code is well structured - you will be overriding this later in your experiments.

== Setting up an experiment

Experiments are set up in the experiments directory. The first thing you need to do is define what consist an experiment in your case. For this open up the file `experiments/experiment.rb`. You will notice that this file contains a bunch of comments and a stub letting you easily understand what to do.

For a typical experiment you will need to do some setup work (eg. initialize your classes, calculate parametres, etc.), run the experiment and maybe do cleanup (remove temp. files).

You do all this work in the `run_the_experiment` method. Use the `measure` method to wrap your measurements. These will be autmatically benchmarked and their ouput will be automatically saved to the results directory for further analysis.

The `test_data` method lets you specify an array of data points that you want split for cross-validation (see below). This will be passed to in `run_the_experiment` in the input variable.

Next you may want to analyze the data you got. For that there is the `analyze_result!` method which has 2 arguments. One is the raw data file that was output by your code and the other is the path to an expected output file (this can be very rich in detail, ideal for confusion matrices and the like). The method should return a hash of summary results (eg. `:total_performance => 16`).

All of this will be also saved to disk and available for later analysis.

More info: https://github.com/gampleman/Experiment/wiki/Designing-your-experiment

== Creating an experimental condition

Now to get to making different conditions and measuring them. First call

    $ experiment generate my_condition -m "This should be a description of what you plan to\
     do, maybe including a hypothesis. Don't worry, you can edit this later."
    
This will create a directory in `experiments` based on the name you provide (in this case `experiments/my_condition`). In this directory you will find a class that inherits from the experiment you defined earlier and that it also explicitly requires all the files you wrote in `app`. This gives you the flexibility to delete any of these includes and create a copy of that file to modify it. It also allows you to override the experiment logic as needed.

Also notice that the description you provided is stored as a comment in that file. You can expand your hypothesis as you work on the file and it will be included in your report automatically.

== Running the experiment

Once you make the desired changes you can run the experiment with:

    $ experiment run my_condition --cv 5
    
This will create a directory in `results` named something like `my_condition-cv5-46424`. The naming convention is to give the condition name, a summary of the configuration used, and a shortened timestamp to differentiate reruns of the same experiment.

The experimental results and benchmarks will be written to this directory with a specification yaml file that details all conditions of the experiment.

Please notice that you can provide several different conditions to the run command and it will run them sequentially, all with required options.

More on the Command Line Interface: https://github.com/gampleman/Experiment/wiki/Command-Line-Interface

== Configuration

So far we have been talking mainly about variations in the source code of the experiments. But what if you just want to tweak a few parameters? There is always the almighty *Config* class to the rescue. 

    Experiment::Config[:my_config_variable] # anywhere in your code
    
You have a config directory containing a `config.yaml` file. This file contains several environments. The idea is that you might want to tweak your options differently when running on your laptop then when running on a university supercomputer. Experiments also have their own config file that override the global.

More info: https://github.com/gampleman/Experiment/wiki/Configuration



== Cross Validation

Cross validation (CV) is one of the most crucial research methods in CS and AI. For that reason it is built right in. You specify how many CVs you want to run using the --cv flag and your data is automatically split up for you and the experiment is run for each CV with the appropriate data.

== Reporting Results

    $ experiment report

Surprise, surprise. This will create two files in your `report` directory (BTW, this directory is also meant for you to store your report or paper draft). The first is methods.mmd. This takes all the stuff you wrote in the beginnings of your experimental condition files and creates a multi-markdown (http://fletcherpenney.net/multimarkdown/) file out of them (I chose multi-markdown for it's LaTEX support and also it is directly importable into Scrivener, my writing application of choice, available at http://www.literatureandlatte.com/scrivener.html).  

The second file created is the `data.csv` file which contains the data from all your experiments. It should be importable to Numbers, Excel even Matlab for further analysis and charting.


== Distributed computing support

Newly this library supports a simple distributed model of running experiments. Setup worker computers with the 

    $ experiment worker --address IP_OF_COMPUTER_WHERE_YOU_RUN_EXPERIMENTS
    
and then run experiments with --distributed flag.

More details: https://github.com/gampleman/Experiment/wiki/Distributed-Mode

== Misc

So that's pretty much the gist of experiment. There's a few other features (and a few soon to come to a gem near you ;-) Growl notifications are now supported. Turn them off by setting growl_notifications to false in your config file.

Also check out the RDocs: http://rdoc.info/github/gampleman/Experiment/master/frames