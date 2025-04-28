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
