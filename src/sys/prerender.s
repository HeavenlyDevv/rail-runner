.include "cpctelera.h.s"
.include "man/entity.h.s"
.include "sys/prerender.h.s"
.include "sys/render.h.s"
.include "sys/screen.h.s"
.include "sys/rails.h.s"

;==================================================================================================
;   RESTAURAR FONDO
;
;   El fondo del juego es negro salvo las 3 bandas de railes. Para borrar un sprite se repone
;   exactamente lo que habia debajo: negro, o la fila de railes con el frame que tenga ESE
;   buffer. Un rect (como mucho 24 lineas) toca como mucho una banda, asi que se divide en
;   3 tramos: negro arriba, banda, negro abajo. Ningun registro indice (ix, iy) se toca aqui.
;==================================================================================================

RESTORE_MAX = num_entities

restore_count:  .db 0
restore_list:   .ds 4*RESTORE_MAX       ; (x, y, w, h) de lo restaurado este frame

;; Datos de railes de cada banda en el buffer actual (se calculan al empezar cada frame)
band_src::      .dw 0, 0, 0

;; rect de trabajo
q_x::  .db 0
q_y::  .db 0
q_x2::  .db 0                           ; x + w
q_y2::  .db 0                           ; y + h
q_w::  .db 0

restore_list_reset::
    xor     a
    ld      (#restore_count), a
    ret

;; Z = lista vacia
restore_list_empty::
    ld      a, (#restore_count)
    or      a
    ret

;==================================================================================================
;   Called by:  render/sys_render_frame (despues de sys_rails_render)
;   Desc:       band_src[k] = datos del frame de railes que tiene la banda k en este buffer

restore_cache_bands::
    call    band_frames_cur         ; hl = band_frames[buffer]
    ld      de, #band_src
    ld      b, #3
  .cb_loop:
    push    bc
    push    hl
    push    de
    ld      a, (hl)
    call    rail_frame_data         ; hl = datos
    pop     de
    ex      de, hl
    ld      (hl), e
    inc     hl
    ld      (hl), d
    inc     hl
    ex      de, hl                  ; de = siguiente band_src
    pop     hl
    inc     hl
    pop     bc
    djnz    .cb_loop
    ret

;; Guarda c = x, b = y, e = w, d = h en q_*
set_query::
    ld      a, c
    ld      (#q_x), a
    add     e
    ld      (#q_x2), a
    ld      a, e
    ld      (#q_w), a
    ld      a, b
    ld      (#q_y), a
    add     d
    ld      (#q_y2), a
    ret

;==================================================================================================
;   Input:  c = x, b = y, e = w, d = h
;   Output: NZ si el rect se solapa con algun rect restaurado este frame

restore_list_hits::
    call    set_query
    ld      a, (#restore_count)
    or      a
    ret     z
    ld      b, a
    ld      hl, #restore_list
  .rh_loop:
    push    hl
    ld      a, (#q_x2)              ; rx < x2
    cp      (hl)
    jr      z, .rh_miss
    jr      c, .rh_miss
    ld      a, (hl)                 ; x < rx + rw
    inc     hl
    inc     hl
    add     (hl)
    ld      c, a
    ld      a, (#q_x)
    cp      c
    jr      nc, .rh_miss
    dec     hl                      ; ry
    ld      a, (#q_y2)              ; ry < y2
    cp      (hl)
    jr      z, .rh_miss
    jr      c, .rh_miss
    ld      a, (hl)                 ; y < ry + rh
    inc     hl
    inc     hl
    add     (hl)
    ld      c, a
    ld      a, (#q_y)
    cp      c
    jr      nc, .rh_miss
    pop     hl
    or      #1                      ; NZ = solapa
    ret
  .rh_miss:
    pop     hl
    ld      de, #4
    add     hl, de
    djnz    .rh_loop
    xor     a                       ; Z = no solapa
    ret

;==================================================================================================
;   Busca la banda que toca q_*.
;   Output: carry = 1 si toca alguna; entonces a = primera linea de la banda (40, 80 o 120)
;           y hl = band_src de esa banda

query_band::
    ld      hl, #band_src
    ld      c, #RAIL_Y_1
  .qb_loop:
    ld      a, (#q_y2)              ; banda < y2
    cp      c
    jr      z, .qb_next
    jr      c, .qb_next
    ld      a, c                    ; y < banda + RAIL_H
    add     #RAIL_H
    ld      b, a
    ld      a, (#q_y)
    cp      b
    jr      nc, .qb_next
    ld      a, c
    scf
    ret
  .qb_next:
    inc     hl
    inc     hl
    ld      a, c
    add     #RAIL_Y_2 - RAIL_Y_1
    ld      c, a
    cp      #RAIL_Y_3 + 1
    jr      c, .qb_loop
    or      a                       ; carry = 0
    ret

;; Avanza hl a la siguiente linea de pantalla (+0x800, o +0xC050 al cruzar un bloque de 8 lineas)
next_line_hl::
    ld      a, h
    add     #8
    ld      h, a
    and     #0x38
    ret     nz
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
    ret

;==================================================================================================
;   Input:  hl = primera linea, b = lineas  (ancho en q_w)
;   Output: hl = linea siguiente a la ultima
;   Desc:   Lineas negras

black_lines:
    ld      a, (#q_w)
    dec     a
    ld      c, a                    ; c = w - 1 (bytes que copia el ldir)
  .bl_line:
    push    bc
    push    hl
    ld      (hl), #0
    ld      a, c
    or      a                       ; ancho 1: ya esta (¡LDIR con BC = 0 copiaria 64 KB!)
    jr      z, .bl_one
    ld      d, h
    ld      e, l
    inc     de
    ld      b, #0
    ldir                            ; 6 us/byte
  .bl_one:
    pop     hl
    call    next_line_hl
    pop     bc
    djnz    .bl_line
    ret

;==================================================================================================
;   restore_list_add
;   Input:  c = x, b = y, e = w, d = h
;   Desc:   Apunta un rect como "zona reescrita" sin restaurar nada (los vagones se dibujan
;           con su fondo, asi que lo que hubiera debajo se pierde igual que al restaurar)

restore_list_add::
    ld      a, (#restore_count)
    cp      #RESTORE_MAX
    ret     nc
    ld      l, a
    inc     a
    ld      (#restore_count), a
    ld      h, #0
    add     hl, hl
    add     hl, hl
    push    de
    ld      de, #restore_list
    add     hl, de
    pop     de
    ld      (hl), c
    inc     hl
    ld      (hl), b
    inc     hl
    ld      (hl), e
    inc     hl
    ld      (hl), d
    ret

;==================================================================================================
;   restore_rect
;   Input:  c = x, b = y, e = w, d = h   (en el buffer start_mem)
;   Desc:   Repone el fondo del rect y lo apunta en la lista de restaurados

restore_rect::
    call    set_query

    ;; apuntar en la lista
    ld      a, (#restore_count)
    cp      #RESTORE_MAX
    jr      nc, .rr_listed
    ld      l, a
    inc     a
    ld      (#restore_count), a
    ld      h, #0
    add     hl, hl
    add     hl, hl
    push    de
    ld      de, #restore_list
    add     hl, de
    pop     de
    ld      (hl), c
    inc     hl
    ld      (hl), b
    inc     hl
    ld      (hl), e
    inc     hl
    ld      (hl), d
  .rr_listed:

    push    de
    ld      de, (#start_mem)
    call    cpct_getScreenPtr_asm   ; hl = primera linea (c = x, b = y)
    pop     de
    push    hl

    call    query_band
    jr      c, .rr_band

    ;; Camino rapido: todo negro
    pop     de                      ; de = destino
    ld      a, (#q_w)
    ld      c, a
    ld      a, (#q_y)
    neg
    ld      b, a
    ld      a, (#q_y2)
    add     b
    ld      b, a                    ; b = h
    xor     a
    jp      cpct_drawSolidBox_asm

  .rr_band:
    ;; a = T (primera linea de la banda), hl = &band_src[k]
    ld      e, (hl)
    inc     hl
    ld      d, (hl)                 ; de = datos de la banda (fila 0)
    ld      (#.rr_T + 1), a

    ;; Tramo 1: negro desde y hasta T (si y < T)
    ld      b, a
    ld      a, (#q_y)
    ld      c, a                    ; c = y
    sub     b                       ; y - T
    jr      nc, .rr_inside          ; y >= T: empieza dentro de la banda
    neg
    ld      b, a                    ; lineas negras
    pop     hl
    push    de
    call    black_lines
    pop     de
    push    hl
    ld      a, (#.rr_T + 1)
    ld      c, a                    ; la banda empieza en T, fila 0
    xor     a
  .rr_inside:
    ;; a = fila inicial dentro de la banda, c = primera linea del tramo
    ld      b, a
    add     a                       ; fila * 16
    add     a
    add     a
    add     a
    add     e
    ld      e, a
    jr      nc, .rr_nc
    inc     d
  .rr_nc:
    ld      a, (#q_x)               ; + (x & 3): fase del patron de 4 bytes
    and     #3
    add     e
    ld      e, a
    jr      nc, .rr_nc2
    inc     d
  .rr_nc2:
    ;; lineas de banda = min(y2, T + RAIL_H) - c
  .rr_T:
    ld      a, #0
    add     #RAIL_H
    ld      b, a
    ld      a, (#q_y2)
    cp      b
    jr      c, .rr_end_ok
    ld      a, b                    ; la banda acaba antes que el rect
  .rr_end_ok:
    ld      (#.rr_bandend + 1), a
    sub     c
    ld      b, a                    ; b = lineas de banda
    pop     hl                      ; hl = linea actual
  .rr_band_line:
    push    bc
    push    hl
    push    de
    ex      de, hl                  ; de = pantalla, hl = fuente
    ld      a, (#q_w)
    ld      c, a
    ld      b, #0
    ldir
    pop     de
    ld      hl, #16                 ; siguiente fila de railes
    add     hl, de
    ex      de, hl
    pop     hl
    call    next_line_hl
    pop     bc
    djnz    .rr_band_line

    ;; Tramo 3: negro desde el final de la banda hasta y2
  .rr_bandend:
    ld      a, #0
    ld      b, a
    ld      a, (#q_y2)
    sub     b
    ret     z
    ld      b, a
    jp      black_lines
