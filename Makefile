COQLIB:=$(shell $(COQBIN)coqc -where)/
BACKUPDIR:="user-contrib/tactician-stdlib-backup/"
VFILES:=$(shell cd $(COQLIB) && find theories plugins user-contrib/Ltac2 -name *.v)
VOFILES:=$(VFILES:=o)
BENCHFILES:=$(VFILES:.v=.bench)

BENCHMARK?=
DETERMINISTIC?=
BENCHMARKSTRING := $(if $(BENCHMARK),Set Tactician Benchmark $(BENCHMARK).,)
BENCHMARKSTRING += $(if $(DETERMINISTIC), Set Tactician Benchmark Deterministic.,)
BENCHMARKFLAG := $(if $(BENCHMARK),-l Benchmark.v,)

ifeq ($(TACTICIANTHEORIES),)
TACTICIANTHEORIES := $(COQLIB)user-contrib/Tactician
endif
ifeq ($(TACTICIANSRC),)
TACTICIANSRC := $(COQLIB)user-contrib/Tactician
endif

# TODO: This is ugly, but since there are no .mllib source files installed by Coq,
# coqdep cannot find plugin dependencies. Therefore, we just have to link all the .cmxs
# files into the build dir.
PLUGINFILES=$(shell cd $(COQLIB) && find plugins user-contrib/Ltac2 user-contrib/Tactician -name *.cmxs)
BOOTCOQC=$(COQBIN)coqc -q -coqlib . -I $(TACTICIANSRC) -R $(TACTICIANTHEORIES) Tactician \
         -rifrom Tactician Ltac1.Record $(FEATFLAG)

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
		cp -p $(COQLIB)$$f $(COQLIB)$(BACKUPDIR)$$f;\
	done

install-recompiled:
	for f in $(VOFILES); do\
		echo "Installing $$f";\
		cp -p $$f $(COQLIB)$$f;\
	done

restore:
	for f in $(VOFILES); do\
		echo "Restoring $$f";\
		cp -p $(COQLIB)$(BACKUPDIR)$$f $(COQLIB)$$f;\
	done

clean:
	rm -rf theories plugins user-contrib .vfiles.d Benchmark.v Features.v .patch
	find . -name *.feat -name *.bench -delete

theories/Init/%.vo theories/Init/%.glob: theories/Init/%.v $(PLUGINFILES) Features.v .patch | .vfiles.d
	@rm -f $*.glob
	@echo "coqc $<"
	@$(BOOTCOQC) -noinit -R theories Coq $<

%.vo %.glob: %.v theories/Init/Prelude.vo $(PLUGINFILES) Features.v .patch | .vfiles.d
	@rm -f $*.glob
	@echo "coqc $<"
	@$(BOOTCOQC) $<

# We compile a second time in case of benchmarking, for performance reasons (due to improved parallelism)
# This is ugly again, because we need to block coqc from actually writing the .vo file
theories/Init/%.bench: theories/Init/%.v theories/Init/%.vo Benchmark.v
	@echo "coqc benchmark $<"
	@chmod -w $(<:=o)
	@$(BOOTCOQC) $(BENCHMARKFLAG) -noinit -R theories Coq $< 2> /dev/null || true
	@chmod +w $(<:=o)

%.bench: %.v %.vo Benchmark.v
	@echo "coqc benchmark $<"
	@chmod -w $(<:=o)
	@$(BOOTCOQC) $(BENCHMARKFLAG) $< 2> /dev/null || true
	@chmod +w $(<:=o)

theories/Init/%.v:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	@cp $(COQLIB)$@ $@

%.v %.cmxs:
	@echo "Linking $@"
	@mkdir --parents $(dir $@)
	@ln -s -T $(COQLIB)$@ $@

# TODO: Also ugly, see https://github.com/coq/coq/pull/11851
Benchmark.v: force
	@touch -a $@
	@if [ "$$(cat $@)" != "$(BENCHMARKSTRING)" ]; then echo "$(BENCHMARKSTRING)" > $@; fi
Features.v: force
	@touch -a $@
	@if [ "$$(cat $@)" != "$(FEATSTRING)" ]; then echo "$(FEATSTRING)" > $@; fi

.SECONDARY : $(PLUGINFILES)

-include .vfiles.d

# TODO: We have to redirect error, because of https://github.com/coq/coq/issues/11850
TOTARGET = > "$@" 2> /dev/null || (RV=$$?; rm -f "$@"; exit $${RV})

USERCONTRIBDIRS:=\
	Ltac2 Tactician
PLUGINDIRS:=\
  omega		micromega \
  ring 	extraction \
  cc 		funind 		firstorder 	derive \
  rtauto 	nsatz           syntax          btauto \
  ssrmatching	ltac		ssr             ssrsearch

.vfiles.d: $(VFILES) $(PLUGINFILES)
	@echo "coqdep"
	@$(COQBIN)coqdep -boot -dyndep no -R theories Coq \
                         -R plugins Coq \
                         -Q user-contrib "" \
                         $(addprefix -I plugins/, $(PLUGINDIRS)) \
                         $(addprefix -I user-contrib/,$(USERCONTRIBDIRS)) \
                         $(VFILES) $(TOTARGET)

.patch: $(VFILES) stdlib-inject.patch
	@echo "patching"
	@git apply stdlib-inject.patch
	@touch .patch

.PHONY: all clean force
