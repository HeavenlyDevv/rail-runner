.include "cpctelera.h.s"
.include "man/entity.h.s"
.include "sys/render.h.s"
.include "sys/generator.h.s"
.include "sys/animated.h.s"
.include "man/menu.h.s"
.include "globals.h.s"
.include "sys/physics.h.s"

level::                     ; Indica las propiedades del nivel actual
    .db     01              ; +0  level
    .db     20              ; +1  currentLoopCount (velocidad a la que spawnean trenes)
    .db     01              ; +2  vx del tren
    .db     00              ; +3  puntos actuales (sin el 0 del final)
    .db     10              ; +4  puntos objetivo para pasar de nivel
    .db     0x00            ; +5  patrones posibles

;; Parametros por nivel (se aplican UNA vez al empezar el nivel). Todo en frames de 50 Hz:
;;   spawn tren   : frames entre vagones
;;   velocidad    : 1/256 de byte por frame
;;   objetivo     : puntos para pasar de nivel
;;   spawn lampara: frames entre lamparas
;;   separacion   : bytes entre lamparas = velocidad * spawn lampara / 256 (para colgarlas
;;                  ya repartidas por el techo al empezar el nivel)
;;   carrera      : frames por cada frame del ciclo de carrera del minero (mas rapido = piernas
;;                  mas rapidas, al ritmo del suelo)
;;   salto        : velocidad del salto/agachada en 1/4 de paso de tabla por frame (4 = normal)
LEVEL_PARAMS_SIZE = 7
level_params:
;;           spawn  vel  obj  lamp sep carrera salto
    .db      45,  90, 20,  80, 28,   6,     4   ; nivel 1
    .db      34, 135, 40,  51, 27,   5,     5   ; nivel 2
    .db      22, 180, 45,  40, 29,   4,     6   ; nivel 3
    .db      16, 225, 50,  23, 21,   3,     7   ; nivel 4

lamp_spacing:   .db 21

FIRST_TRAIN_DELAY = 114         ; frames hasta el primer vagon (~2.3 s)

currentLoopCount:
    .db #20

set_lampara_loop_count:
    .db 0

lampara_loop_count:
    .db 0x31

trains:
    .db 0x00, 0x00, 0x00    ; 0x00
    ;   gem   diam  gold      tnt

Rows:
  .db #row_1+train_offset
  .db #row_2+train_offset
  .db #row_3+train_offset

;==================================================================================================
;   Called by:  game/man_game_init
;   Desc:       Copia los parametros del nivel actual a "level" y reinicia los contadores

sys_generator_init::
    ld      a, (#level)
    dec     a                       ; nivel 1..4 -> indice 0..3
    ld      e, a
    add     a                       ; * 7 (LEVEL_PARAMS_SIZE)
    add     e                       ; * 3
    add     a                       ; * 6
    add     e                       ; * 7
    ld      e, a
    ld      d, #0
    ld      hl, #level_params
    add     hl, de

    ld      a, (hl)                 ; frecuencia de trenes
    ld      (#level + velocidad_spawn), a
    inc     hl
    ld      a, (hl)                 ; velocidad
    ld      (#level + velocidad), a
    inc     hl
    ld      a, (hl)                 ; objetivo
    ld      (#level + puntos_objetivo), a
    inc     hl
    ld      a, (hl)                 ; frecuencia de lamparas
    ld      (#set_lampara_loop_count), a
    ld      (#lampara_loop_count), a
    inc     hl
    ld      a, (hl)                 ; separacion entre lamparas
    ld      (#lamp_spacing), a
    inc     hl
    ld      a, (hl)                 ; ritmo de carrera del minero
    ld      (#miner_run_frame_time), a
    inc     hl
    ld      a, (hl)                 ; velocidad de salto/agachada
    ld      (#miner_move_rate), a

    ld      a, #FIRST_TRAIN_DELAY
    ld      (#currentLoopCount), a

    xor     a
    ld      hl, #trains
    ld      (hl), a
    inc     hl
    ld      (hl), a
    inc     hl
    ld      (hl), a
    ret

;======================
setGem:
    ld      hl, #frames_tren_gemas
    ld      indx_frames+1(ix), h
    ld      indx_frames(ix), l

    ld      hl, #_spr_trenv3_gemas_1_m
    ld      indx_sprite+1(ix), h
    ld      indx_sprite(ix), l

    xor     a
    ld      (iy), a

    ld      a, indx_flags(ix)
    and     #is_masked | is_bgdraw
    or      #train_gemas
    ld      indx_flags(ix), a

    ret

setDiamond:
    ld       hl, #frames_tren_diamante
    ld      indx_frames+1(ix), h
    ld      indx_frames(ix), l
    xor      a
    ld       1(iy), a

    ld      hl, #_spr_trenv3_diamante_1_m
    ld      indx_sprite+1(ix), h
    ld      indx_sprite(ix), l

    ld      a, indx_flags(ix)
    and     #is_masked | is_bgdraw
    or      #train_diamante
    ld      indx_flags(ix), a

    ret

setGold:

    ld       hl, #frames_tren_oro
    ld      indx_frames+1(ix), h
    ld      indx_frames(ix), l
    xor      a
    ld       2(iy), a

    ld      hl, #_spr_trenv3_oro_1_m
    ld      indx_sprite+1(ix), h
    ld      indx_sprite(ix), l

    ld      a, indx_flags(ix)
    and     #is_masked | is_bgdraw
    or      #train_oro
    ld      indx_flags(ix), a

    ret

setTnt:

    ld       hl, #frames_tren_tnt
    ld      indx_frames+1(ix), h
    ld      indx_frames(ix), l

    ld      hl, #_spr_trenv3_tnt_1_m
    ld      indx_sprite+1(ix), h
    ld      indx_sprite(ix), l

    ld      a, indx_flags(ix)
    and     #is_masked | is_bgdraw
    or      #train_tnt
    ld      indx_flags(ix), a

    ret

;==================================================================
;   Tipo de vagon: secuencia determinista (cada 6 oro, cada 11 diamante, cada 16 gemas)
sys_generate_type:

    ld      iy, #trains
    ld      a, (iy)
    cp      #15
    jp      z, setGem
    inc     a
    ld      (iy), a

    ld      a, 1(iy)
    cp      #10
    jp      z, setDiamond
    inc     a
    ld      1(iy), a

    ld      a, 2(iy)
    cp      #5
    jp      z, setGold
    inc     a
    ld      2(iy), a

    jp      setTnt

;; devuelve en E la fila de un carril aleatorio (0, 1 o 2 con la misma probabilidad:
;; se tira un numero de 0 a 3 y el 3 se descarta).
getRandomRow::
    call    cpct_getRandom_xsp40_u8_asm
    and     #3
    cp      #3
    jr      z, getRandomRow             ; descartar el 3 y volver a tirar

    ld      c, a
    ld      b, #0
    ld      hl, #Rows
    add     hl, bc
    ld      e, (hl)
    ret

;; Fraccion inicial (xfrac) aleatoria. Si todos los vagones nacieran con xfrac = 0, al salir
;; cada 91 frames (= 16 pasos de 5.69 frames) avanzarian todos en el MISMO frame: ese frame
;; tendria que redibujarlos todos y los demas no harian nada. Asi se reparten.
random_phase:
    push    ix
    call    cpct_getRandom_xsp40_u8_asm
    pop     ix
    ld      indx_xfrac(ix), a
    ret

sys_generate_random_tren::

    ld      ix, #templ_tren
    call    sys_generate_type
    call    getRandomRow
    ld      a, e
    ld      indx_y(ix), a

    ld      a, (#level + velocidad)
    ld      indx_vx(ix), a
    call    random_phase                ; fraccion inicial aleatoria (ver abajo)

    ld      hl, #templ_tren
    call    create_template             ; si el array esta lleno no se crea (carry)

    ld      a, (#level + velocidad_spawn)
    ld      (#currentLoopCount), a

    ret

sys_generate_lampara::

    ld      ix, #templ_lampara
    ld      hl, #_spr_lampara_1
    ld      indx_sprite+1(ix), h
    ld      indx_sprite(ix), l

    ld      a, #70
    ld      indx_x(ix), a
    ld      a, (#level + velocidad)
    ld      indx_vx(ix), a
    call    random_phase

    ld      hl, #templ_lampara
    call    create_template

    ld      a, (#set_lampara_loop_count)
    ld      (#lampara_loop_count), a

    ret

;==================================================================================================
;   Called by:  game/man_game_init
;   Desc:       Al empezar el nivel las lamparas ya cuelgan del techo, repartidas con la misma
;               separacion que tendran al ir apareciendo.

sys_generator_prefill_lamps::
    ld      a, #70
  .pf_loop:
    push    af
    ld      ix, #templ_lampara
    ld      indx_x(ix), a
    ld      a, (#level + velocidad)
    ld      indx_vx(ix), a
    call    random_phase
    ld      hl, #templ_lampara
    call    create_template
    pop     af
    ld      b, a
    ld      a, (#lamp_spacing)
    ld      c, a
    ld      a, b
    sub     c
    jr      nc, .pf_loop
    ret

;==================================================================================================
;   Called by:  game/man_game_play
;   Desc:       Cuenta atras para generar trenes y lamparas.

sys_generator_update::
    ld      a, (#currentLoopCount)
    or      a
    jp      z, sys_generate_random_tren

    dec     a
    ld      (#currentLoopCount), a

    ;;; === GENERADO DE LAMPARAS ===

    ld      a, (#lampara_loop_count)
    or      a
    jp      z, sys_generate_lampara

    dec     a
    ld      (#lampara_loop_count), a

    ret
