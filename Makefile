# --- tp3-sdc/Makefile ---
# Tools
ASM=nasm
QEMU=qemu-system-i386 # Emulator for Happy Path
BOCHS=bochs           # Emulator for Bad Path
BUILD_DIR=build

# Source Files
SRC_HAPPY=src/boot_happy_path.asm
SRC_BAD=src/boot_bad_path.asm

# Output Files
IMG_HAPPY=$(BUILD_DIR)/boot_happy_path.img
LST_HAPPY=$(BUILD_DIR)/boot_happy_path.lst
IMG_BAD=$(BUILD_DIR)/boot_bad_path.img
LST_BAD=$(BUILD_DIR)/boot_bad_path.lst

# Bochs Configuration File (Only needed for Bad Path)
BOCHSRC_BAD=bochsrc_bad.txt

# Assembler Flags: -f bin for flat binary output
ASMFLAGS = -f bin

# QEMU Flags (for Happy Path)
QEMUFLAGS_BASE = -fda # Use image as floppy drive A
QEMUFLAGS_DEBUG = -S -gdb tcp::1234 # Halt CPU at start (-S), enable GDB server

# Bochs Flags are specified via the config file

# Phony Targets (not actual files)
.PHONY: all clean run run-bad debug debug-bad happy bad check-bochsrc

# Default target: build both images
all: happy bad

# Build targets
happy: $(IMG_HAPPY)
bad: $(IMG_BAD)

# Rule to assemble Happy Path source
$(IMG_HAPPY): $(SRC_HAPPY) | $(BUILD_DIR)
	@echo "Assembling $(SRC_HAPPY) -> $@"
	@$(ASM) $(ASMFLAGS) $< -o $@ -l $(LST_HAPPY)
	@echo "Created $(LST_HAPPY)"

# Rule to assemble Bad Path source
$(IMG_BAD): $(SRC_BAD) | $(BUILD_DIR)
	@echo "Assembling $(SRC_BAD) -> $@"
	@$(ASM) $(ASMFLAGS) $< -o $@ -l $(LST_BAD)
	@echo "Created $(LST_BAD)"

# Create the build directory if it doesn't exist
$(BUILD_DIR):
	@echo "Creating build directory: $@"
	@mkdir -p $(BUILD_DIR)

# Clean generated files (Only Bad Path Bochs log is relevant now)
clean:
	@echo "Cleaning build directory and Bochs logs..."
	@rm -rf $(BUILD_DIR) bochsout_bad.txt # Only remove bad path log

# Check if the required Bochs configuration file exists (only needed for bad path)
check-bochsrc:
	@if [ ! -f "$(BOCHSRC_BAD)" ]; then \
		echo "Error: Bochs configuration file ($(BOCHSRC_BAD)) not found for Bad Path."; \
		exit 1; \
	fi

# --- Execution Targets ---

# Run the Happy Path in QEMU
run: happy
	@echo "Running Happy Path ( $(IMG_HAPPY) ) with QEMU..."
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_HAPPY)

# Run the Bad Path in Bochs
run-bad: bad check-bochsrc # Needs bochsrc
	@echo "Running Bad Path ( $(IMG_BAD) ) with Bochs..."
	@echo "!!! EXPECT BOCHS TO HALT OR REPORT A #GP FAULT (check bochsout_bad.txt) !!!"
	@$(BOCHS) -q -f $(BOCHSRC_BAD) # Use Bochs command with config

# --- Debugging Targets ---

# Debug the Happy Path with QEMU + GDB
debug: happy
	@echo "Starting QEMU for Happy Path debugging ( $(IMG_HAPPY) )..."
	@echo "QEMU waiting for GDB connection on localhost:1234"
	@echo "Connect GDB in another terminal with: gdb -ex 'target remote localhost:1234'"
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_HAPPY) $(QEMUFLAGS_DEBUG) & # QEMU in debug mode

# Debug the Bad Path with Bochs + GDB
debug-bad: bad check-bochsrc # Needs bochsrc
	@echo "Starting Bochs for Bad Path debugging ( $(IMG_BAD) )..."
	@echo "Bochs GDB stub enabled via $(BOCHSRC_BAD)."
	@echo "!!! EXPECT #GP FAULT ON WRITE ATTEMPT !!!"
	@echo "Connect GDB in another terminal with: gdb -ex 'target remote localhost:1234'"
	@$(BOCHS) -f $(BOCHSRC_BAD) & # Bochs command with GDB stub enabled via config
