; print_bios_final.asm - Imprime string usando int 10h, ah=0E en modo texto

[bits 16]
[org 0x7c00]

start:
    ; --- Configurar Segmentos ---
    xor ax, ax    ; AX = 0
    mov ds, ax    ; DS = 0
    mov es, ax    ; ES = 0
    ; mov bx,0x8000 ; No necesario para modo texto

    ; --- Establecer Modo Texto 80x25 Color ---
    ; mov ax,0x13   ; Eliminado: Modo gráfico incorrecto
    ; int 0x10
    mov ax, 0x0003  ; AH=00h (Set Mode), AL=03h (80x25 color text)
    int 0x10        ; Establecer modo de video (esto también limpia pantalla)

    ; --- Eliminar intentos de posicionar cursor (innecesarios ahora) ---
    ; mov ah,02
    ; int 0x10
    ; mov ah,0x02
    ; mov bh,0x00
    ; mov dh,0x12
    ; mov dl,0x03
    ; int 0x10

    ; --- Imprimir el mensaje ---
    mov si, our_message   ; Puntero SI al inicio del mensaje
    call PrintTextRoutine ; Llamar a la rutina de impresión modificada

    ; --- Detener la CPU ---
    ; xor ax, ax      ; Eliminado: Espera de tecla y reinicio
    ; int 0x16
    ; xor ax, ax
    ; int 0x19
    cli               ; Deshabilitar interrupciones
halt_loop:
    hlt               ; Detener CPU
    jmp halt_loop     ; Bucle por si hlt se reanuda

; --- Mensaje a Imprimir ---
our_message db "FrkAnCKundAndCheckOut", 0x0D, 0x0A, 0x00 ; Mensaje con CR, LF, NUL "ForkAroundAndCheckOut" "FrkAnCKundAndCheckOut"

; --- Rutina de Impresión de Texto Modificada ---
PrintTextRoutine:
    ; mov bl,1        ; Eliminado: Lógica de color incorrecta para ah=0E
    mov ah, 0x0E      ; Función Teletype
    mov bh, 0         ; Página de video 0 (¡IMPORTANTE!)
.repeat_next_char:
    lodsb             ; Cargar byte de [DS:SI] en AL, incrementar SI
    cmp al, 0         ; ¿Fin del string (NUL)?
    je .done_print    ; Si es NUL, terminar

    ; add bl,6        ; Eliminado
    int 0x10          ; Llamar a BIOS para imprimir carácter en AL

    jmp .repeat_next_char ; Repetir para el siguiente carácter

.done_print:
    ret               ; Volver de la rutina

; --- Relleno y Firma de Arranque ---
times (510 - ($ - $$)) db 0x00 ; Rellena con ceros hasta el byte 510
dw 0xAA55                      ; Firma mágica de arranque
