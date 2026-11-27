.include "sys/stats.h.s"
.include "sys/screen.h.s"
.include "sys/render.h.s"

score_string: .asciz "SCORE"

points_string: .db 0, 0, 0, 0, 0
points:: .db 0x00, 0x00         ; puntuacion en BCD (4 digitos)

newPoints:: .db 0x00, 0x00      ; puntos (BCD) a sumar en el siguiente paso de logica

player_lives:: ; Indica el numero de vidas
  .db #3

player_hits:: ; Indica el numero de vidas perdidas. Aumenta cuando impacta un carrito de TNT
  .db #0

hud_dirty::   ; buffers en los que falta repintar corazones y puntos (0, 1 o 2)
  .db #0

;==================================================================================================
;   Called by:  game/man_game_play (inicio de nivel)
;   Desc:       Bordes y "SCORE" en los dos buffers; corazones y puntos pendientes de pintar

sys_stats_init::

    call    sys_draw_borders
    call    sys_draw_score_label
    call    switch_buf_silent

    call    sys_draw_borders
    call    sys_draw_score_label
    call    switch_buf_silent

    ld      a, #2
    ld      (#hud_dirty), a
    ret

;==================================================================================================
;   Desc:   Dibuja los bordes

sys_draw_borders:
  call      sys_draw_left_border
  call      sys_draw_right_border
  call      sys_draw_top_border
  jp        sys_draw_bottom_border

sys_draw_left_border:
    ld      d, #MARCO_LEFT_HEIGHT
    ld      e, #MARCO_LEFT_WIDTH
    ld      hl, #_spr_marco_left
    ld      c, #MARCO_LEFT_POSITION_X
    ld      b, #MARCO_LEFT_POSITION_Y
    jp      sys_draw_one_entity

sys_draw_right_border:
    ld      d, #MARCO_LEFT_HEIGHT
    ld      e, #MARCO_LEFT_WIDTH
    ld      hl, #_spr_marco_left
    ld      c, #MARCO_RIGHT_POSITION_X
    ld      b, #MARCO_LEFT_POSITION_Y
    jp      sys_draw_one_entity

sys_draw_top_border:
  ld        d, #MARCO_HALF_TOP_HEIGHT
  ld        e, #MARCO_HALF_TOP_WIDTH
  ld        hl, #_spr_marco_top_left
  ld        c, #MARCO_TOP_LEFT_POSITION_X
  ld        b, #MARCO_TOP_POSITION_Y
  call      sys_draw_one_entity

  ld        d, #MARCO_HALF_TOP_HEIGHT
  ld        e, #MARCO_HALF_TOP_WIDTH
  ld        hl, #_spr_marco_top_right
  ld        c, #MARCO_TOP_RIGHT_POSITION_X
  ld        b, #MARCO_TOP_POSITION_Y
  jp        sys_draw_one_entity

sys_draw_bottom_border:
  ld        d, #MARCO_HALF_TOP_HEIGHT
  ld        e, #MARCO_HALF_TOP_WIDTH
  ld        hl, #_spr_marco_top_left
  ld        c, #MARCO_TOP_LEFT_POSITION_X
  ld        b, #MARCO_BOTTOM_POSITION_Y
  call      sys_draw_one_entity

  ld        d, #MARCO_HALF_TOP_HEIGHT
  ld        e, #MARCO_HALF_TOP_WIDTH
  ld        hl, #_spr_marco_top_right
  ld        c, #MARCO_TOP_RIGHT_POSITION_X
  ld        b, #MARCO_BOTTOM_POSITION_Y
  jp        sys_draw_one_entity

;==================================================================================================
;   Desc:   Dibuja los corazones: player_lives en total, los player_hits primeros vacios

sys_draw_hearts:
    ld      a, (#player_lives)      ; total de vidas
    ld      hl, #player_hits
    ld      d, (hl)                 ; golpes recibidos

    ld      c, #HEARTS_POSITION_START_X
    ld      b, #HEARTS_POSITION_Y

    loop_hearts:
        or      a
        ret     z
        dec     a
        push    af

        ld      a, d
        or      a
        jr      nz, draw_empty_heart
        ld      hl, #_spr_full_heart
        jr      draw_heart

        draw_empty_heart:
            ld      hl, #_spr_empty_heart
            dec     d

        draw_heart:
            push    bc
            push    de
            ld      d, #HEARTS_HEIGHT
            ld      e, #HEARTS_WIDTH
            call    sys_draw_one_entity
            pop     de
            pop     bc

            ld      a, #HEARTS_PADDING
            add     a, c
            ld      c, a

            pop     af
            jr      loop_hearts

;==================================================================================================
;   Called by:  game/logic_step (50 Hz)
;   Desc:       Suma los puntos nuevos y marca el HUD para repintar si ha cambiado

sys_stats_update::
    ld      hl, (#newPoints)
    ld      a, h
    or      l
    ret     z

    ld      bc, (#newPoints)
    ld      hl, (#points)
    ld      a, l
    add     c
    daa
    ld      l, a
    ld      a, h
    adc     b
    daa
    ld      h, a
    ld      (#points), hl
    ld      hl, #0x0000
    ld      (#newPoints), hl

    ld      a, #2
    ld      (#hud_dirty), a
    ret

;==================================================================================================
;   Called by:  game/man_game_play (render, una vez por frame)
;   Desc:       Repinta corazones y puntos solo si han cambiado (una vez en cada buffer):
;               el texto cuesta ~0.8 ms por caracter.

sys_hud_render::
    ld      a, (#hud_dirty)
    or      a
    ret     z
    dec     a
    ld      (#hud_dirty), a
    call    sys_draw_hearts
    jp      sys_stats_scoreboard_draw

;==================================================================================================
;   Desc:   "SCORE" (fijo)

sys_draw_score_label:
    ld      l, #14
    ld      h, #0
    call    cpct_setDrawCharM0_asm
    ld      c, #10
    ld      b, #155
    call    sys_draw_one_string
    ld      iy, #score_string
    jp      _myDrawStringM0

;==================================================================================================
;   Desc:   Escribo la puntuacion (4 digitos BCD)

sys_stats_scoreboard_draw:
    ld      l, #14
    ld      h, #0
    call    cpct_setDrawCharM0_asm
    ld      hl, (#points)

    ld      a, h            ;; digito 1
    rrca
    rrca
    rrca
    rrca
    and     #0x0F
    add     #48
    ld      (#points_string), a

    ld      a, h            ;; digito 2
    and     #0x0F
    add     #48
    ld      (#points_string + 1), a

    ld      a, l            ;; digito 3
    rrca
    rrca
    rrca
    rrca
    and     #0x0F
    add     #48
    ld      (#points_string + 2), a

    ld      a, l            ;; digito 4
    and     #0x0F
    add     #48
    ld      (#points_string + 3), a

    ld      c, #10
    ld      b, #170
    call    sys_draw_one_string
    ld      iy, #points_string
    jp      _myDrawStringM0
