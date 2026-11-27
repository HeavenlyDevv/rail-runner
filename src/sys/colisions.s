.include "sys/physics.h.s"
.include "man/entity.h.s"
.include "sys/stats.h.s"
.include "sys/render.h.s"
.include "sys/prerender.h.s"
.include "sys/generator.h.s"
.include "sys/colisions.h.s"
.include "sys/screen.h.s"

inmortal:: .db 0x00  ; Contador que voy decrementando si minero esta inmortal (acaba de colisionar)

INMORTAL_TIME = 199  ; frames (50 Hz) sin recibir daño tras un golpe (~4 s)

;==================================================================================================
;   Input:  ix -> vagon | iy -> minero
;   Desc:
;      Caja contra caja (AABB). La X del minero se recorta 4 bytes por la derecha para que
;      la hitbox sea mas justa que el dibujo.

sys_check_positions::
    ld      a, indx_type(ix)
    and     #e_type_dead            ; un vagon que ya ha chocado no vuelve a contar
    ret     nz

    ;; vagon.x < minero.x + minero.w - 4
    ld      a, indx_x(iy)
    add     indx_sprite_w(iy)
    sub     #4
    ld      b, a
    ld      a, indx_x(ix)
    cp      b
    ret     nc

    ;; minero.x < vagon.x + vagon.w
    ld      a, indx_x(ix)
    add     indx_sprite_w(ix)
    ld      b, a
    ld      a, indx_x(iy)
    cp      b
    ret     nc

    ;; vagon.y < minero.y + minero.h
    ld      a, indx_y(iy)
    add     indx_sprite_h(iy)
    ld      b, a
    ld      a, indx_y(ix)
    cp      b
    ret     nc

    ;; minero.y < vagon.y + vagon.h
    ld      a, indx_y(ix)
    add     indx_sprite_h(ix)
    ld      b, a
    ld      a, indx_y(iy)
    cp      b
    ret     nc

    ;; Choque
    call    man_entity_set4Destruction  ; ix = vagon

    ld      a, indx_flags(ix)
    and     #train_tnt
    jr      nz, loose_life

    jr      gain_points

;==================================================================================================
;   Input:  ix -> vagon
;   Desc:   Añado puntos dependiendo del tipo de carrito
;           "puntos actuales" (progreso del nivel) y la puntuacion BCD que se ve en pantalla

gain_points:
    ld      a, indx_flags(ix)
    and     #train_oro
    jr      nz, addGold

    ld      a, indx_flags(ix)
    and     #train_diamante
    jr      nz, addDiamond

    ld      a, indx_flags(ix)
    and     #train_gemas
    jr      nz, addGems
    ret

    addGold:
        ld      a, (#level + puntos_actuales)
        add     a, #1
        ld      (#level + puntos_actuales), a

        ld      hl, #newPoints
        ld      (hl), #0x10
        ret

    addDiamond:
        ld      a, (#level + puntos_actuales)
        add     a, #5
        ld      (#level + puntos_actuales), a

        ld      hl, #newPoints
        ld      (hl), #0x50
        ret

    addGems:
        ld      a, (#level + puntos_actuales)
        add     a, #10
        ld      (#level + puntos_actuales), a

        ld      hl, #newPoints + 1  ; +1 porque quiero meter 100 en little endian = 00 01
        ld      (hl), #0x01
        ret

;==================================================================================================
;   Desc:   Minero inmortal un rato y un golpe mas (player_hits)

loose_life:
    ld      a, #INMORTAL_TIME
    ld      (#inmortal), a

    ld      a, (#player_hits)
    inc     a
    ld      (#player_hits), a

    ld      a, #2                   ; repintar los corazones en los dos buffers
    ld      (#hud_dirty), a
    ret
