.include "sys/physics.h.s"
.include "sys/input.h.s"
.include "man/entity.h.s"
.include "sys/colisions.h.s"
.include "sys/generator.h.s"
.include "sys/animated.h.s"

LANE_TOP     = row_1 - 5        ; y del minero en cada carril
LANE_BOTTOM  = row_3 - 5
LANE_STEP    = row_2 - row_1    ; 40 lineas entre carriles

;==================================================================================================
;   MINERO: ciclo de carrera de 6 frames y saltos/agachadas entre carriles
;
;   Cambiar de carril sigue una tabla de (desplazamiento en y, frame) por frame de 50 Hz:
;     subir  = saltar: se agacha, salta, sube 3 lineas de mas y cae sobre el rail
;     bajar  = agacharse: se encoge y cae acelerando (como la gravedad) hasta el rail de abajo
;   y ambos aterrizan agachados un momento. Cada frame se coloca en su linea exacta.
;==================================================================================================

MINER_RUNNING  = 0
MINER_JUMPING  = 1
MINER_DUCKING  = 2
MOVE_END       = 0x80           ; fin de tabla

;; indices de miner_sprites
S_CROUCH = 6
S_JUMP   = 7
S_DUCK   = 8

miner_state:    .db MINER_RUNNING
miner_step:     .db 0           ; posicion dentro de la tabla de movimiento
miner_base_y:   .db 0           ; y al empezar a cambiar de carril
miner_run_time: .db 0
miner_run_idx:  .db 0           ; frame del ciclo de carrera (0..5)
miner_step_acc: .db 0           ; avance fraccionario por la tabla de movimiento

;; Dependen del nivel (los pone sys_generator_init): cuanto mas rapido va el nivel, mas
;; rapido corre y salta el minero
miner_run_frame_time::  .db 6   ; frames por frame del ciclo de carrera
miner_move_rate::       .db 4   ; pasos de tabla por frame, en cuartos (4 = 1 paso)

miner_sprites:
    .dw _spr_minero_m1, _spr_minero_m1b, _spr_minero_m2, _spr_minero_m2b
    .dw _spr_minero_m3, _spr_minero_m3b
    .dw _spr_minero_crouch, _spr_minero_jump, _spr_minero_duck

;;              dy,  frame
move_up_table:
    .db           0, S_CROUCH       ; impulso
    .db           0, S_CROUCH
    .db          -8, S_JUMP
    .db         -16, S_JUMP
    .db         -23, S_JUMP
    .db         -29, S_JUMP
    .db         -34, S_JUMP
    .db         -38, S_JUMP
    .db         -41, S_JUMP
    .db         -43, S_JUMP         ; punto mas alto: 3 lineas por encima del rail
    .db         -43, S_JUMP
    .db         -42, S_JUMP
    .db         -40, S_CROUCH       ; aterriza
    .db         -40, S_CROUCH
    .db         -40, S_CROUCH
    .db    MOVE_END

move_down_table:
    .db           0, S_DUCK         ; se encoge
    .db           0, S_DUCK
    .db           2, S_DUCK
    .db           5, S_DUCK
    .db           9, S_DUCK
    .db          14, S_DUCK
    .db          20, S_DUCK
    .db          27, S_DUCK
    .db          34, S_DUCK
    .db          40, S_CROUCH       ; aterriza
    .db          40, S_CROUCH
    .db          40, S_CROUCH
    .db    MOVE_END

;; a = indice de miner_sprites -> sprite del minero (ix)
miner_set_sprite:
    add     a
    ld      e, a
    ld      d, #0
    ld      hl, #miner_sprites
    add     hl, de
    ld      a, (hl)
    ld      indx_sprite(ix), a
    inc     hl
    ld      a, (hl)
    ld      indx_sprite+1(ix), a
    ret

;==================================================================================================
;   Called by:  physics/sys_physics_update (50 veces por segundo)
;   Input:  ix -> entidad en cuestion
;   Desc:
;       Mueve a la izquierda con coma fija: xfrac acumula vx/256 de byte por frame y cuando
;       desborda, x baja un byte. Asi un vagon de nivel 1 avanza 1 byte cada ~2.8 frames de forma
;       regular.
;       Si se saldria por la izquierda, se marca para destruir.

sys_physics_update_one_entity:
    res     7, indx_rflags(ix)      ; bit 7 = "ha avanzado en este paso" (lo usa la animacion)
    ld      a, indx_type(ix)
    and     #e_type_dead
    ret     nz                      ; los que estan muriendo no se mueven
    ld      a, indx_xfrac(ix)
    add     indx_vx(ix)
    ld      indx_xfrac(ix), a
    ret     nc
    ld      a, indx_x(ix)
    or      a
    jp      z, man_entity_set4Destruction
    dec     a
    ld      indx_x(ix), a
    set     7, indx_rflags(ix)
    ret

;==================================================================================================
;   Called by:  game/logic_step (50 Hz)
;   Desc:
;       Un solo recorrido del array para mover, chocar y animar. Los sistemas siguen siendo
;       funciones separadas (mover, colision, animacion); lo que se ahorra es recorrer el array
;       tres veces (~22 us por entidad y pasada).
;       El minero es siempre e_array[0]: se crea el primero y nunca se destruye.

col_enabled: .db 0          ; 1 si el minero puede chocar este paso (no es inmortal)

sys_physics_update::
    ld      ix, #e_array                ; minero: cambio de carril
    call    sys_physics_update_on_input

    ld      a, (#inmortal)              ; inmortal: descontar y no chocar
    or      a
    jr      z, .vulnerable
    dec     a
    ld      (#inmortal), a
    xor     a
    jr      .col_set
  .vulnerable:
    inc     a
  .col_set:
    ld      (#col_enabled), a

    ld      iy, #e_array                ; iy = minero (para las colisiones)
    ld      ix, #e_array
  .pu_loop:
    ld      a, indx_type(ix)
    or      a
    ret     z
    bit     1, a                        ; e_type_movable
    call    nz, sys_physics_update_one_entity
    ld      a, indx_type(ix)
    and     #e_type_colider
    jr      z, .pu_anim
    ld      a, (#col_enabled)
    or      a
    call    nz, sys_check_positions
  .pu_anim:
    ld      a, indx_type(ix)
    and     #e_type_animated
    call    nz, sys_animated_entity
    ld      de, #e_size
    add     ix, de
    jr      .pu_loop

;==================================================================================================
;   Called by:  game/man_game_init

sys_physics_init::
    xor     a
    ld      (#miner_state), a
    ld      (#miner_run_time), a
    ld      (#miner_run_idx), a
    ret

;==================================================================================================
;   Called by:  physics/sys_physics_update (50 Hz)
;   Input:  ix -> minero

sys_physics_update_on_input:
    ld      a, (#miner_state)
    or      a
    jr      nz, .moving

    ;; ---- corriendo: ¿quiere cambiar de carril?
    ld      a, (#keyIdentifier)
    cp      #KEY_UP
    jr      nz, .not_up
    ld      a, indx_y(ix)
    cp      #LANE_TOP + 1
    jr      c, .run                 ; ya esta en el carril de arriba
    ld      a, #MINER_JUMPING
    jr      .start
  .not_up:
    cp      #KEY_DOWN
    jr      nz, .run
    ld      a, indx_y(ix)
    cp      #LANE_BOTTOM
    jr      nc, .run                ; ya esta en el carril de abajo
    ld      a, #MINER_DUCKING
  .start:
    ld      (#miner_state), a
    xor     a
    ld      (#miner_step), a
    ld      (#miner_step_acc), a
    ld      a, indx_y(ix)
    ld      (#miner_base_y), a

    ;; ---- siguiente paso de la tabla de movimiento
  .moving:
    ld      hl, #move_up_table
    ld      a, (#miner_state)
    cp      #MINER_JUMPING
    jr      z, .tbl
    ld      hl, #move_down_table
  .tbl:
    ld      a, (#miner_step)
    ld      e, a
    ld      d, #0
    add     hl, de
    add     hl, de                  ; hl = tabla + paso * 2
    ld      a, (hl)
    cp      #MOVE_END
    jr      z, .landed
    ld      b, a                    ; dy (con signo)
    ld      a, (#miner_base_y)
    add     b
    ld      indx_y(ix), a
    inc     hl
    ld      a, (hl)
    push    af                      ; frame de esta posicion

    ;; avanzar por la tabla al ritmo del nivel: acc += ritmo; pasos = acc / 4
    ;; (sin pasar del final: el siguiente frame lee MOVE_END y aterriza)
    ld      a, (#miner_move_rate)
    ld      b, a
    ld      a, (#miner_step_acc)
    add     b
    ld      c, a
    and     #3
    ld      (#miner_step_acc), a
    srl     c
    srl     c                       ; c = pasos a avanzar (1 o 2)
    dec     hl                      ; hl = entrada actual
  .adv:
    ld      a, (hl)                 ; se puede llegar a MOVE_END, pero no pasarlo
    cp      #MOVE_END
    jr      z, .adv_done
    ld      a, (#miner_step)
    inc     a
    ld      (#miner_step), a
    inc     hl
    inc     hl
    dec     c
    jr      nz, .adv
  .adv_done:
    pop     af
    jp      miner_set_sprite

  .landed:
    xor     a
    ld      (#miner_state), a       ; vuelve a correr (y si sigue pulsada, salta otra vez)
    ld      (#miner_run_time), a

    ;; ---- ciclo de carrera
  .run:
    ld      a, (#miner_run_frame_time)
    ld      b, a
    ld      hl, #miner_run_time
    inc     (hl)
    ld      a, (hl)
    cp      b
    jr      c, .run_frame
    ld      (hl), #0
    ld      a, (#miner_run_idx)
    inc     a
    cp      #6
    jr      c, .run_ok
    xor     a
  .run_ok:
    ld      (#miner_run_idx), a
  .run_frame:
    ld      a, (#miner_run_idx)
    jp      miner_set_sprite
