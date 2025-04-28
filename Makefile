# --- tp3-sdc/Makefile ---
ASM=nasm
QEMU=qemu-system-i386 # o qemu-system-x86_64 si lo prefieres/necesitas
BUILD_DIR=build

# Definir nombres de archivo fuente
SRC_HAPPY=src/boot_happy_path.asm
SRC_BAD=src/boot_bad_path.asm

# Definir nombres de archivo de salida (imagen y listado)
IMG_HAPPY=$(BUILD_DIR)/boot_happy_path.img
LST_HAPPY=$(BUILD_DIR)/boot_happy_path.lst
IMG_BAD=$(BUILD_DIR)/boot_bad_path.img
LST_BAD=$(BUILD_DIR)/boot_bad_path.lst

# Flags del Ensamblador: -f bin para salida binaria plana
ASMFLAGS = -f bin

# Flags de QEMU: -fda para usar como imagen de disquete A
QEMUFLAGS_BASE = -accel tcg -fda 
QEMUFLAGS_DEBUG = -S -gdb tcp::1234

# Targets Phony (no son archivos reales)
.PHONY: all clean run run-ro debug debug-ro happy ro

# Target por defecto: construir ambas imágenes
all: happy ro

# Target para construir solo la versión "Happy Path"
happy: $(IMG_HAPPY)

# Target para construir solo la versión "Read-Only Test"
ro: $(IMG_BAD)

# Regla para construir la imagen "Happy Path"
$(IMG_HAPPY): $(SRC_HAPPY) | $(BUILD_DIR)
	@echo "Assembling $(SRC_HAPPY) -> $@"
	@$(ASM) $(ASMFLAGS) $< -o $@ -l $(LST_HAPPY)
	@echo "Created $(LST_HAPPY)"

# Regla para construir la imagen "Read-Only Test"
$(IMG_BAD): $(SRC_BAD) | $(BUILD_DIR)
	@echo "Assembling $(SRC_BAD) -> $@"
	@$(ASM) $(ASMFLAGS) $< -o $@ -l $(LST_BAD)
	@echo "Created $(LST_BAD)"

# Regla para crear el directorio de build si no existe
$(BUILD_DIR):
	@echo "Creating build directory: $@"
	@mkdir -p $(BUILD_DIR)

# Target para limpiar los archivos generados
clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD_DIR)

# Target para ejecutar la versión "Happy Path" en QEMU
run: happy
	@echo "Running Happy Path ( $(IMG_HAPPY) )..."
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_HAPPY)

# Target para ejecutar la versión "Read-Only Test" en QEMU
run-ro: ro
	@echo "Running Read-Only Test ( $(IMG_BAD) )..."
	@echo "!!! EXPECT QEMU TO RESET OR CRASH DUE TO #GP FAULT !!!"
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_BAD)

# Target para depurar la versión "Happy Path" con GDB
debug: happy
	@echo "Starting QEMU for Happy Path debugging ( $(IMG_HAPPY) )..."
	@echo "Connect GDB with: target remote localhost:1234"
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_HAPPY) $(QEMUFLAGS_DEBUG) &

# Target para depurar la versión "Read-Only Test" con GDB
debug-ro: ro
	@echo "Starting QEMU for Read-Only Test debugging ( $(IMG_BAD) )..."
	@echo "!!! EXPECT #GP FAULT ON WRITE ATTEMPT !!!"
	@echo "Connect GDB with: target remote localhost:1234"
	@$(QEMU) $(QEMUFLAGS_BASE) $(IMG_BAD) $(QEMUFLAGS_DEBUG) &
