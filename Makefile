# Run from Linux/WSL after `igny init`. The lock selects the default environment.
IGNY ?= igny
IGNY_ENV ?= default
IGNY_RUN = $(IGNY) run --env $(IGNY_ENV)
MODEL := output/apb3uart/verilated
WAVE := output/waves/cosim.vcd

.DEFAULT_GOAL := help
.PHONY: help preflight sed build run sim smoke waves clean

help:
	@echo "igny run make sed    - convert shell/configuration line endings to LF"
	@echo "igny run make build  - build the current DPI UART model with VCD support"
	@echo "igny run make run    - run the checked co-simulation and record $(WAVE)"
	@echo "igny run make smoke  - run the 14 readbacks and both rejection controls"
	@echo "igny run make waves  - open an existing waveform with Crucible-managed GTKWave"
	@echo "igny run make clean  - remove generated output/; preserve sources and tool installs"

preflight:
	@command -v $(IGNY) >/dev/null 2>&1 || { echo "Enter Crucible first: igny init"; exit 1; }

sed:
	sed -i 's/\r$$//' scripts/*.sh upstream.env

build: sed preflight
	$(IGNY_RUN) ./scripts/build.sh

run sim: sed preflight
	@test -x "$(MODEL)" || { echo "Build the model first: igny run make build"; exit 1; }
	@mkdir -p output/waves
	@rm -f "$(WAVE)"
	COSIM_TRACE_FILE="$(abspath $(WAVE))" $(IGNY_RUN) ./scripts/smoke.sh
	python3 scripts/check_waveform.py "$(WAVE)"

smoke: sed preflight
	$(IGNY_RUN) ./scripts/smoke.sh

waves: preflight
	@test -s "$(WAVE)" || { echo "Generate the waveform first: igny run make run"; exit 1; }
	@echo "Opening $(abspath $(WAVE))"
	$(IGNY_RUN) gtkwave "$(abspath $(WAVE))"

clean:
	python3 scripts/clean.py
