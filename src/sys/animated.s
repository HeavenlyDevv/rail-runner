.include "man/entity.h.s"
.include "sys/animated.h.s"
.include "sys/render.h.s"
.include "sys/generator.h.s"

;==== ANIMATION ====
;; Los vagones apuntan a sprites enmascarados (mascara y color intercalados,
;; sprites/masked_sprites.s), asi que una sola tabla sirve para las dos cosas.

frames_lampara::
  .dw #_spr_lampara_1
  .dw #_spr_lampara_2
  .dw #_spr_lampara_1
  .dw #_spr_lampara_3

frames_minero::
  .dw #_spr_minero_m1
  .dw #_spr_minero_m2
  .dw #_spr_minero_m3

frames_tren_tnt::
  .dw #_spr_trenv3_tnt_1_m
  .dw #_spr_trenv3_tnt_2_m
  .dw #_spr_trenv3_tnt_3_m

frames_tren_oro::
  .dw #_spr_trenv3_oro_1_m
  .dw #_spr_trenv3_oro_2_m
  .dw #_spr_trenv3_oro_3_m

frames_tren_diamante::
  .dw #_spr_trenv3_diamante_1_m
  .dw #_spr_trenv3_diamante_2_m
  .dw #_spr_trenv3_diamante_3_m

frames_tren_gemas::
  .dw #_spr_trenv3_gemas_1_m
  .dw #_spr_trenv3_gemas_2_m
  .dw #_spr_trenv3_gemas_3_m

;==================================================================================================
;   Called by:  physics/sys_physics_update (vagones y lamparas)
;   Input:  ix = entidad
;   Desc:   Cada anim_frec+1 frames pasa al siguiente frame de su tabla

sys_animated_entity::
    ld      a, indx_anim_frec(ix)
    ld      b, indx_anim_counter(ix)
    sub     b
    jr      z, .due
    inc     b
    ld      indx_anim_counter(ix), b
    ret

  .due:
    ;; Si se mueve en horizontal, el cambio de frame espera a un paso en el que avance:
    ;; asi la animacion no obliga a redibujar ademas de cuando se mueve.
    ld      a, indx_vx(ix)
    or      a
    jr      z, .change
    bit     7, indx_rflags(ix)
    ret     z
  .change:
    ld      indx_anim_counter(ix), #0

    ;; indice actual (4 bits altos) -> siguiente, volviendo a 0 tras el ultimo
    ld      a, indx_frame_(ix)
    ld      c, a
    and     #frame_num
    ld      b, a                            ; b = num. frames
    ld      a, c
    rrca
    rrca
    rrca
    rrca
    and     #0x0F
    inc     a
    cp      b
    jr      c, .in_range
    xor     a
  .in_range:
    ld      d, a                            ; d = nuevo indice
    rlca
    rlca
    rlca
    rlca
    or      b
    ld      indx_frame_(ix), a

    ;; sprite = frames[indice]
    ld      a, d
    add     a
    ld      e, a
    ld      d, #0
    ld      l, indx_frames(ix)
    ld      h, indx_frames+1(ix)
    add     hl, de
    ld      a, (hl)
    ld      indx_sprite(ix), a
    inc     hl
    ld      a, (hl)
    ld      indx_sprite+1(ix), a
    ret
