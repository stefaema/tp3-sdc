; boot_bad_path.asm - Prueba aislada de escritura en segmento Read-Only

[bits 16]
[org 0x7c00]

; --- Inicialización Modo Real ---
start:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Limpiar pantalla
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
    ; Cargar TODOS los segmentos de datos con el selector RW inicialmente
    mov ax, DATA_RW_SEG    ; Usar selector RW (0x10)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax             ; Stack también usa el segmento RW

    ; Configurar un puntero de stack válido
    mov esp, 0x90000       ; Stack en 576KB


    ; Imprimir mensajes iniciales usando print32
    mov edx, VID_MEM_BASE + (2 * 80 * 3) ; Fila 3
    mov ebx, msg_pm_active
    call print32

    mov edx, VID_MEM_BASE + (2 * 80 * 4) ; Fila 4
    mov ebx, msg_segments_rw
    call print32

    ; --- Intento de Escritura en Segmento Read-Only (Aislado) ---
    mov edx, VID_MEM_BASE + (2 * 80 * 6) ; Fila 6
    mov ebx, msg_attempt_ro_write ; "Attempting write using DS=RO..."
    call print32

    ; PASO 2: Cambiar DS al segmento RO
    mov ax, DATA_RO_SEG     ; Cargar selector RO (0x18) en AX
    mov ds, ax              ; ¡Ahora DS apunta a un segmento Read-Only!

    ; PASO 3: Intentar escribir usando DS (que ahora es RO)
    ; Esta es la instrucción que DEBE causar un #GP Fault
    mov word [ds:0x10000], 0xDEAD ; Intenta escribir en [DS(RO):0x10000]

    ; --- Código que NO debería ejecutarse si la protección funciona ---
    mov edx, VID_MEM_BASE + (2 * 80 * 8) ; Fila 8
    mov ebx, msg_write_succeeded_error ; "ERROR: Write to RO segment SUCCEEDED!"
    call print32 

halt_loop:
    hlt
    jmp halt_loop

; --- Rutina de Impresión Modo Protegido (Memoria Video) ---
; Asume que los segmentos DS/ES apuntan a un segmento RW cuando se llama
; para leer el string de EBX y escribir en EDX (memoria de video).
VID_MEM_BASE equ 0xb8000
print32:
    pusha               ; Guardar registros generales
    push ds             ; Guardar DS original
    push es             ; Guardar ES original

    ; Asegurarse de que ES sea RW para escribir en memoria de video
    ; (Asumimos que SS es siempre RW aquí, lo cual es seguro en nuestro setup)
    mov ax, ss          ; Cargar selector de SS (que es DATA_RW_SEG)
    mov es, ax          ; Usar ES = RW para escribir en memoria de video

.loop:
    ; Leer caracter del string (usando DS, que debería ser RW al llamar a print32)
    mov al, [ds:ebx]
    mov ah, 0x0F        ; Atributo: Blanco sobre negro
    cmp al, 0           ; ¿Fin del string?
    je .done

    ; Escribir caracter y atributo en memoria de video (usando ES = RW)
    mov [es:edx], ax

    add ebx, 1          ; Avanzar puntero del string
    add edx, 2          ; Avanzar puntero de video
    jmp .loop
.done:
    pop es              ; Restaurar ES original
    pop ds              ; Restaurar DS original
    popa                ; Restaurar registros generales
    ret

; =========================================================================
; Datos y GDT
; =========================================================================

gdt_start:
gdt_null: ; Descriptor Nulo (Obligatorio, Índice 0)
    dd 0x0
    dd 0x0
gdt_code: ; Descriptor de Código (Índice 1, Selector 0x08)
    dw 0xFFFF  ; Límite bajo
    dw 0x0000  ; Base baja
    db 0x00    ; Base media
    db 0x9A    ; Acceso (Presente, Ring 0, Sistema=1, Tipo=1010 E/R)
    db 0xCF    ; Granularidad (4K, 32bit, L=0), Límite alto
    db 0x00    ; Base alta
gdt_data_rw: ; Descriptor de Datos RW (Índice 2, Selector 0x10)
    dw 0xFFFF  ; Límite bajo
    dw 0x0000  ; Base baja
    db 0x00    ; Base media
    db 0x92    ; Acceso (Presente, Ring 0, Sistema=1, Tipo=0010 R/W) <-- **RW**
    db 0xCF    ; Granularidad (4K, 32bit, L=0), Límite alto
    db 0x00    ; Base alta
gdt_data_ro: ; Descriptor de Datos RO (Índice 3, Selector 0x18)
    dw 0xFFFF  ; Límite bajo
    dw 0x0000  ; Base baja
    db 0x00    ; Base media
    db 0x90    ; Acceso (Presente, Ring 0, Sistema=1, Tipo=0000 R/O) <-- **RO**
    db 0xCF    ; Granularidad (4K, 32bit, L=0), Límite alto
    db 0x00    ; Base alta
gdt_end:

; Descriptor de GDT (Puntero para LGDT)
gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Límite (Tamaño - 1)
    dd gdt_start              ; Dirección Base de la GDT

; Constantes para Selectores
CODE_SEG      equ gdt_code - gdt_start      ; 0x08
DATA_RW_SEG   equ gdt_data_rw - gdt_start   ; 0x10 (Para Stack y datos generales/video)
DATA_RO_SEG   equ gdt_data_ro - gdt_start   ; 0x18 (Para prueba de escritura RO)

; Mensajes
msg_starting        db 'Bootloader Starting (Bad Path - RO Test)...', 0x0D, 0x0A, 0
msg_gdt_load        db 'Loading GDT...', 0x0D, 0x0A, 0
msg_entering_pm     db 'Entering Protected Mode...', 0x0D, 0x0A, 0
msg_pm_active       db 'Protected Mode Active.', 0
msg_segments_rw     db 'Segments DS/ES/SS set to RW.', 0
msg_attempt_ro_write db 'Attempting write using DS=RO...', 0
msg_write_succeeded_error db 'ERROR: Write to RO segment SUCCEEDED! Protection FAILED!', 0

; --- Relleno y Firma de Arranque ---
%define BOOT_SECTOR_SIZE 512
%define BOOT_SIGNATURE_OFFSET (BOOT_SECTOR_SIZE - 2)
    times BOOT_SIGNATURE_OFFSET - ($ - $$) db 0  ; Rellena hasta offset 510
    dw 0xAA55                                    ; Firma Mágica
