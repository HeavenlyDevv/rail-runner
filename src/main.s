.include "sys/time.h.s"

.include "cpctelera.h.s"
.include "man/game.h.s"
.include "man/menu.h.s"
.include "globals.h.s"
.include "man/interruptions.h.s"

.area _DATA
.area _CODE

;==================================================================================================
;   Maquina de estados principal
;
;   Cada pantalla es una funcion que se llama con CALL y devuelve el control con RET.
;   Ninguna pantalla salta (JP) a etiquetas de otro modulo: asi la pila nunca crece y
;   el flujo es MENU -> NUEVA PARTIDA -> NIVEL -> (NIVEL SUPERADO | GAME OVER | VICTORIA).
;
;   man_game_play devuelve en A el resultado del nivel:
;       RESULT_LEVEL_DONE  -> se pasa al siguiente nivel (o a la victoria tras el ultimo)
;       RESULT_GAME_OVER   -> pantalla de game over (R = reintentar nivel, Q = menu)
;==================================================================================================

_main::
   ld    sp, #0x8000                  ; la pila crece hacia abajo desde 0x7FFF (debajo de los buffers)
   call  cpct_disableFirmware_asm

   ld    hl, #man_interruption
   call  cpct_setInterruptHandler_asm ; el wrapper de CPCtelera guarda los registros y hace ei/reti

main_loop::
   ld    sp, #0x8000                  ; defensivo: cada vuelta al menu empieza con la pila limpia
   call  show_menu
   call  man_new_game                 ; nivel 1, puntos 0, vidas llenas

next_level:
   call  man_show_level
   call  man_game_init
   call  man_game_play                ; A = resultado

   cp    #RESULT_GAME_OVER
   jr    z, game_over_screen

   ;; Nivel superado
   call  man_next_level               ; Z = no quedan mas niveles
   jr    nz, next_level

   call  man_show_winner
   jr    main_loop

game_over_screen:
   call  man_show_game_over           ; A = 1 reintentar, 0 volver al menu
   or    a
   jr    z, main_loop
   call  man_retry_level              ; mismo nivel, progreso y puntos del nivel a cero
   jr    next_level
