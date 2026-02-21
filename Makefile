# ============================================================================
# CHOMPER - A Pac-Man Clone for the Commodore 64
# Build system using KickAssembler (or ACME as fallback)
# ============================================================================
# Requires: Java Runtime (for KickAssembler) or ACME cross-assembler
#           VICE emulator (optional, for testing)
#           Python 3 + Pillow (optional, for screenshot generation)
# ============================================================================

# Configuration
ASSEMBLER   ?= kickass
KICKASS_JAR ?= KickAss.jar
ACME        ?= acme
VICE        ?= x64sc
PYTHON      ?= python3

# Paths
SRC_DIR     = src
DATA_DIR    = src/data
BUILD_DIR   = build
TOOLS_DIR   = tools
SCREEN_DIR  = screenshots

# Output
PRG_FILE    = $(BUILD_DIR)/chomper.prg
D64_FILE    = $(BUILD_DIR)/chomper.d64

# Source files
MAIN_SRC    = $(SRC_DIR)/main.asm

# ============================================================================
# Targets
# ============================================================================

.PHONY: all clean run screenshots d64 help

all: $(PRG_FILE)

# Build with KickAssembler (preferred)
ifeq ($(ASSEMBLER),kickass)
$(PRG_FILE): $(wildcard $(SRC_DIR)/*.asm) $(wildcard $(DATA_DIR)/*.asm)
	@mkdir -p $(BUILD_DIR)
	java -jar $(KICKASS_JAR) $(MAIN_SRC) -o $(PRG_FILE) -showmem -symbolfile
	@echo "Build complete: $(PRG_FILE)"
endif

# Build with ACME (fallback)
ifeq ($(ASSEMBLER),acme)
$(PRG_FILE): $(wildcard $(SRC_DIR)/*.asm) $(wildcard $(DATA_DIR)/*.asm)
	@mkdir -p $(BUILD_DIR)
	$(ACME) -f cbm -o $(PRG_FILE) $(MAIN_SRC)
	@echo "Build complete: $(PRG_FILE)"
endif

# Create D64 disk image
d64: $(PRG_FILE)
	c1541 -format "chomper,ch" d64 $(D64_FILE) -attach $(D64_FILE) -write $(PRG_FILE) "chomper"
	@echo "Disk image created: $(D64_FILE)"

# Run in VICE emulator
run: $(PRG_FILE)
	$(VICE) -autostart $(PRG_FILE)

# Generate screenshot mockups
screenshots:
	$(PYTHON) $(TOOLS_DIR)/generate_screenshots.py

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*

# Help
help:
	@echo "CHOMPER - C64 Pac-Man Clone Build System"
	@echo "========================================="
	@echo "  make            - Build the game (PRG)"
	@echo "  make d64        - Create D64 disk image"
	@echo "  make run        - Build and run in VICE"
	@echo "  make screenshots- Generate screen mockups"
	@echo "  make clean      - Clean build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  ASSEMBLER=kickass|acme  (default: kickass)"
	@echo "  KICKASS_JAR=path        (default: KickAss.jar)"
	@echo "  VICE=path               (default: x64sc)"
