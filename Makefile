COQLIB:=$(shell $(COQBIN)coqc -where)/
BACKUPDIR:="user-contrib/tactician-stdlib-backup/"
VFILES:=$(shell cd $(COQLIB) && find theories plugins user-contrib/Ltac2 user-contrib/Tactician -name *.v)
VOFILES:=$(VFILES:=o)
BENCHFILES:=$(VFILES:.v=.bench)

BENCHMARK?=
BENCHMARKSTRING := $(if $(BENCHMARK),Set Tactician Benchmark $(BENCHMARK).,)
BENCHMARKFLAG := $(if $(BENCHMARK),-l Benchmark.v,)

# TODO: This is ugly, but since there are no .mllib source files installed by Coq,
# coqdep cannot find plugin dependencies Therefore, we just have to link all the .cmxs
# files into the build dir.
PLUGINFILES=$(shell cd $(COQLIB) && find plugins user-contrib/Ltac2 -name *.cmxs)
BOOTCOQC=$(COQBIN)coqc -q -coqlib . -I $(COQLIB)user-contrib/Tactician -R $(COQLIB)user-contrib/Tactician Tactician \
         -rifrom Tactician Ltac1.Record

ifeq ($(BENCHMARK),)
all: $(VOFILES)
else
all: $(VOFILES) $(BENCHFILES)
endif

install: backup install-recompiled

backup:
	for f in $(VOFILES); do\
		echo "Backing up $$f";\
		mkdir --parents $(COQLIB)$(BACKUPDIR)$$(dirname $$f);\
		cp $(COQLIB)$$f $(COQLIB)$(BACKUPDIR)$$f;\
	done

install-recompiled:
	for f in $(VOFILES); do\
		echo "Installing $$f";\
		cp $$f $(COQLIB)$$f;\
	done

restore:
	for f in $(VOFILES); do\
		echo "Restoring $$f";\
		cp $(COQLIB)$(BACKUPDIR)$$f $(COQLIB)$$f;\
	done

clean:
	rm -rf theories plugins .vfiles.d Benchmark.v parse_errors.txt bench

theories/Init/%.vo theories/Init/%.glob: theories/Init/%.v $(PLUGINFILES) | .vfiles.d
	@rm -f $*.glob
	@mkdir --parents $(dir theories/Init/$@)
	@echo "coqc theories/Init/$<"
	@$(BOOTCOQC) -noinit -R theories Coq $<

user-contrib/Tactician/%.vo:
	@rm -f $*.glob
	@mkdir --parents $(dir theories/Init/$@)
	@echo "coqc theories/Init/$<"
	@$(COQBIN)coqc -q -coqlib . -I $(COQLIB)user-contrib/Tactician -noinit $<

%.vo %.glob: %.v theories/Init/Prelude.vo $(PLUGINFILES) | .vfiles.d
	@rm -f $*.glob
	@mkdir --parents $(dir $@)
	@echo "coqc $<"
	@$(BOOTCOQC) $<

# We compile a second time in case of benchmarking, for performance reasons (due to improved parallelism)
# This is ugly again, because we need to block coqc from actually writing the .vo file
theories/Init/%.bench: theories/Init/%.v theories/Init/%.vo Benchmark.v
	@echo "coqc benchmark theories/Init/$<"
	@chmod -w $(<:=o)
	@$(BOOTCOQC) $(BENCHMARKFLAG) -noinit -R theories Coq $< 2> /dev/null || true
	@chmod +w $(<:=o)

%.bench: %.v %.vo Benchmark.v
	@echo "coqc benchmark $<"
	@chmod -w $(<:=o)
	@$(BOOTCOQC) $(BENCHMARKFLAG) $< 2> /dev/null || true
	@chmod +w $(<:=o)

%.v %.cmxs:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	@ln -s -T $(COQLIB)$@ $@

theories/Init/Notations.v:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	@cp $(COQLIB)/theories/Init/Notations.v theories/Init/Notations.v
	@echo "Global Set Default Proof Mode \"Tactician Ltac1\"." >> theories/Init/Notations.v

# TODO: Also ugly, see https://github.com/coq/coq/pull/11851
Benchmark.v: force
	@touch -a $@
	@if [ "$$(cat $@)" != "$(BENCHMARKSTRING)" ]; then echo "$(BENCHMARKSTRING)" > $@; fi

.SECONDARY : $(PLUGINFILES)

-include .vfiles.d

# TODO: We have to redirect error, because of https://github.com/coq/coq/issues/11850
TOTARGET = > "$@" 2> /dev/null || (RV=$$?; rm -f "$@"; exit $${RV})

.vfiles.d: $(VFILES)
	@echo "coqdep"
	@$(COQBIN)coqdep -boot -dyndep $(addprefix -I $(COQLIB)plugins/,$(PLUGINS)) $(VFILES) $(TOTARGET)

.PHONY: all clean force
