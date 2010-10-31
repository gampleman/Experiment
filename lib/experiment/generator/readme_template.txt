This project has a slightly complex structure which is though beneficial for automating
many mundane tasks. So a brief description of the files/folders included:

app
 - Contains the base implementation.
config
 - Configuration for running in different environments.
doc
 - Documentation for the reference implementation.
experiments
 - This directory includes all experiments that were coded. They generally `require` 
   files from the reference implementation and add modifications of there own. 
   Each is explained in its `about.md` file.
report
 - Source files used to create the report (multi-markdown format, see http://fletcherpenney.net/multimarkdown).
results
 - Has all the measurements from individual experiments. Naming convention: 
   {name}-{classes}-cv{number of cross validations}-{shortened timestamp}.
test
 - Unit tests.
tmp
 - Various stuff stored here. Ignore.
vendor
 - Library code and scripts not written by me.
