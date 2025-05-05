# Project Files

## Makefile (in root)

```
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
```

## Files in src folder

## src/boot_bad_path.asm

```
; boot_ss_rw_ds_ro_test.asm - Stack R/W, Datos RO para prueba

[bits 16]
[org 0x7c00]

; --- Inicialización Modo Real ---
start:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov ax, 0x0003
    int 0x10

    mov si, msg_starting
    call print16_bios

    ; --- Transición a Modo Protegido ---
    mov si, msg_gdt_load
    call print16_bios

    cli
    lgdt [gdt_descriptor]

    mov si, msg_entering_pm
    call print16_bios

    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    jmp CODE_SEG:start_protected

; --- Rutina de Impresión Modo Real (BIOS) ---
print16_bios:
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

; =========================================================================
[bits 32]
; =========================================================================

start_protected:
    ; --- Configuración Modo Protegido ---
    ; PASO 1: Cargar DS, ES, FS, GS con el selector del segmento RO
    mov ax, DATA_RO_SEG    ; Usar selector RO (0x18) para datos generales
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    ; SS se cargará con LSS usando el segmento R/W

    ; PASO 2: Configurar Stack ATÓMICAMENTE usando LSS y el segmento R/W
    ; stack_ptr necesita ser leído. ¿Puede DS (RO) leerlo? Sí.
    ; SS se cargará con DATA_RW_SEG (0x10).
    lss esp, [stack_ptr]  ; Carga SS=0x10 y ESP=0x90000

    ; --- Código Principal Modo Protegido ---
    mov edx, VID_MEM_BASE + (2 * 80 * 3) ; Fila 3
    mov ebx, msg_pm_active
    call print32

    mov edx, VID_MEM_BASE + (2 * 80 * 4) ; Fila 4
    mov ebx, msg_seg_stack_set_mix ; Mensaje adaptado
    call print32

    ; --- Intento de Escritura en Segmento Read-Only (vía DS) ---
    mov edx, VID_MEM_BASE + (2 * 80 * 5) ; Fila 5
    mov ebx, msg_attempt_write_ds
    call print32

    ; PASO 3: ¡Intento de escritura usando DS (que es RO)!
    nop
    mov word [0x10000], 0xDEAD ; Intenta escribir en [DS(RO):0x10000]
                               ; ¡Debería causar #GP!

    ; --- Código que NO debería ejecutarse ---
    mov edx, VID_MEM_BASE + (2 * 80 * 7) ; Fila 7
    mov ebx, msg_write_succeeded_error
    call print32

halt_loop:
    hlt
    jmp halt_loop

; --- Rutina de Impresión Modo Protegido (Memoria Video) ---
VID_MEM_BASE equ 0xb8000
print32:
    pusha
.loop:
    mov al, [ebx]       ; Lee usando DS (ahora RO, pero leer está permitido)
    mov ah, 0x0F
    cmp al, 0
    je .done
    mov [es:edx], ax    ; Escribe usando ES (también RO, pero escribir a memoria
                        ; de video a veces funciona o tiene efectos diferentes a RAM normal -
                        ; para ser más estrictos, print32 debería usar SS si queremos
                        ; estar seguros de escribir con un segmento R/W, pero dejémoslo así por ahora)
    add ebx, 1
    add edx, 2
    jmp .loop
.done:
    popa
    ret

; =========================================================================
; Datos y GDT
; =========================================================================

gdt_start:
gdt_null: ; Índice 0
    dd 0x0
    dd 0x0
gdt_code: ; Índice 1, Selector 0x08
    dw 0xFFFF; Limite(15:0)
    dw 0x0000; Base(15:0)
    db 0x00;   Base(23:16)
    db 0x9A;   Acceso (P=1,DPL=0,S=1,Type=1010 E/R)
    db 0xCF;   Gran (G=1,D/B=1,L=0,AVL=0), Limite(19:16)
    db 0x00;   Base(31:24)
gdt_data_rw: ; Índice 2, Selector 0x10 - *** READ/WRITE (PARA STACK SS) ***
    dw 0xFFFF; Limite(15:0)
    dw 0x0000; Base(15:0)
    db 0x00;   Base(23:16)
    db 0x92;   Acceso (P=1,DPL=0,S=1,Type=0010 R/W) <-- RW=1
    db 0xCF;   Gran (G=1,D/B=1,L=0,AVL=0), Limite(19:16)
    db 0x00;   Base(31:24)
gdt_data_ro: ; Índice 3, Selector 0x18 - *** READ ONLY (PARA DATOS DS/ES/FS/GS) ***
    dw 0xFFFF; Limite(15:0)
    dw 0x0000; Base(15:0)
    db 0x00;   Base(23:16)
    db 0x90;   Acceso (P=1,DPL=0,S=1,Type=0000 RO)  <-- RW=0
    db 0xCF;   Gran (G=1,D/B=1,L=0,AVL=0), Limite(19:16)
    db 0x00;   Base(31:24)
gdt_end:

; Descriptor de GDT (Puntero para LGDT)
gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Límite (Tamaño - 1)
    dd gdt_start              ; Dirección Base de la GDT

; Constantes para Selectores
CODE_SEG      equ gdt_code - gdt_start      ; 0x08
DATA_RW_SEG   equ gdt_data_rw - gdt_start   ; 0x10 (Para SS)
DATA_RO_SEG   equ gdt_data_ro - gdt_start   ; 0x18 (Para DS, ES, etc.)

; Mensajes
msg_starting        db 'Bootloader Starting (SS=RW, DS=RO Test)...', 0x0D, 0x0A, 0
msg_gdt_load        db 'Loading GDT...', 0x0D, 0x0A, 0
msg_entering_pm     db 'Entering Protected Mode...', 0x0D, 0x0A, 0
msg_pm_active       db 'Protected Mode Active.', 0
msg_seg_stack_set_mix db 'Stack Set (SS=RW), Data Segs Set (DS/ES=RO).', 0
msg_attempt_write_ds db 'Attempting write to [DS(RO):0x10000]...', 0
msg_write_succeeded_error db 'ERROR: Write to RO segment SUCCEEDED!', 0

; Puntero para LSS (Define SS como R/W)
stack_ptr:
    dd 0x90000      ; Nuevo valor para ESP (32 bits)
    dw DATA_RW_SEG  ; *** USA EL SELECTOR R/W (0x10) PARA SS ***

; --- Relleno y Firma de Arranque ---
%define BOOT_SECTOR_SIZE 512
%define BOOT_SIGNATURE_OFFSET (BOOT_SECTOR_SIZE - 2)
    times BOOT_SIGNATURE_OFFSET - ($ - $$) db 0  ; Rellena hasta offset 510
    dw 0xAA55                                    ; Firma Mágica
```

## src/boot_happy_path.asm

```
; boot_happy_path.asm - Transición a Modo Protegido con Mensajes

[bits 16]
[org 0x7c00]

; --- Inicialización Modo Real ---
start:
    ; Configurar Segmentos y Stack Inicial
    mov ax, 0       ; Usar segmento 0
    mov ds, ax ; cargar DS con 0. Datos en el segmento 0
    mov es, ax ; cargar ES con 0. Extra en el segmento 0
    mov ss, ax ; cargar SS con 0. Stack en el segmento 0 
    mov sp, 0x7c00  ; Stack justo debajo de nuestro código. Este es el offset del bootloader.

    ; En este caso, todo se ejecuta en un solo segmento, así que no es necesario cargar otros segmentos con bases diferentes.
    ; (En un sistema real, podríamos tener diferentes segmentos de código y datos). E.g. para los strings de mensajes.

    ; Limpiar la pantalla (Usando BIOS int 10h, AH=0x00, AL=0x03)
    mov ax, 0x0003  ; AH=0 (Set Video Mode), AL=3 (80x25 Texto)
    int 0x10

    ; Imprimir mensaje inicial (Usando BIOS int 10h, AH=0x0E)
    mov si, msg_starting
    call print16_bios

    ; --- Transición a Modo Protegido ---
    mov si, msg_gdt_load 
    call print16_bios ; Imprimir antes de deshabilitar interrupciones

    cli                 ; Deshabilitar interrupciones para no corromperlas con el cambio de modo
    lgdt [gdt_descriptor] ; Cargar GDT

    mov si, msg_entering_pm
    call print16_bios ; Aún podemos usar BIOS brevemente después de LGDT

    mov eax, cr0        ; Obtener CR0
    or eax, 0x1         ; Poner el bit PE (Protection Enable)
    mov cr0, eax        ; Actualizar CR0 para entrar en modo protegido

    ; Salto lejano para cargar CS y limpiar pipeline
    jmp CODE_SEG:start_protected

; --- Rutina de Impresión Modo Real (BIOS) ---

print16_bios:
    ; PRECONDICIÓN: El registro SI debe apuntar al inicio de un string terminado en NUL (byte 0).
    ; OBJETIVO: Imprimir ese string en la pantalla usando la BIOS.
    ; MODO: Se ejecuta en Modo Real de 16 bits.
    ; MODIFICA: Registros AX, SI (y potencialmente otros registros internos usados por la interrupción int 0x10).

    mov ah, 0x0E        ; Función teletype (Imprimir caracter y avanzar cursor)

.loop:                  ; Etiqueta para el inicio del bucle de impresión
    lodsb               ; Cargar byte de [SI] en AL, luego incrementar SI automáticamente

    ; ANÁLISIS de lodsb:
    ; 'lodsb' (Load String Byte) es una instrucción de cadena.
    ; 1. Lee el byte al que apunta el registro DS:SI (como DS se puso a 0, lee de la dirección lineal contenida en SI).    
    ; 2. Guarda ese byte en el registro AL.
    ; 3. Incrementa automáticamente el registro SI en 1 (para apuntar al siguiente byte del string en la próxima iteración).

    cmp al, 0           ; Compara el caracter recién cargado (en AL) con 0.

    ; ANÁLISIS de cmp al, 0:
    ; 1. Compara AL con el valor inmediato 0. Actualiza la ZF (Zero Flag) para reflejar el resultado.
    ; El valor 0 se usa convencionalmente para marcar el final de un string
    ; (string terminado en NUL).

    je .done            ; Saltar a la etiqueta '.done' si ZF es 1 (si AL era 0)


    int 0x10            ; Llamar a la interrupción de video de la BIOS

    ; ANÁLISIS de int 0x10:
    ; 'int' (Software Interrupt) causa una interrupción de software.
    ; El número indica qué rutina de servicio de la BIOS queremos invocar (la 0x10 es para servicios de Video).
    ;
    ; En nuestro caso, ANTES del bucle pusimos 'mov ah, 0x0E'. La función 0x0E de la int 0x10 es la "Teletype Output" cuando se llama:
    ; - Toma el caracter que está en el registro AL.
    ; - Lo imprime en la pantalla en la posición ACTUAL del cursor.
    ; - Avanza AUTOMÁTICAMENTE el cursor a la siguiente posición (maneja saltos de línea y scroll si es necesario).

    jmp .loop           ; Volver al inicio del bucle para procesar el siguiente caracter

    ; ANÁLISIS de jmp .loop:
    ; Si no saltamos a '.done' (porque el caracter no era NUL), entonces
    ; ejecutamos un salto incondicional (`jmp`) de vuelta a la etiqueta
    ; `.loop` para cargar, comparar e imprimir el siguiente caracter del string.

.done:                  ; Etiqueta a la que saltamos cuando encontramos el NUL
    ret                 ; Vuelve a la rutina que llamó a 'print16_bios'

    
; =========================================================================
[bits 32] ; A partir de aquí, estamos en modo protegido de 32 bits
; =========================================================================

start_protected:
    ; --- Configuración Modo Protegido ---
    mov ax, DATA_SEG    ; Cargar selector de datos en AX
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax          ; Cargar SS (Segmento de Stack)

    ; Configurar un puntero de stack válido
    mov esp, 0x90000    ; Stack en 576KB

    ; --- Código Principal Modo Protegido ---
    ; Imprimir mensajes usando acceso directo a memoria de video
    mov edx, VID_MEM_BASE + (2 * 80 * 3) ; Fila 3
    mov ebx, msg_pm_active
    call print32

    mov edx, VID_MEM_BASE + (2 * 80 * 4) ; Fila 4
    mov ebx, msg_seg_stack_set
    call print32

    ; (Aquí iría la prueba RO en la siguiente versión)

    mov edx, VID_MEM_BASE + (2 * 80 * 6) ; Fila 6
    mov ebx, msg_halting
    call print32

halt_loop:
    hlt                 ; Detener CPU
    jmp halt_loop       ; Bucle por si acaso


; --- Rutina de Impresión Modo Protegido (Memoria Video) ---+
; Escribir en memoria de video directamente utilizando esta base, que mapea memoria RAM a video.
VID_MEM_BASE equ 0xb8000
print32:
    pusha               ; Guardar registros
    ; EBX apunta al string a imprimir. EBX aumenta automaticamente 
    ; EDX apunta al buffer de consola digamos (memoria de video)
    ; 
.loop:
    mov al, [ebx]       ; Cargar caracter desde el string (EBX apunta al string)
    mov ah, 0x0F        ; Atributo: Blanco sobre negro
    cmp al, 0           ; ¿Fin del string?
    je .done
    mov [edx], ax       ; Escribir caracter y atributo
    add ebx, 1          ; Avanzar puntero del string
    add edx, 2          ; Avanzar puntero de video
    jmp .loop
.done:
    popa                ; Restaurar registros
    ret

; =========================================================================
; Datos y GDT
; =========================================================================

gdt_start:
gdt_null:
    dd 0x0
    dd 0x0
gdt_code: ; Selector 0x08
    dw 0xFFFF; Limite(15:0)
    dw 0x0000; Base(15:0)
    db 0x00;   Base(23:16)
    db 0x9A;   Acceso (P=1,DPL=0,S=1,Type=1010 E/R)
    db 0xCF;   Gran (G=1,D/B=1,L=0,AVL=0), Limite(19:16)
    db 0x00;   Base(31:24)
gdt_data: ; Selector 0x10 - *** READ/WRITE ***
    dw 0xFFFF; Limite(15:0)
    dw 0x0000; Base(15:0)
    db 0x00;   Base(23:16)
    db 0x92;   Acceso (P=1,DPL=0,S=1,Type=0010 R/W) <-- Bit RW=1
    db 0xCF;   Gran (G=1,D/B=1,L=0,AVL=0), Limite(19:16)
    db 0x00;   Base(31:24)
gdt_end:

; Descriptor de GDT (Puntero para LGDT)
gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Límite (Tamaño - 1)
    dd gdt_start              ; Dirección Base de la GDT

; Constantes para Selectores
CODE_SEG equ gdt_code - gdt_start ; 0x08
DATA_SEG equ gdt_data - gdt_start ; 0x10

; Mensajes db 'Texto', {0x0D: Carriage Return, 0x0A: Line Feed, 0:NUL}
msg_starting        db 'Bootloader Starting...', 0x0D, 0x0A, 0
msg_gdt_load        db 'Loading GDT...', 0x0D, 0x0A, 0
msg_entering_pm     db 'Entering Protected Mode...', 0x0D, 0x0A, 0
msg_pm_active       db 'Protected Mode Active.', 0
msg_seg_stack_set   db '32-bit Segments and Stack Set.', 0
msg_halting         db 'System Halted.', 0

; --- Relleno y Firma de Arranque ---
%define BOOT_SECTOR_SIZE 512
%define BOOT_SIGNATURE_OFFSET (BOOT_SECTOR_SIZE - 2)
    times BOOT_SIGNATURE_OFFSET - ($ - $$) db 0  ; Rellena hasta offset 510
    dw 0xAA55                                    ; Firma Mágica
```

## Files in scripts folder

## scripts/colors.sh

```
#!/bin/bash
# colors.sh - Define functions for colored output using ANSI escape codes.
# Should be sourced by other scripts.

# Prevent re-sourcing
if [ -n "$_COLORS_LOADED" ]; then
    return 0 # Already loaded
fi
export _COLORS_LOADED=1 # Mark as loaded

# --- Color Definitions ---
C_RESET='\033[0m'
C_GREEN='\033[0;92m'    # Bright Green
C_RED='\033[0;91m'      # Bright Red
C_YELLOW='\033[0;93m'   # Bright Yellow
C_BLUE='\033[0;94m'     # Bright Blue
C_MAGENTA='\033[0;95m'  # Bright Magenta
C_CYAN='\033[0;96m'     # Bright Cyan
C_WHITE='\033[0;97m'    # Bright White

# --- Basic Color Functions ---
# Usage: green "Your text here"
green() { echo -e "${C_GREEN}$@${C_RESET}"; }
red() { echo -e "${C_RED}$@${C_RESET}"; }
yellow() { echo -e "${C_YELLOW}$@${C_RESET}"; }
blue() { echo -e "${C_BLUE}$@${C_RESET}"; }
magenta() { echo -e "${C_MAGENTA}$@${C_RESET}"; }
cyan() { echo -e "${C_CYAN}$@${C_RESET}"; }
white() { echo -e "${C_WHITE}$@${C_RESET}"; }

# --- Semantic Functions ---
info() { green "[INFO] $@"; }
error() { red "[ERROR] $@"; }
warning() { yellow "[WARN] $@"; }
command_msg() { yellow "> $@"; } # Use yellow to show commands
step() { cyan "--- $@ ---"; }

# --- Function to Execute and Display Command ---
# Usage: run_cmd ls -l
run_cmd() {
    command_msg "$@" # Display the command
    "$@"             # Execute the command
    local status=$?
    if [ $status -ne 0 ]; then
        error "Command failed with status $status: $@"
        # Decide if you want to exit immediately on failure
        # exit $status
    fi
    return $status
}

# Indicate successful loading if sourced directly for testing
#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#    info "Color functions loaded."
#fi
```

## scripts/setup_env.sh

```
#!/bin/bash
# setup_env.sh - Simplified script to attempt installation of necessary tools
#                and update submodules for the TP3 project environment.

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Ensures pipeline errors are caught

# Get the directory this script is in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root is the parent directory of 'scripts/'
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the colors script
if ! source "${SCRIPT_DIR}/colors.sh"; then
    echo "FATAL: Could not source colors.sh" >&2
    exit 1
fi

# --- Function to attempt installation of a list of packages ---
# Executes commands directly for robustness with sudo/pipelines
install_packages() {
    local manager=$1
    local update_cmd=$2 # Separate update command (can be empty)
    local install_cmd_base=$3 # Install command base
    shift 3 # Remove manager and commands from arguments
    local packages_to_install="$@"

    if [ -z "$packages_to_install" ]; then
        warning "No packages specified for installation with $manager."
        return 0
    fi

    info "Attempting to install using '$manager': $packages_to_install"

    # --- Execute Update Command (if provided) ---
    if [ -n "$update_cmd" ]; then
        info "Running package list update..."
        command_msg "${update_cmd}" # Show the command
        if ! ${update_cmd}; then   # Execute directly
           error "'$manager' update command failed. Installation might fail."
           # return 1 # Optional: Exit if update fails
        fi
    fi

    # --- Execute Install Command ---
    info "Running package installation..."
    local full_install_command="${install_cmd_base} ${packages_to_install}"
    command_msg "${full_install_command}" # Show the command
    if ! ${full_install_command}; then  # Execute directly
        error "Installation command failed."
        error "Please check the output above and try installing necessary packages manually."
        return 1 # Indicate failure
    else
        info "Installation command finished for $manager."
        return 0 # Indicate success
    fi
}

# --- Main Script Logic ---

cd "$PROJECT_ROOT" || { error "Failed to change directory to $PROJECT_ROOT"; exit 1; }
info "Running setup from project root: $(pwd)"

# === Step 1: Attempt Dependency Installation ===
step "Attempting to Install Dependencies"

manager_found=0
install_status=0 # Variable para guardar el estado de la instalación (0=éxito)

# --- Define package names per manager ---
PKGS_APT="git nasm build-essential qemu-system-x86 gdb binutils bsdmainutils"
PKGS_DNF="git nasm make gcc binutils qemu-system-x86-core gdb util-linux"
PKGS_YUM="git nasm make gcc binutils qemu-system-x86-core gdb util-linux"
PKGS_PACMAN="git nasm base-devel qemu-system-i386 gdb binutils util-linux"
PKGS_BREW="git nasm make qemu gdb binutils util-linux"

# --- Attempt installation based on detected manager ---
if command -v apt &> /dev/null; then
    manager_found=1
    install_packages "apt" "sudo apt update" "sudo apt install -y" $PKGS_APT
    install_status=$? # Captura el estado de esta llamada
elif command -v dnf &> /dev/null; then
    manager_found=1
    install_packages "dnf" "" "sudo dnf install -y" $PKGS_DNF
    install_status=$? # Captura el estado de esta llamada
elif command -v yum &> /dev/null; then
    manager_found=1
    install_packages "yum" "" "sudo yum install -y" $PKGS_YUM
    install_status=$? # Captura el estado de esta llamada
elif command -v pacman &> /dev/null; then
    manager_found=1
    install_packages "pacman" "sudo pacman -Syu --noconfirm" "sudo pacman -S --noconfirm --needed" $PKGS_PACMAN
    install_status=$? # Captura el estado de esta llamada
elif command -v brew &> /dev/null; then
    manager_found=1
    install_packages "brew" "brew update" "brew install" $PKGS_BREW
    install_status=$? # Captura el estado de esta llamada
fi

# --- Verificar resultado de la instalación ---
if [ $manager_found -eq 0 ]; then
    warning "Could not detect a supported package manager."
    warning "Skipping automatic dependency installation. Please ensure required tools are installed."
elif [ $install_status -ne 0 ]; then # Verifica la variable de estado capturada
    error "Dependency installation failed (exit status: $install_status). Cannot proceed."
    exit 1
else
    info "Dependency installation step finished successfully."
fi
echo

# === Step 2: Initialize/Update Submodules ===
step "Initializing/Updating Git Submodules"

if [ ! -f ".gitmodules" ]; then
    warning "'.gitmodules' file not found in project root ($(pwd)). No submodules to update."
else
    info "Updating submodules recursively..."
    # Use run_cmd here as git commands are usually safe
    run_cmd git submodule update --init --recursive
    info "Submodules initialized/updated successfully."
fi
echo

# === Completion ===
info "Environment setup attempt finished for tp3-sdc!"
info "Please verify that all necessary tools (nasm, qemu, make, etc.) are now working."

exit 0
```
