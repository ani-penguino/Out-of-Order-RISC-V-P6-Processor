This is the repository for your implementation of an out-of-order,
synthesizable, RISC-V processor with advanced features.

See the [Project Specification](https://drive.google.com/file/d/1z8MC70pnj0iMrgUmu1rYOlS5uGNltmwG/view?usp=drive_link)
for more details on deadlines and the overall structure of the project.

- Running `make simv` will compile a simulation executable for your
  processor

- Running `make syn_simv` will compile a synthesis executable for your
  processor

- Running `./simv +MEMORY=program.mem` (or `./syn_simv`) will run the
  processory with the given program and output the `@@@` memory values.
  
``` make
# ---- Module Testbenches ---- #
# NOTE: these require files like: 'verilog/rob.sv' and 'test/rob_test.sv'
#       which implement and test the module: 'rob'
make <module>.pass   <- greps for "@@@ Passed" or "@@@ Incorrect" in the output
make <module>.out    <- run the testbench (via <module>.simv)
make <module>.simv   <- compile the testbench executable
make <module>.verdi  <- run in verdi (via <module>.simv)
make <module>.syn.pass   <- greps for "@@@ Passed" or "@@@ Incorrect" in the output
make <module>.syn.out    <- run the synthesized module on the testbench
make <module>.syn.simv   <- compile the synthesized module with the testbench
make synth/<module>.vg   <- synthesize the module
make <module>.syn.verdi  <- run in verdi (via <module>.syn.simv)

# ---- module testbench coverage ---- #
make <module>.coverage    <- print the coverage hierarchy report to the terminal
make <module>.cov.verdi   <- open the coverage report in verdi
make <module>.cov         <- compiles a coverage executable for the module and testbench
make <module>.cov.vdb     <- runs the executable and creates the <module>.cov.vdb directory
make <module>_cov_report  <- run urg to create human readable coverage reports
```

### Pipeline Files

The two files `verilog/pipeline.sv` and `test/pipeline_test.sv` have
been edited to comment-out or remove project 3 specific code, so you
should be able to re-use them when you want to start integrating your
modules into a full processor again.

We've added an `icache` module in `verilog/icache.sv`. That file has
more comments explaining how it works, but the idea is it stores
memory's response tag until memory returns that tag with the data. More
about how our processor's memory works will be presented in the final
lab section.

The file `psel_gen.sv` implements an incredibly efficient parameterized
priority selector (remember project 1?!). many tasks in superscalar
processors come down to priority selection, so instead of writing
manual for-loops, try to use this module. It is faster than any
priority selector the instructors are aware of (as far as my last
conversation about it with Brehob).

The following Makefile rules are available to run programs on the
processor:

``` make
# ---- Program Execution ---- #
# These are your main commands for running programs and generating output
make <my_program>.out      <- run a program on simv
                              generate *.out, *.wb, and *.ppln files in 'output/'
make <my_program>.syn.out  <- run a program on syn_simv and do the same

# ---- Executable Compilation ---- #
make simv      <- compiles simv from the TESTBENCH and SOURCES
make syn_simv  <- compiles syn_simv from TESTBENCH and SYNTH_FILES
make *.vg      <- synthesize modules in SOURCES for use in syn_simv
make slack     <- grep the slack status of any synthesized modules

# ---- Program Memory Compilation ---- #
# Programs to run are in the programs/ directory
make programs/<my_program>.mem  <- compile a program to a RISC-V memory file
make compile_all                <- compile every program at once (in parallel with -j)

# ---- Dump Files ---- #
make <my_program>.dump  <- disassembles compiled memory into RISC-V assembly dump files
make *.debug.dump       <- for a .c program, creates dump files with a debug flag
make dump_all           <- create all dump files at once (in parallel with -j)

# ---- Verdi ---- #
make <my_program>.verdi     <- run a program in verdi via simv
make <my_program>.syn.verdi <- run a program in verdi via syn_simv

# ---- Visual Debugger ---- #
make <my_program>.vis  <- run a program on the project 3 vtuber visual debugger!
make vis_simv          <- compile the vtuber executable from VTUBER and SOURCES

# ---- Cleanup ---- #
make clean            <- remove per-run files and compiled executable files
make nuke             <- remove all files created from make rules
```
