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
