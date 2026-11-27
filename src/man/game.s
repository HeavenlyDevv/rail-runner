.include "man/entity.h.s"
.include "sys/render.h.s"
.include "sys/input.h.s"
.include "sys/time.h.s"
.include "sys/animated.h.s"
.include "sys/physics.h.s"
.include "sys/prerender.h.s"
.include "man/menu.h.s"
.include "sys/screen.h.s"
.include "sys/stats.h.s"
.include "sys/generator.h.s"
.include "sys/colisions.h.s"
.include "man/game.h.s"
.include "globals.h.s"
.include "sys/rails.h.s"
.include "man/interruptions.h.s"

.globl cpct_waitVSYNC_asm

level_start_points:     ; puntos al empezar el nivel actual (para "reintentar")
    .dw 0x0000

;==================================================================================================
;   Called by:  main.s
;   Desc:
;       Deja todo el estado de partida como recien encendido: nivel 1, puntos 0, vidas llenas.

man_new_game::
    ld      a, #1
    ld      (#level), a
    ld      hl, #0x0000
    ld      (#points), hl
    ld      (#level_start_points), hl
    jr      man_retry_level_keep_points

;==================================================================================================
;   Called by:  main.s (tras game over + R)
;   Desc:
;       Repite el nivel actual: vidas llenas, progreso del nivel a 0 y la puntuacion
;       vuelve a la que habia al empezar el nivel.

man_retry_level::
    ld      hl, (#level_start_points)
    ld      (#points), hl
man_retry_level_keep_points:
    xor     a
    ld      (#player_hits), a
    ld      (#level + puntos_actuales), a
    ret

;==================================================================================================
;   Called by:  main.s (tras superar un nivel)
;   Output: Z si ya no quedan niveles (victoria), NZ si hay que jugar el siguiente
;   Desc:   Avanza de nivel y guarda la puntuacion de inicio para "reintentar".

man_next_level::
    ld      hl, (#points)
    ld      (#level_start_points), hl
    xor     a
    ld      (#level + puntos_actuales), a
    ld      a, (#level)
    inc     a
    ld      (#level), a
    cp      #NUM_LEVELS + 1
    ret

;==================================================================================================
;   Called by:  main.s
;   Desc:       Prepara un nivel: entidades, pantalla y parametros del nivel actual

man_game_init::
    call    man_entity_init     ; Inicializa el array de entidades colocando todas las pos. a 0
    call    sys_render_init     ; Prepara la pantalla vaciandola, poniendo border y ajustando paleta
    call    sys_generator_init  ; Parametros del nivel (velocidad, frecuencia de trenes...)
    call    sys_input_init      ; Sin teclas pendientes de un menu anterior
    call    sys_physics_init    ; El minero empieza quieto en su carril
    xor     a
    ld      (#inmortal), a
    ld      hl, #0x0000
    ld      (#newPoints), hl

    call    sys_templates_init  ; crea el minero (siempre e_array[0])
    call    sys_generator_prefill_lamps ; lamparas ya colgadas al empezar
    ret

;==================================================================================================
;   Un paso de logica = 1/50 s de juego (todas las velocidades y tiempos estan en frames)

logic_step::
    call    sys_typeInput           ; teclado (escaneado en la interrupcion de VSYNC)
    call    sys_physics_update      ; mover, chocar y animar (un solo recorrido)
    call    sys_generator_update    ; nuevos vagones y lamparas
    call    sys_rails_update        ; frame de la animacion de los railes
    call    sys_stats_update        ; sumar puntos
    jp      man_entity_update       ; eliminar las entidades ya borradas de los dos buffers

;==================================================================================================
;   Called by:  main.s
;   Output: A = RESULT_LEVEL_DONE | RESULT_GAME_OVER
;   Desc:
;       Bucle con paso de logica fijo: se dibuja un frame, se espera al VSYNC, se muestra y se
;       ejecutan tantos pasos de logica como frames hayan pasado (normalmente 1). Si un frame
;       cuesta mas de 20 ms el juego no se ralentiza: hace 2 pasos y se ve a 25 fps ese momento.
;       Unico punto de salida: un RET con el resultado en A.

MAX_STEPS = 4
PACE_HOLD = 25                          ; vueltas a 25 fps (1 s) antes de reintentar 50

pace_frames:    .db 1
pace_hold:      .db 0

man_game_play::

    ld      hl, #0x8000
    call    reset_buffer        ; Limpia 0x8000-0xBFFF
    ld      hl, #0xC000
    call    reset_buffer        ; Limpia 0xC000-0xFFFF

    call    sys_stats_init      ; bordes + "SCORE" en los dos buffers
    call    sys_rails_init      ; railes en los dos buffers

    xor     a
    ld      (#frame_count), a

    game_loop:
        call    sys_render_frame        ; dibuja en el buffer oculto solo lo que ha cambiado
        call    sys_hud_render          ; corazones y puntos si han cambiado

    game_wait::                         ; (etiqueta global: solo para medir con el emulador)
        ;; Ritmo: 1 frame por vuelta (50 fps) mientras quepa. Si una vuelta se pasa, se fija
        ;; 2 frames por vuelta (25 fps estables) un rato: un ritmo estable se ve mas suave que
        ;; ir saltando entre 1, 2 y 3 frames.
        ld      hl, #pace_frames
        ld      a, (#frame_count)       ; VSYNCs desde que se mostro el frame anterior
        cp      (hl)
        jr      c, .on_time
        ld      (hl), #2                ; se ha pasado: 25 fps durante PACE_HOLD vueltas
        ld      b, a
        ld      a, #PACE_HOLD
        ld      (#pace_hold), a
        ld      a, b
        inc     a                       ; y esperar a un VSYNC nuevo (sin mostrar a medias)
        jr      .wait_target
    .on_time:
        ld      a, (hl)
    .wait_target:
        ld      hl, #frame_count
    .wait_vsync:
        cp      (hl)
        jr      z, .wait_check
        jr      nc, .wait_vsync
    .wait_check:
        ld      a, (#pace_hold)         ; ¿toca volver a intentar 50 fps?
        or      a
        jr      z, .pace_done
        dec     a
        ld      (#pace_hold), a
        jr      nz, .pace_done
        ld      a, #1
        ld      (#pace_frames), a
    .pace_done:
        call    switch_buf              ; mostrar lo dibujado; el otro buffer pasa a ser el oculto

        di
        ld      a, (#frame_count)       ; frames transcurridos = pasos de logica
        ld      b, a
        xor     a
        ld      (#frame_count), a
        ei
        ld      a, b
        cp      #MAX_STEPS + 1
        jr      c, .steps
        ld      b, #MAX_STEPS

    .steps:
        push    bc
        call    logic_step

        ld      a, (#player_lives)      ;; ¿Sin vidas?
        ld      b, a
        ld      a, (#player_hits)
        cp      b
        jr      nc, .game_over

        ld      a, (#level + puntos_actuales)   ;; ¿Nivel superado?
        ld      b, a
        ld      a, (#level + puntos_objetivo)
        cp      b
        jr      z, .level_done
        jr      c, .level_done

        pop     bc
        djnz    .steps
        jr      game_loop

    .level_done:
        pop     bc
        ld      a, #RESULT_LEVEL_DONE
        ret

    .game_over:
        pop     bc
        ld      a, #RESULT_GAME_OVER
        ret
