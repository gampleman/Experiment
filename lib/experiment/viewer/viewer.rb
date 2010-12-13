begin
  require 'sinatra'
rescue Exception => e
  abort "Sinatra gem required. Run `gem install sinatra` and try again"
end
require 'erb'
require 'yaml'
require File.dirname(__FILE__) + "/../stats/descriptive"

module Experiment
  # @private
  module Viewer
    # This is used solely for the purpose of the webapp in {Runner#view}.
    # It has nothing to do with actual results.
    # @private
    class Result

      attr_reader :valid, :name

      def initialize(name)
        @name = name
        @files = Dir["./results/#{name}/*"].map {|f| File.basename(f) }
        @valid = @files.include?("performance_table.txt") && 
          @files.include?("specification.yaml") &&
          @files.include?("summary.mmd") &&
          @files.include?("results.yaml")
      end

      def spec
        return unless @files.include?("specification.yaml")
        YAML::load_file("./results/#{name}/specification.yaml")
      end

      def results
        return unless @files.include?("results.yaml")
        res = YAML::load_file("./results/#{name}/results.yaml")
        stats = []
        res.each do |k,v|
          if v.all? {|a| a.is_a? Numeric }
            stats << {"Mean" => Experiment::Stats::mean(v), "Std Deviation" => Experiment::Stats::standard_deviation(v)}
          end
        end
        {:res => res, :stats => stats}
      end

      def error
        "<h2>Experiment ended with exception</h2><pre>#{File.read("./results/#{name}/error.log")}</pre>" if @files.include?("error.log")
      end
      
      def performance
        return unless @files.include?("performance_table.txt")
        File.read("./results/#{name}/performance_table.txt")
      end
      
    end
    
  end
end

# @private
helpers do
  def tabulate(hash)
    out = "<table>"
    hash.each do |k,v|
      out << "<tr><th>#{k}</th><td>#{yield(k, v)}</td></tr>"
    end
    out << "</table>"
    out
  end
end
# @private
get '/' do
  red = Dir["./results/*/*"].first 
  redirect '/' + File.basename(File.dirname(red))
end
# @private
get '/:name' do
  @experiments = Dir["./results/*/*"].map{|a| File.basename(File.dirname(a)) }.uniq.map {|f| Experiment::Viewer::Result.new f }
  @experiment = Experiment::Viewer::Result.new(params[:name])
  erb :show
end
# @private
get '/destroy/:name' do
  FileUtils.rm_r "./results/#{params[:name]}"
  redirect '/'
end

__END__

@@ show

<!DOCTYPE html>
<html>
<head>
    <title>Experiment result viewer - <%= @experiment.name%></title>
    <style type="text/css">
    * { padding: 0; margin: 0; }
    body {
        font-family: Helvetica, sans-serif;
        display: -webkit-box;
        -webkit-box-orient: horizontal;
        -webkit-box-direction: reverse;
        -webkit-box-pack: start;
        
        text-shadow: 0 -1px 0 rgba(255,255,255,0.2);
    }
    article { 
      -webkit-box-flex: 1; 
      background-image: 
        -webkit-gradient(radial, 50% 0, 0, 50% 150, 200,
          color-stop(0.0, rgba(200,200,200, 0.1)),
          color-stop(1.0, rgba(200,200,200, 1))
        ),
        -webkit-gradient(linear, 0% 0%, 60% 650,
          color-stop(0.3999, rgba(230,230,230, 1)),
          color-stop(0.4, rgba(200,200,200, 1))
        );
    } 
    nav ul li { list-style-type: none; }
    nav {  
      -webkit-box-shadow: 1px 0 5px rgba(0,0,0,0.2);
      background: rgba(120, 120, 120, 1);
   }
    nav a {
        display: block;
        padding: 4px 20px 4px 10px;
        text-decoration: none;
        color: rgba(255, 255, 255, 0.9);
        text-shadow: 0 1px 0 rgba(0, 0, 0, 0.9);
        border-top: 1px solid rgba(100, 100, 150, 0.9);
        background: -webkit-gradient(linear, center top, center bottom, color-stop(0.0, rgba(140, 140, 140, 1)), color-stop(1.0, rgba(130, 130, 130, 1)));
    }
    nav a:before {
        content: "!";
        color: red;
        display: inline-block;
        margin-right: 3px;
    }
    nav a.ok:before {
        content: "";
    }
    nav a:visited {
        color: rgba(220, 220, 220, 0.9);
    }
    nav a:hover {
        background: -webkit-gradient(linear, center top, center bottom, color-stop(0.0, rgba(190, 190, 200, 1)), color-stop(1.0, rgba(140, 140, 150, 1)));
    }
    h1 {
        background: -webkit-gradient(linear, center top, center bottom, color-stop(0.0, #222d41), color-stop(1.0, rgba(21,26,36,0.9))); /*#151a24*/
        padding: 15px;
        color: white;
        -webkit-box-shadow: 0 1px 0 rgba(255,255,255,0.2), 0 1px 10px rgba(255,255,255,0.8);
    }
    h1 span {
        background: -webkit-gradient(linear, center top, center bottom, color-stop(0.0, #fff), color-stop(1.0, rgb(200,200,200)));
        -webkit-background-clip: text;
        display: block;
        color: transparent; 
    }
    h2, p { margin: 20px; }
    article>h1+p>a {
        color: red;
        position: absolute;
        text-shadow: 0 1px 0 rgba(0,0,0,0.4);
        top: 25px;
        right: 10px;
    }
    article>table { margin: 20px; }
    table, tr, td, th {
        border: 1px solid black;
        border-collapse: collapse;
        padding: 3px;
    }
    table table { border: none; }
    tbody th, tfoot th { text-align: right; }
    tfoot { border-top: 2px solid black; }
    thead { border-bottom: 2px solid black; }
    pre {
        overflow: auto;
        white-space: pre-wrap;
        margin: 20px;
        border: 1px solid rgba(0,0,0,0.3);
        background: rgba(0,0,0,0.1);
        padding: 5px;
    }
    #retest {
      /*display:none;*/
      height: 0;
      overflow: hidden;
      -webkit-transition: height 0.5s;

    }
    #retest:target {
      display: block;
      height: 160px;
    }
    </style>
</head>
<body>
    
<article>
    <h1><span><%= @experiment.name %></span></h1>
    <p><a href="/destroy/<%= @experiment.name %>" onclick="return confirm('Are you sure?')">Delete this result</a></p>
    
    <% if spec = @experiment.spec %>
    <h2>Specification</h2>
    <p><a href="#retest">Retest</a></p>
    <%= tabulate(spec) { |k,v| k == :configuration ? tabulate(v){|k,v| v } : v.inspect }%>
    
    <section id="retest">
      <h2>Retest</h2>
      <pre>
experiment run <%=spec[:name]%> --cv <%=spec[:cross_validations]%> <%spec[:configuration].each do |k,v|%>--<%=k%> <%=v.inspect%> <%end%>
      </pre>
    </section>
    
    <% end %>

    <% if results = @experiment.results %>
    <h2>Results</h2>
    <table>
        <thead>
            <tr>
                <th>Cross validation</th>
                <% results[:res].keys.each do |header| %>
                    <th><%= header %></th>
                <% end %>
            </tr>
        </thead>
        <tbody>
            <% results[:res].values.transpose.each_with_index do |row, i| %>
            <tr>
                <td><%= i+1 %></td>
                <% row.each do |cell| %>
                <td><%= cell.is_a?(Numeric) ? sprintf("%.3f", cell) : cell %></td>
                <% end %>
            </tr>
            <% end %>
        </tbody>
        <tfoot>
            <tr>
                <th>Mean</th>
                <% results[:stats].each do |s| %>
                    <td><%=  sprintf "%.3f", s["Mean"]%></td>
                <%end%>
            </tr>
            <tr>
                <th>Std Deviation</th>
                <% results[:stats].each do |s| %>
                    <td><%=  sprintf "%.3f", s["Std Deviation"]%></td>
                <%end%>
            </tr>
        </tfoot>
    </table>
    <% end %>
    <%= @experiment.error %>
    <% if perf = @experiment.performance %>
    <h2>Performance table</h2>
    <pre>
<%=perf%>
    </pre>
    <%end%>
</article>
<nav>
    <ul>
    <% @experiments.each do |exp| %>
        <li>
            <a href="/<%=exp.name%>" <%= "class=ok" if exp.valid %>><%= exp.name %></a>
        </li>
    <% end %>
    </ul>
</nav>
</body>
</html>