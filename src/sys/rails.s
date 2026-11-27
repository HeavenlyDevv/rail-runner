.include "cpctelera.h.s"
.include "man/entity.h.s"
.include "sys/rails.h.s"
.include "sys/screen.h.s"

;==================================================================================================
;   RAILES
;
;   Los railes se dibujan una vez y solo se repinta una banda cuando cambia el frame de la
;   animacion (cada RAIL_ANIM_FRAMES frames), una banda por frame y en cada buffer por turno.
;   Cada fila del dibujo es un patron de 4 bytes que se repite (rails_data.s), asi que una linea
;   de 80 bytes se rellena con PUSH (2 us/byte) desde ese patron.
;==================================================================================================

RAIL_ANIM_FRAMES    = 17            ; frames entre pasos de la animacion de los railes
RAIL_FRAME_BYTES    = RAIL_H * 16   ; 11 filas x 16 bytes por frame

rail_frame::        .db 0           ; frame de animacion actual (0..2)
rail_counter:       .db RAIL_ANIM_FRAMES

;; Frame de railes dibujado en cada banda de cada buffer: [buffer 0x8000][3] [buffer 0xC000][3]
band_frames::       .db 0, 0, 0, 0, 0, 0

;; Banda redibujada este frame (0xFF = ninguna) y sus lineas, para que el render repinte
;; lo que estuviera encima.
rails_redrawn_y::   .db 0xFF

rail_frame_ptrs:
    .dw rails_frames
    .dw rails_frames + RAIL_FRAME_BYTES
    .dw rails_frames + 2*RAIL_FRAME_BYTES

;==================================================================================================
;   Called by:  game/man_game_play (inicio de nivel)
;   Desc:       Frame 0 y las 3 bandas dibujadas en los dos buffers

;; Filas que cambian entre frames de la animacion (las demas, raíl gris y huecos negros,
;; son fijas: se pintan al empezar el nivel y no se vuelven a tocar)
rail_row_anim:      .db 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1
rails_all_rows:     .db 1           ; 1 = pintar tambien las filas fijas (inicio de nivel)

sys_rails_init::
    ld      a, #1
    ld      (#rails_all_rows), a
    xor     a
    ld      (#rail_frame), a
    ld      a, #RAIL_ANIM_FRAMES
    ld      (#rail_counter), a
    ld      hl, #band_frames
    ld      b, #6
  .clr:
    ld      (hl), #0
    inc     hl
    djnz    .clr

    ld      b, #2                   ; los dos buffers
  .buf:
    push    bc
    xor     a
    call    rails_draw_band
    ld      a, #1
    call    rails_draw_band
    ld      a, #2
    call    rails_draw_band
    call    switch_buf_silent
    pop     bc
    djnz    .buf
    xor     a
    ld      (#rails_all_rows), a
    ret

;==================================================================================================
;   Called by:  game/logic_step (50 Hz)
;   Desc:       Avanza el frame de la animacion de los railes

sys_rails_update::
    ld      hl, #rail_counter
    dec     (hl)
    ret     nz
    ld      (hl), #RAIL_ANIM_FRAMES
    ld      a, (#rail_frame)
    inc     a
    cp      #3
    jr      c, .ok
    xor     a
  .ok:
    ld      (#rail_frame), a
    ret

;==================================================================================================
;   Called by:  render/sys_render_frame (al principio de cada frame)
;   Output:     rails_redrawn_y = primera linea de la banda repintada (0xFF si ninguna)
;   Desc:
;       Busca la primera banda de ESTE buffer que no tiene el frame actual y la repinta.
;       Orden resultante: banda 0 en A, banda 0 en B, banda 1 en A... (nunca se ve un frame
;       anterior despues de uno nuevo).

sys_rails_render::
    ld      a, #0xFF
    ld      (#rails_redrawn_y), a

    call    band_frames_cur         ; hl = band_frames del buffer actual
    ld      a, (#rail_frame)
    ld      c, a
    ld      b, #0                   ; banda
  .find:
    ld      a, (hl)
    cp      c
    jr      nz, .redraw
    inc     hl
    inc     b
    ld      a, b
    cp      #3
    jr      c, .find
    ret

  .redraw:
    ld      (hl), c                 ; esta banda queda con el frame actual
    ld      a, b
    push    af
    call    rails_draw_band
    pop     af
    call    band_first_line
    ld      (#rails_redrawn_y), a
    ret

;==================================================================================================
;   Output: hl = &band_frames[buffer actual][0]

band_frames_cur::
    ld      hl, #band_frames
    ld      a, (#start_mem + 1)
    cp      #0xC0
    ret     nz
    inc     hl
    inc     hl
    inc     hl
    ret

;==================================================================================================
;   Input:  a = banda (0..2)   Output: a = primera linea (40, 80, 120)

band_first_line::
    ld      b, a
    add     a                       ; 2
    add     a                       ; 4
    add     b                       ; 5
    add     a                       ; 10
    add     a                       ; 20
    add     a                       ; 40
    add     #RAIL_Y_1
    ret

;==================================================================================================
;   Input:  a = frame (0..2)   Output: hl = datos de ese frame (11 filas x 16 bytes)

rail_frame_data::
    add     a
    ld      e, a
    ld      d, #0
    ld      hl, #rail_frame_ptrs
    add     hl, de
    ld      a, (hl)
    inc     hl
    ld      h, (hl)
    ld      l, a
    ret

;==================================================================================================
;   Input:  a = banda (0..2)
;   Desc:   Dibuja la banda con el frame rail_frame en el buffer start_mem (solo las filas
;           animadas, salvo al iniciar el nivel). Interrupciones desactivadas durante la banda
;           (< 2 ms, menos de las 52 lineas entre interrupciones: como mucho se retrasa una).

rails_draw_band::
    call    band_first_line
    ld      b, a                    ; y
    ld      c, #0                   ; x
    ld      de, (#start_mem)
    call    cpct_getScreenPtr_asm   ; hl = primera linea
    push    hl
    ld      a, (#rail_frame)
    call    rail_frame_data
    push    hl
    pop     iy                      ; iy = patron de la fila 0
    pop     hl

    ld      de, #rail_row_anim
    ld      (#.row_ptr + 1), de
    ld      a, #RAIL_H
    ld      (#.lines + 1), a
    di
    ld      (#.restore_sp + 1), sp
  .line:
    ld      (#.cur_line + 1), hl    ; inicio de esta linea
  .row_ptr:
    ld      a, (#0x0000)            ; ¿fila animada?
    ld      b, a
    ld      a, (#rails_all_rows)
    or      b
    jr      z, .cur_line            ; fila fija: no se toca

    ld      c, 0(iy)                ; push bc escribe (c, b) y push de (e, d):
    ld      b, 1(iy)                ;   p0 p1 p2 p3 p0 p1 ... de izquierda a derecha
    ld      e, 2(iy)
    ld      d, 3(iy)
    ld      a, l                    ; sp = fin de la linea (80 bytes, nunca cruza un banco de 2K)
    add     #80
    ld      l, a
    jr      nc, .nc
    inc     h
  .nc:
    ld      sp, hl
    .rept 20
    push    de
    push    bc
    .endm

  .cur_line:
    ld      hl, #0x0000
    ld      a, h                    ; siguiente linea de pantalla: +0x800 o +0xC050
    add     #8
    ld      h, a
    and     #0x38
    jr      nz, .same_block
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
  .same_block:
    ld      bc, #16                 ; siguiente fila del patron
    add     iy, bc
    ld      de, (#.row_ptr + 1)
    inc     de
    ld      (#.row_ptr + 1), de
  .lines:
    ld      a, #0
    dec     a
    ld      (#.lines + 1), a
    jr      nz, .line
  .restore_sp:
    ld      sp, #0x0000
    ei
    ret
