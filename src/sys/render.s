.include "cpctelera.h.s"
.include "man/entity.h.s"
.include "sys/render.h.s"
.include "sys/animated.h.s"
.include "sys/generator.h.s"
.include "sys/screen.h.s"
.include "sys/prerender.h.s"
.include "sys/rails.h.s"
.include "globals.h.s"

;==================================================================================================
;   RENDER POR CAMBIOS (dirty rendering) con doble buffer
;
;   Cada entidad recuerda que dibujo dejo en CADA buffer (here_* / there_*, ver entity.h.s).
;   En cada frame, en el buffer oculto:
;     1. restaurar: si algo cambio (posicion, frame, visibilidad), se repone el fondo donde estaba
;     2. solapes:   lo que no cambio pero pisa una zona restaurada se marca para repintar
;     3. dibujar:   solo las entidades marcadas
;   Una entidad quieta no cuesta nada.
;==================================================================================================

MINER_ANIM_FRAMES   = 34        ; frames entre cambios de animacion
TREN_ANIM_FRAMES    = 23
LAMP_ANIM_FRAMES    = 45
MINER_MAX_VY        = 10        ; lineas por frame como maximo al cambiar de carril

;; Desplazamiento del "slot" del buffer actual dentro de la entidad: 0 (0x8000) o 4 (0xC000).
;; Con iy = ix + slot_offset, indx_here_*(iy) es siempre lo dibujado en el buffer actual.
slot_offset:    .dw 0

;; ===== TEMPLATES =============================================================
;; Mismo orden que la estructura de entity.h.s (se comprueba el tamaño al ensamblar)

templ_minero::
   .db #e_type_renderable | #e_type_movable | #e_type_input | #e_type_colisionable  ; (su animacion la lleva physics)
   .db #2, #row_1 - 5                   ; x, y
   .db #0, #MINER_MAX_VY                ; vx, vy
   .db #MINERO_SPRITE_WIDTH, #MINERO_SPRITE_HEIGHT
   .db #0                               ; xfrac
   .dw #_spr_minero_m1                  ; sprite
   .dw #frames_minero                   ; tabla de animacion
   .db #0x03                            ; indice 0 | 3 frames
   .db #MINER_ANIM_FRAMES - 1, #0       ; frecuencia, contador
   .db #is_masked                       ; flags
   .db #0, #NOT_DRAWN                   ; here_x, here_y
   .dw #0                               ; here_spr
   .db #0, #NOT_DRAWN                   ; there_x, there_y
   .dw #0                               ; there_spr
   .db #0                               ; rflags
templ_minero_end:

templ_tren::
   .db #e_type_renderable | #e_type_movable | #e_type_animated | #e_type_colider
   .db #68, #row_2 + train_offset
   .db #0, #0
   .db #TREN_SPRITE_WIDTH, #TREN_SPRITE_HEIGHT
   .db #0
   .dw #_spr_trenv3_tnt_1_m
   .dw #frames_tren_tnt
   .db #0x03
   .db #TREN_ANIM_FRAMES - 1, #0
   .db #is_masked | is_bgdraw
   .db #0, #NOT_DRAWN
   .dw #0
   .db #0, #NOT_DRAWN
   .dw #0
   .db #0

templ_lampara::
   .db #e_type_renderable | #e_type_animated | #e_type_movable
   .db #70, #0
   .db #0, #0
   .db #10, #20
   .db #0
   .dw #_spr_lampara_1
   .dw #frames_lampara
   .db #0x04                            ; 4 frames
   .db #LAMP_ANIM_FRAMES - 1, #0
   .db #0                               ; sin mascara (siempre sobre negro)
   .db #0, #NOT_DRAWN
   .dw #0
   .db #0, #NOT_DRAWN
   .dw #0
   .db #0

.if (templ_minero_end - templ_minero) - e_size
   .error "templ_minero no coincide con el tamaño de la entidad"
.endif

;;; ############################################################################
;;; DIBUJO
;;; ############################################################################

;;============================================
;; Dibuja un sprite sin mascara en el buffer actual (menus, HUD)
;; input: b = y, c = x, hl = sprite, d = alto, e = ancho
sys_draw_one_entity::
  push hl
  push de
  ld de, (start_mem)
  call cpct_getScreenPtr_asm
  ex de, hl
  pop bc
  pop hl
  jp cpct_drawSprite_asm

;;============================================
;; Igual pero con sprite enmascarado (pares mascara/color)
;; input: b = y, c = x, hl = sprite, d = alto, e = ancho
sys_draw_masked_at::
  push hl
  push de
  ld de, (start_mem)
  call cpct_getScreenPtr_asm
  ex de, hl
  pop bc
  pop hl
  jp draw_masked

;====================================================================
;   Puntero de pantalla para strings (b = y, c = x) -> hl

sys_draw_one_string::
  ld de, (start_mem)
  jp cpct_getScreenPtr_asm

;==================================================================================================
;   draw_masked
;   Input:  hl = sprite (pares mascara, color), de = destino, c = ancho (1..11), b = alto
;   Desc:
;       pantalla = (pantalla AND mascara) OR color, en UNA pasada y sin buffer temporal.
;       La pila apunta al sprite: "pop bc" lee mascara y color a la vez (c = mascara, b = color).
;       11 us por byte.
;       El bucle de cada linea esta desenrollado; se entra en el punto que toca segun el ancho.
;       Interrupciones desactivadas mientras se dibuja (< 2.5 ms: como mucho se retrasa una).

DM_MAX_W    = 11
DM_BLOCK    = 6                     ; bytes de codigo por byte de sprite

draw_masked::
    ld      a, b
    ld      (#.dm_lines + 1), a
    ld      a, #DM_MAX_W
    sub     c                       ; bytes que nos saltamos
    ld      c, a
    add     a                       ; *2
    add     c                       ; *3
    add     a                       ; *6
    push    hl
    ld      hl, #.dm_row
    add     l
    ld      l, a
    jr      nc, .dm_nc
    inc     h
  .dm_nc:
    ld      (#.dm_jump + 1), hl
    pop     hl

    di
    ld      (#.dm_sp + 1), sp
    ld      sp, hl                  ; sp = sprite
    ex      de, hl                  ; hl = destino
  .dm_line:
    ld      d, h                    ; de = inicio de la linea
    ld      e, l
  .dm_jump:
    jp      .dm_row
  .dm_row:
    .rept DM_MAX_W
    pop     bc
    ld      a, (hl)
    and     c
    or      b
    ld      (hl), a
    inc     hl
    .endm
    ex      de, hl
    ld      a, h                    ; siguiente linea de pantalla
    add     #8
    ld      h, a
    and     #0x38
    jr      nz, .dm_lines
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
  .dm_lines:
    ld      a, #0
    dec     a
    ld      (#.dm_lines + 1), a
    jr      nz, .dm_line
  .dm_sp:
    ld      sp, #0x0000
    ei
    ret

;==================================================================================================
;   draw_masked_bg
;   Input:  ix = entidad (x, y, w, h, sprite enmascarado). Dibuja en start_mem.
;   Desc:
;       Para los vagones, que solo estan sobre negro o sobre una banda de railes: el fondo se
;       lee de los datos de los railes (no de la pantalla), asi el rect queda reescrito entero
;       y al moverse solo hay que restaurar la tira de 1-2 bytes que dejan atras.
;         lineas sobre negro:  pantalla = color                      ( 7 us/byte)
;         lineas sobre railes: pantalla = (railes AND mascara) OR color (13 us/byte)
;       La pila apunta al sprite (pop bc = mascara, color). Sin CALLs dentro del dibujo.

draw_masked_bg::
    push    iy
    ld      c, indx_x(ix)
    ld      b, indx_y(ix)
    ld      e, indx_sprite_w(ix)
    ld      d, indx_sprite_h(ix)
    call    set_query
    ld      c, indx_x(ix)
    ld      b, indx_y(ix)
    ld      de, (#start_mem)
    call    cpct_getScreenPtr_asm
    ld      (#.bg_dest + 1), hl

    ;; puntos de entrada en los bucles desenrollados segun el ancho
    ld      a, (#q_w)
    ld      b, a
    ld      a, #DM_MAX_W
    sub     b
    ld      c, a                    ; c = bytes saltados
    add     a                       ; *3 (bloque negro: pop bc / ld (hl),b / inc hl)
    add     c
    ld      e, a
    ld      d, #0
    ld      hl, #.bk_row
    add     hl, de
    ld      (#.bk_jump + 1), hl
    ld      hl, #.bk2_row
    add     hl, de
    ld      (#.bk2_jump + 1), hl
    ld      a, c                    ; *7 (bloque railes)
    add     a
    add     a
    add     a
    sub     c
    ld      hl, #.rl_row
    add     l
    ld      l, a
    jr      nc, .bg_nc2
    inc     h
  .bg_nc2:
    ld      (#.rl_jump + 1), hl

    ;; tramos: negro arriba (n1), railes (n2, desde la fila r0), negro abajo (n3)
    ld      a, (#q_y2)
    ld      b, a
    ld      a, (#q_y)
    neg
    add     b                       ; h
    ld      (#.bk_n + 1), a         ; por defecto todo negro
    xor     a
    ld      (#.rl_n + 1), a
    ld      (#.bk2_n + 1), a
    call    query_band              ; carry: a = T, hl = &band_src[k]
    jr      nc, .bg_go
    ld      e, (hl)
    inc     hl
    ld      d, (hl)                 ; de = fila 0 de la banda
    ld      c, a                    ; c = T
    ld      a, (#q_y)
    ld      b, a                    ; b = y
    sub     c                       ; y - T
    jr      nc, .bg_in              ; empieza dentro de la banda: n1 = 0, r0 = y - T
    neg
    ld      (#.bk_n + 1), a         ; n1 = T - y
    xor     a                       ; r0 = 0
    ld      b, c                    ; la banda empieza en T
    jr      .bg_r0
  .bg_in:
    push    af
    xor     a
    ld      (#.bk_n + 1), a
    pop     af
  .bg_r0:
    add     a                       ; de += r0 * 16 + (x & 3)
    add     a
    add     a
    add     a
    add     e
    ld      e, a
    jr      nc, .bg_nc3
    inc     d
  .bg_nc3:
    ld      a, (#q_x)
    and     #3
    add     e
    ld      e, a
    jr      nc, .bg_nc4
    inc     d
  .bg_nc4:
    ld      (#.rl_src + 1), de
    ld      a, c                    ; fin de banda = min(y2, T + RAIL_H)
    add     #RAIL_H
    ld      c, a
    ld      a, (#q_y2)
    cp      c
    jr      c, .bg_endok
    ld      a, c
  .bg_endok:
    ld      c, a
    sub     b                       ; n2 = fin - inicio
    ld      (#.rl_n + 1), a
    ld      a, (#q_y2)
    sub     c                       ; n3 = y2 - fin
    ld      (#.bk2_n + 1), a

  .bg_go:
    ld      l, indx_sprite(ix)
    ld      h, indx_sprite+1(ix)
    di
    ld      (#.bg_sp + 1), sp
    ld      sp, hl                  ; sp = sprite
  .bg_dest:
    ld      hl, #0x0000             ; hl = pantalla

    ;; ---- negro arriba
  .bk_n:
    ld      a, #0
    or      a
    jr      z, .rl_n
  .bk_line:
    ld      (#.bk_cnt + 1), a
    ld      d, h
    ld      e, l
  .bk_jump:
    jp      .bk_row
  .bk_row:
    .rept DM_MAX_W
    pop     bc
    ld      (hl), b
    inc     hl
    .endm
    ex      de, hl
    ld      a, h
    add     #8
    ld      h, a
    and     #0x38
    jr      nz, .bk_cnt
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
  .bk_cnt:
    ld      a, #0
    dec     a
    jr      nz, .bk_line

    ;; ---- railes
  .rl_n:
    ld      a, #0
    or      a
    jp      z, .bk2_n
  .rl_line:
    ld      (#.rl_cnt + 1), a
    ld      (#.rl_save + 1), hl
  .rl_src:
    ld      de, #0x0000
  .rl_jump:
    jp      .rl_row
  .rl_row:
    .rept DM_MAX_W
    pop     bc
    ld      a, (de)
    and     c
    or      b
    ld      (hl), a
    inc     hl
    inc     de
    .endm
    ld      hl, (#.rl_src + 1)      ; siguiente fila de railes
    ld      bc, #16
    add     hl, bc
    ld      (#.rl_src + 1), hl
  .rl_save:
    ld      hl, #0x0000
    ld      a, h
    add     #8
    ld      h, a
    and     #0x38
    jr      nz, .rl_cnt
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
  .rl_cnt:
    ld      a, #0
    dec     a
    jp      nz, .rl_line

    ;; ---- negro abajo
  .bk2_n:
    ld      a, #0
    or      a
    jr      z, .bg_sp
  .bk2_line:
    ld      (#.bk2_cnt + 1), a
    ld      d, h
    ld      e, l
  .bk2_jump:
    jp      .bk2_row
  .bk2_row:
    .rept DM_MAX_W
    pop     bc
    ld      (hl), b
    inc     hl
    .endm
    ex      de, hl
    ld      a, h
    add     #8
    ld      h, a
    and     #0x38
    jr      nz, .bk2_cnt
    ld      a, l
    add     #0x50
    ld      l, a
    ld      a, h
    adc     #0xC0
    ld      h, a
  .bk2_cnt:
    ld      a, #0
    dec     a
    jr      nz, .bk2_line

  .bg_sp:
    ld      sp, #0x0000
    ei
    pop     iy
    ret

;==================================================================================================
;   Called by:  generator / game (crear entidades)
;   Input:  hl = template
;   Output: carry = 1 si el array esta lleno (no se crea)

create_template::
    push    hl
    call    man_entity_create       ; hl = entidad reservada, carry = lleno
    pop     de
    ret     c
    ex      de, hl                  ; hl = template, de = entidad
    ld      bc, #e_size
    call    cpct_memcpy_asm
    or      a
    ret

;==================================================================================================
;   Called by:  game.s/man_game_init
;   Desc:       Crea el minero

sys_templates_init::
    ld      hl, #templ_minero
    jp      create_template

;==================================================================================================
;   Called by:  game.s/man_game_init
;   Desc:       modo 0, borde y tinta 0 negros, paleta del juego

sys_render_init::

  ld    c, #0
  call  cpct_setVideoMode_asm

  cpctm_setBorder_asm HW_BLACK

  ld    l, #0
  ld    h, #HW_BLACK
  call  cpct_setPALColour_asm

  ld    hl, #_main_palette
  ld    de, #16
  call  cpct_setPalette_asm

  ret

;==================================================================================================
;   Called by:  game/man_game_play (una vez por frame)
;   Desc:       Dibuja el frame en el buffer oculto (start_mem)

sys_render_frame::
    ld      hl, #0                  ; slot del buffer actual dentro de cada entidad
    ld      a, (#start_mem + 1)
    cp      #0xC0
    jr      nz, .s0
    ld      l, #4
  .s0:
    ld      (#slot_offset), hl

    call    sys_rails_render        ; quizas repinta una banda de railes
    call    restore_cache_bands     ; datos de railes de cada banda en este buffer
    call    restore_list_reset

    ld      hl, #render_pass_restore
    ld      a, #e_type_renderable
    call    man_entity_forall_matching

    ;; ¿Se ha restaurado el minero? (entonces lo que tenga debajo se repinta)
    ld      a, (#e_array + indx_rflags)
    and     #RF_RESTORED
    ld      (#miner_restored), a

    call    restore_list_empty
    jr      z, .no_overlaps
    ld      hl, #render_pass_overlap
    ld      a, #e_type_minero_o_vagon
    call    man_entity_forall_matching
  .no_overlaps:

    ;; Dibujar: todo menos el minero, y el minero el ultimo (siempre por encima)
    ld      hl, #render_pass_draw_others
    ld      a, #e_type_renderable
    call    man_entity_forall_matching
    ld      ix, #e_array
    jp      render_pass_draw

e_type_minero_o_vagon = e_type_renderable
miner_restored: .db 0

render_pass_draw_others:
    ld      a, indx_type(ix)
    and     #e_type_input
    ret     nz
    jp      render_pass_draw

;; iy = ix + slot_offset
set_slot_iy:
    push    ix
    pop     iy
    ld      de, (#slot_offset)
    add     iy, de
    ret

;==================================================================================================
;   Pasada 1 (ix = entidad): decide si cambia y restaura el fondo donde estaba

render_pass_restore:
    call    set_slot_iy
    ld      indx_rflags(ix), #0

    ;; ¿Debe verse? (muerta = no; minero inmortal parpadea cada 4 frames)
    ld      a, indx_type(ix)
    and     #e_type_dead
    jp      nz, .want_nothing
    ld      a, indx_type(ix)
    and     #e_type_input
    jr      z, .visible
    ld      a, (#inmortal)
    and     #0x04
    jp      nz, .want_nothing

  .visible:
    ld      a, indx_here_y(iy)
    cp      #NOT_DRAWN
    jp      z, .dirty                       ; no habia nada: dibujar sin restaurar
    cp      indx_y(ix)
    jr      nz, .dirty_restore
    ld      a, indx_here_x(iy)
    cp      indx_x(ix)
    jr      nz, .dirty_restore
    ld      a, indx_here_spr(iy)
    cp      indx_sprite(ix)
    jr      nz, .spr_changed
    ld      a, indx_here_spr+1(iy)
    cp      indx_sprite+1(ix)
    jr      nz, .spr_changed

    ;; Sin cambios. Solo hay que repintar si la banda de railes repintada este frame la piso.
    ld      a, (#rails_redrawn_y)
    cp      #0xFF
    ret     z
    ld      b, a                            ; banda: [b, b + RAIL_H)
    ld      a, indx_y(ix)                   ; entidad: [y, y + h)
    cp      b
    jr      nc, .y_ge_band
    add     indx_sprite_h(ix)               ; y < banda: solapa si y + h > banda
    cp      b
    ret     z
    ret     c
    jr      .dirty
  .y_ge_band:
    ld      c, a
    ld      a, b
    add     #RAIL_H
    cp      c                               ; solapa si banda + RAIL_H > y
    ret     z
    ret     c
    jr      .dirty

  .spr_changed:
    ;; Solo ha cambiado el frame. Si es el minero (ciclo de carrera) y no toca a nadie, se
    ;; dibuja sobre su fondo conocido (como los vagones): sin restaurar ni buscar solapes.
    ld      a, indx_type(ix)
    and     #e_type_input
    jr      z, .dirty_restore
    call    miner_alone
    jr      nz, .dirty_restore
    set     2, indx_rflags(ix)              ; dibujar esta vez con draw_masked_bg
    jp      .dirty

  .dirty_restore:
    ;; Sprite opaco (lamparas) que solo se ha movido a la izquierda: el dibujo nuevo tapa casi
    ;; todo el viejo, solo hay que restaurar la tira de la derecha que queda al descubierto.
    ld      a, indx_flags(ix)
    and     #is_masked | is_bgdraw
    cp      #is_masked                      ; enmascarado normal (minero): restaurar todo
    jr      z, .full_restore
    ld      a, indx_here_y(iy)
    cp      indx_y(ix)
    jr      nz, .full_restore
    ld      a, indx_here_x(iy)
    sub     indx_x(ix)                      ; dx = here_x - x
    jr      c, .full_restore
    jr      z, .dirty                       ; misma x: el dibujo nuevo lo tapa todo
    cp      indx_sprite_w(ix)
    jr      nc, .full_restore
    ld      e, a                            ; ancho = dx
    ld      a, indx_x(ix)
    add     indx_sprite_w(ix)
    ld      c, a                            ; desde x + w
    ld      b, indx_y(ix)
    ld      d, indx_sprite_h(ix)
    call    restore_rect
    jr      .dirty
  .full_restore:
    call    restore_here
  .dirty:
    set     0, indx_rflags(ix)              ; RF_DIRTY
    ;; Un vagon se dibuja con su fondo: reescribe su rect entero. Se apunta como zona
    ;; reescrita para que lo que este debajo (el minero) se repinte despues.
    bit     7, indx_flags(ix)               ; is_bgdraw
    ret     z
    ld      c, indx_x(ix)
    ld      b, indx_y(ix)
    ld      e, indx_sprite_w(ix)
    ld      d, indx_sprite_h(ix)
    jp      restore_list_add

  .want_nothing:
    ld      a, indx_here_y(iy)
    cp      #NOT_DRAWN
    ret     z
    call    restore_here
    ld      indx_here_y(iy), #NOT_DRAWN
    ret

;==================================================================================================
;   miner_alone
;   Input:  ix = minero, iy = su slot en este buffer
;   Output: Z si ninguna otra entidad (donde esta ahora ni donde esta dibujada en este buffer)
;           toca el rect del minero

miner_alone:
    push    ix
    push    iy
    ld      c, indx_x(ix)
    ld      b, indx_y(ix)
    ld      e, indx_sprite_w(ix)
    ld      d, indx_sprite_h(ix)
    call    set_query
    ld      ix, #e_array + e_size           ; el resto de entidades
  .ma_loop:
    ld      a, indx_type(ix)
    or      a
    jr      z, .ma_alone
    ld      c, indx_x(ix)                   ; donde esta ahora
    ld      b, indx_y(ix)
    call    .ma_hit
    jr      nz, .ma_touch
    push    ix
    pop     iy
    ld      de, (#slot_offset)
    add     iy, de
    ld      a, indx_here_y(iy)              ; donde esta dibujada en este buffer
    cp      #NOT_DRAWN
    jr      z, .ma_next
    ld      b, a
    ld      c, indx_here_x(iy)
    call    .ma_hit
    jr      nz, .ma_touch
  .ma_next:
    ld      de, #e_size
    add     ix, de
    jr      .ma_loop
  .ma_alone:
    pop     iy
    pop     ix
    xor     a                               ; Z
    ret
  .ma_touch:
    pop     iy
    pop     ix
    or      #1                              ; NZ
    ret

  ;; rect (c, b, w y h de ix) contra q_*: NZ si se tocan
  .ma_hit:
    ld      a, (#q_x2)                      ; c < x2
    cp      c
    jr      z, .ma_no
    jr      c, .ma_no
    ld      a, c                            ; x < c + w
    add     indx_sprite_w(ix)
    ld      c, a
    ld      a, (#q_x)
    cp      c
    jr      nc, .ma_no
    ld      a, (#q_y2)                      ; b < y2
    cp      b
    jr      z, .ma_no
    jr      c, .ma_no
    ld      a, b                            ; y < b + h
    add     indx_sprite_h(ix)
    ld      b, a
    ld      a, (#q_y)
    cp      b
    jr      nc, .ma_no
    or      #1
    ret
  .ma_no:
    xor     a
    ret

;; Repone el fondo bajo lo dibujado en este buffer (rect here_x, here_y, w, h)
restore_here:
    set     1, indx_rflags(ix)              ; RF_RESTORED
    ld      c, indx_here_x(iy)
    ld      b, indx_here_y(iy)
    ld      e, indx_sprite_w(ix)
    ld      d, indx_sprite_h(ix)
    jp      restore_rect

;==================================================================================================
;   Pasada 2: lo que no cambia pero estaba debajo de una zona restaurada se repinta

render_pass_overlap:
    bit     0, indx_rflags(ix)
    ret     nz
    ;; Solo se pueden pisar el minero, o lo que este junto al minero si el que se ha restaurado
    ;; es el minero (los vagones de un carril nunca se tocan y las lamparas solo pueden tocar al
    ;; minero cuando salta al carril de arriba)
    ld      a, indx_type(ix)
    and     #e_type_input
    jr      nz, .ov_check
    ld      a, (#miner_restored)
    or      a
    ret     z
  .ov_check:
    call    set_slot_iy
    ld      a, indx_here_y(iy)
    cp      #NOT_DRAWN
    ret     z
    ld      c, indx_here_x(iy)
    ld      b, a
    ld      e, indx_sprite_w(ix)
    ld      d, indx_sprite_h(ix)
    call    restore_list_hits               ; Z = no solapa
    ret     z
    set     0, indx_rflags(ix)
    ret

;==================================================================================================
;   Pasada 3: dibujar lo marcado y apuntar que hay en este buffer

render_pass_draw:
    bit     0, indx_rflags(ix)
    ret     z
    call    set_slot_iy
    bit     7, indx_flags(ix)
    jr      nz, .bg
    bit     2, indx_rflags(ix)
    jr      z, .not_bg
  .bg:
    call    draw_masked_bg
    jr      .drawn
  .not_bg:

    ld      de, (#start_mem)
    ld      c, indx_x(ix)
    ld      b, indx_y(ix)
    call    cpct_getScreenPtr_asm
    ex      de, hl                          ; de = destino
    ld      l, indx_sprite(ix)
    ld      h, indx_sprite+1(ix)
    ld      c, indx_sprite_w(ix)
    ld      b, indx_sprite_h(ix)
    ld      a, indx_flags(ix)
    and     #is_masked
    jr      z, .plain
    call    draw_masked
    jr      .drawn
  .plain:
    call    cpct_drawSprite_asm
  .drawn:
    ld      a, indx_x(ix)
    ld      indx_here_x(iy), a
    ld      a, indx_y(ix)
    ld      indx_here_y(iy), a
    ld      a, indx_sprite(ix)
    ld      indx_here_spr(iy), a
    ld      a, indx_sprite+1(ix)
    ld      indx_here_spr+1(iy), a
    ret
