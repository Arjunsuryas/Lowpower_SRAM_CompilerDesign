# Makefile for Low Power SRAM Compiler

# Python interpreter
PYTHON = python3

# Directories
SRC_DIR = src
CONFIG_DIR = config
OUTPUT_DIR = output
SCRIPTS_DIR = scripts
VERIFICATION_DIR = verification

# Default configuration
DEFAULT_CONFIG = small_cache

# Phony targets
.PHONY: all clean help compile analyze verify compare list-configs

# Default target
all: compile analyze

# Help target
help:
	@echo "Low Power SRAM Compiler Makefile"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  compile CONFIG=<name>    - Compile SRAM with specified configuration"
	@echo "  analyze CONFIG=<name>    - Run power and area analysis"
	@echo "  verify                   - Run verification testbench"
	@echo "  compare CONFIGS='c1 c2'  - Compare multiple configurations"
	@echo "  list-configs             - List available configurations"
	@echo "  clean                    - Clean output files"
	@echo "  help                     - Show this help"
	@echo ""
	@echo "Configuration options:"
	@echo "  small_cache              - Small cache memory (1KB, 2 banks)"
	@echo "  large_memory             - Large memory (1MB, 8 banks)"
	@echo "  ultra_low_power          - Ultra low power (512B, 1 bank)"
	@echo "  high_performance         - High performance (512KB, 16 banks)"
	@echo ""
	@echo "Examples:"
	@echo "  make compile CONFIG=small_cache"
	@echo "  make analyze CONFIG=ultra_low_power"
	@echo "  make compare CONFIGS='small_cache large_memory'"

# Compile SRAM
compile:
	@echo "Compiling SRAM with configuration: $(CONFIG)"
	$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
		--config $(or $(CONFIG),$(DEFAULT_CONFIG)) \
		--output $(OUTPUT_DIR)/$(or $(CONFIG),$(DEFAULT_CONFIG)) \
		--generate-verilog

# Run analysis
analyze:
	@echo "Running analysis for configuration: $(CONFIG)"
	$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
		--config $(or $(CONFIG),$(DEFAULT_CONFIG)) \
		--output $(OUTPUT_DIR)/$(or $(CONFIG),$(DEFAULT_CONFIG)) \
		--power-analysis \
		--area-analysis

# Full compilation with analysis
full: compile analyze

# Compare configurations
compare:
	@echo "Comparing configurations: $(CONFIGS)"
	$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
		--compare $(CONFIGS) \
		--output $(OUTPUT_DIR)/comparison

# List available configurations
list-configs:
	$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py --list-configs

# Run verification
verify:
	@echo "Running SRAM verification..."
	@if command -v vsim >/dev/null 2>&1; then \
		cd $(VERIFICATION_DIR) && \
		vlog sram_tb.sv && \
		vsim -c -do "run -all; quit\" sram_tb; \
	else \
		echo "ModelSim/QuestaSim not found. Verification requires simulator."; \
		echo "RTL files are available for manual verification."; \
	fi

# Generate documentation
docs:
	@echo "Generating documentation..."
	@mkdir -p $(OUTPUT_DIR)/docs
	@echo "# SRAM Compiler Documentation" > $(OUTPUT_DIR)/docs/README.md
	@echo "" >> $(OUTPUT_DIR)/docs/README.md
	@echo "This directory contains generated SRAM designs and analysis reports." >> $(OUTPUT_DIR)/docs/README.md
	@echo "" >> $(OUTPUT_DIR)/docs/README.md
	@echo "## Available Configurations" >> $(OUTPUT_DIR)/docs/README.md
	@$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py --list-configs >> $(OUTPUT_DIR)/docs/README.md

# Power analysis for all configurations
power-sweep:
	@echo "Running power analysis sweep..."
	@for config in small_cache large_memory ultra_low_power high_performance; do \
		echo "Analyzing $$config..."; \
		$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
			--config $$config \
			--output $(OUTPUT_DIR)/$$config \
			--power-analysis; \
	done

# Area analysis for all configurations
area-sweep:
	@echo "Running area analysis sweep..."
	@for config in small_cache large_memory ultra_low_power high_performance; do \
		echo "Analyzing $$config..."; \
		$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
			--config $$config \
			--output $(OUTPUT_DIR)/$$config \
			--area-analysis; \
	done

# Generate all configurations
generate-all:
	@echo "Generating all SRAM configurations..."
	@for config in small_cache large_memory ultra_low_power high_performance; do \
		echo "Generating $$config..."; \
		$(PYTHON) $(SCRIPTS_DIR)/compile_sram.py \
			--config $$config \
			--output $(OUTPUT_DIR)/$$config \
			--generate-verilog \
			--power-analysis \
			--area-analysis; \
	done

# Technology scaling analysis
tech-scaling:
	@echo "Running technology scaling analysis..."
	@mkdir -p $(OUTPUT_DIR)/tech_scaling
	@echo "Technology scaling analysis requires custom configuration files"
	@echo "See config/sram_configs.json for technology node parameters"

# Clean output files
clean:
	@echo "Cleaning output files..."
	rm -rf $(OUTPUT_DIR)/*
	rm -rf work/
	rm -f transcript
	rm -f modelsim.ini
	rm -f *.log
	rm -f *.wlf

# Install dependencies
install-deps:
	@echo "Installing Python dependencies..."
	pip3 install --user numpy matplotlib pandas

# Lint Python code
lint:
	@echo "Linting Python code..."
	@if command -v pylint >/dev/null 2>&1; then \
		pylint $(SRC_DIR)/compiler/*.py $(SCRIPTS_DIR)/*.py; \
	else \
		echo "pylint not found. Install with: pip3 install pylint"; \
	fi

# Format Python code
format:
	@echo "Formatting Python code..."
	@if command -v black >/dev/null 2>&1; then \
		black $(SRC_DIR)/compiler/*.py $(SCRIPTS_DIR)/*.py; \
	else \
		echo "black not found. Install with: pip3 install black"; \
	fi

# Run tests
test: verify
	@echo "Running Python unit tests..."
	@if [ -d "tests" ]; then \
		$(PYTHON) -m pytest tests/; \
	else \
		echo "No Python tests found. Verification testbench completed."; \
	fi

# Package for distribution
package:
	@echo "Creating distribution package..."
	@mkdir -p $(OUTPUT_DIR)/package
	@tar -czf $(OUTPUT_DIR)/package/sram_compiler.tar.gz \
		$(SRC_DIR)/ $(CONFIG_DIR)/ $(SCRIPTS_DIR)/ $(VERIFICATION_DIR)/ \
		Makefile README.md
	@echo "Package created: $(OUTPUT_DIR)/package/sram_compiler.tar.gz"

# Show statistics
stats:
	@echo "SRAM Compiler Statistics"
	@echo "======================="
	@echo "Python files: $$(find $(SRC_DIR) -name '*.py' | wc -l)"
	@echo "Verilog files: $$(find $(SRC_DIR) -name '*.v' -o -name '*.sv' | wc -l)"
	@echo "Configuration files: $$(find $(CONFIG_DIR) -name '*.json' | wc -l)"
	@echo "Total lines of code: $$(find $(SRC_DIR) $(SCRIPTS_DIR) -name '*.py' -exec wc -l {} + | tail -1 | awk '{print $$1}')"
