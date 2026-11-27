.include "man/menu.h.s"
.include "sys/screen.h.s"
.include "sys/input.h.s"
.include "man/entity.h.s"
.include "cpctelera.h.s"
.include "globals.h.s"
.include "sys/generator.h.s"
.include "sys/time.h.s"
.include "sys/render.h.s"
.include "sys/animated.h.s"
level_string: .asciz "LEVEL"

num_level_string: .db 0, 0   ; digito + terminador

;; Pausa de las pantallas de nivel y victoria: 7 * 100 halts / 300 Hz = 2,3 s
SCREEN_WAIT_B = 7
SCREEN_WAIT_C = 100

man_show_level:

    ld hl, #0x8000
    call reset_buffer

    ld hl, #0xC000
    call reset_buffer

    call man_draw_level
    call switch_buf
    ld b, #SCREEN_WAIT_B
    ld c, #SCREEN_WAIT_C
    call wait_halts

    ret

man_draw_level:

  ; ==== DRAW LEVEL STRING ====
    ld      l, #14
    ld      h, #0

    call    cpct_setDrawCharM0_asm
    
    ld      c, #20
    ld      b, #60
    ld de, (start_mem)

    call cpct_getScreenPtr_asm 

    ld      iy, #level_string
    call    _myDrawStringM0

  ; === DRAW LEVEL NUMBER ===

  ld    hl,   #level
  ld    a, (hl)            ;; Muevo a la derecha para pintar el lado izquierdo
  add   #48
  ld    (#num_level_string), a

  ld      c, #50
  ld      b, #60
  ld de, (start_mem)

  call cpct_getScreenPtr_asm 

  ld      iy, #num_level_string
  call    _myDrawStringM0
   
  ret

man_init_menu:

  ld c, #0
  call cpct_setVideoMode_asm

  cpctm_setBorder_asm HW_BLACK

  ld l, #0
  ld h, #HW_BLACK
  call cpct_setPALColour_asm

  ld   hl, #_main_palette
  ld   de, #16
  call cpct_setPalette_asm

  ld hl, #0x8000
  call reset_buffer

  ld hl, #0xC000
  call reset_buffer

  ret

draw_components:

  ; ------- PICO ----------------
  ld d, #PICO_HEIGHT
  ld e, #PICO_WIDTH

  ld hl, #_spr_pico
  ld c, #PICO_POSITION_X
  ld b, #PICO_POSITION_Y

  call sys_draw_sprite

  ; ------- AIL ----------------

  ld d, #AIL_HEIGHT
  ld e, #AIL_WIDTH

  ld hl, #_spr_ail_text
  ld c, #AIL_POSITION_X
  ld b, #AIL_POSITION_Y

  call sys_draw_sprite

  ; ------- RUNNER ----------------

  ld d, #RUNNER_HEIGHT
  ld e, #RUNNER_WIDTH

  ld hl, #_spr_runner_text
  ld c, #RUNNER_POSITION_X
  ld b, #RUNNER_POSITION_Y

  call sys_draw_sprite

  ; ------- PRESS PLAY ----------------

  ld d, #PRESS_PLAY_HEIGHT
  ld e, #PRESS_PLAY_WIDTH

  ld hl, #_spr_press_play 
  ld c, #PRESS_PLAY_POSITION_X
  ld b, #PRESS_PLAY_POSITION_Y

  call sys_draw_sprite

  ; ------- PRESS INSTRUCTIONS ----------------

  ld d, #PRESS_INSTRUCTIONS_HEIGHT
  ld e, #PRESS_INSTRUCTIONS_WIDTH

  ld hl, #_spr_press_instructions 
  ld c, #PRESS_INSTRUCTIONS_POSITION_X
  ld b, #PRESS_INSTRUCTIONS_POSITION_Y

  call sys_draw_sprite

  ret

draw_components_instructions:
  ; ------- MINOR UP ----------------

  ld d, #MINERO_SPRITE_HEIGHT
  ld e, #MINERO_SPRITE_WIDTH  ;24/2

  ld hl, #_spr_minero_m1 
  ld c, #10
  ld b, #1

  call sys_draw_masked_at

  ; ------- MINOR DOWN ----------------

  ld d, #MINERO_SPRITE_HEIGHT
  ld e, #MINERO_SPRITE_WIDTH

  ld hl, #_spr_minero_m2 
  ld c, #10
  ld b, #31

  call sys_draw_masked_at

    ; ------- VAGON TNT ----------------

  ld d, #TREN_SPRITE_HEIGHT
  ld e, #TREN_SPRITE_WIDTH  ;24/2

  ld hl, #_spr_trenv3_tnt_1_m 
  ld c, #8
  ld b, #68

  call sys_draw_masked_at

  ; ------- VAGON ORO ----------------

  ld d, #TREN_SPRITE_HEIGHT
  ld e, #TREN_SPRITE_WIDTH

  ld hl, #_spr_trenv3_oro_1_m 
  ld c, #8
  ld b, #98

  call sys_draw_masked_at

    ; ------- VAGON DIAMANTE ----------------

  ld d, #TREN_SPRITE_HEIGHT
  ld e, #TREN_SPRITE_WIDTH  

  ld hl, #_spr_trenv3_diamante_1_m 
  ld c, #8
  ld b, #128

  call sys_draw_masked_at

  ; ------- VAGON GEMA ----------------

  ld d, #TREN_SPRITE_HEIGHT
  ld e, #TREN_SPRITE_WIDTH

  ld hl, #_spr_trenv3_gemas_1_m 
  ld c, #8
  ld b, #158

  call sys_draw_masked_at

  ; ------- TEXTO TNT ----------------

  ld d, #TXT_TNT_HEIGHT
  ld e, #TXT_TNT_WIDTH

  ld hl, #_spr_tnt
  ld c, #TXT_TNT_POSITION_X
  ld b, #TXT_TNT_POSITION_Y

  call sys_draw_sprite

  ; ------- TEXTO ORO ----------------

  ld d, #TXT_ORO_HEIGHT
  ld e, #TXT_ORO_WIDTH

  ld hl, #_spr_oro
  ld c, #TXT_ORO_POSITION_X
  ld b, #TXT_ORO_POSITION_Y

  call sys_draw_sprite

    ; ------- TEXTO DIAMANTE ----------------

  ld d, #TXT_DIAMANTE_HEIGHT
  ld e, #TXT_DIAMANTE_WIDTH

  ld hl, #_spr_diamante
  ld c, #TXT_DIAMANTE_POSITION_X
  ld b, #TXT_DIAMANTE_POSITION_Y

  call sys_draw_sprite

  ; ------- TEXTO GEMA ----------------

  ld d, #TXT_GEMA_HEIGHT
  ld e, #TXT_GEMA_WIDTH

  ld hl, #_spr_gema
  ld c, #TXT_GEMA_POSITION_X
  ld b, #TXT_GEMA_POSITION_Y

  call sys_draw_sprite

    ; ------- PUNTUACION TNT ----------------

  ld d, #PUNTOS_TNT_HEIGHT
  ld e, #PUNTOS_TNT_WIDTH

  ld hl, #_spr_tnt_puntos
  ld c, #PUNTOS_TNT_POSITION_X
  ld b, #PUNTOS_TNT_POSITION_Y

  call sys_draw_sprite

  ; ------- PUNTUACION ORO ----------------

  ld d, #PUNTOS_ORO_HEIGHT
  ld e, #PUNTOS_ORO_WIDTH

  ld hl, #_spr_oro_puntos
  ld c, #PUNTOS_ORO_POSITION_X
  ld b, #PUNTOS_ORO_POSITION_Y

  call sys_draw_sprite

    ; ------- PUNTUACION DIAMANTE ----------------

  ld d, #PUNTOS_DIAMANTE_HEIGHT
  ld e, #PUNTOS_DIAMANTE_WIDTH

  ld hl, #_spr_diamante_puntos
  ld c, #PUNTOS_DIAMANTE_POSITION_X
  ld b, #PUNTOS_DIAMANTE_POSITION_Y

  call sys_draw_sprite

  ; ------- PUNTUACION GEMA ----------------

  ld d, #PUNTOS_GEMA_HEIGHT
  ld e, #PUNTOS_GEMA_WIDTH

  ld hl, #_spr_gema_puntos
  ld c, #PUNTOS_GEMA_POSITION_X
  ld b, #PUNTOS_GEMA_POSITION_Y

  call sys_draw_sprite

  ; ------- ARROW UP ----------------

  ld d, #ARROW_UP_HEIGHT
  ld e, #ARROW_UP_WIDTH

  ld hl, #_spr_up 
  ld c, #ARROW_UP_POSITION_X
  ld b, #ARROW_UP_POSITION_Y

  call sys_draw_sprite

  ; ------- ARROW DOWN ----------------

  ld d, #ARROW_DOWN_HEIGHT
  ld e, #ARROW_DOWN_WIDTH

  ld hl, #_spr_down
  ld c, #ARROW_DOWN_POSITION_X
  ld b, #ARROW_DOWN_POSITION_Y

  call sys_draw_sprite
  ; ------- O BUTTON ----------------

  ld d, #O_HEIGHT
  ld e, #O_WIDTH

  ld hl, #_spr_o
  ld c, #O_POSITION_X
  ld b, #O_POSITION_Y

  call sys_draw_sprite
  ; ------- P BUTTON ----------------

  ld d, #P_HEIGHT
  ld e, #P_WIDTH

  ld hl, #_spr_p
  ld c, #P_POSITION_X
  ld b, #P_POSITION_Y

  call sys_draw_sprite

  ; ------------ PLAY -----------------
  ld d, #PRESS_PLAY_HEIGHT
  ld e, #PRESS_PLAY_WIDTH

  ld hl, #_spr_press_play 
  ld c, #15
  ld b, #190

  call sys_draw_sprite

  ret
  
man_show_game_over::

  ld hl, #0x8000
  call reset_buffer

  ld hl, #0xC000
  call reset_buffer

  call draw_components_gameover
  call switch_buf
   
  ;; Output: A = 1 reintentar (R), 0 volver al menu (Q)
  input_loop:
    ld      hl, #Key_R
    call    cpct_isKeyPressed_asm
    ld      a, #1
    ret     nz

    ld      hl, #Key_Q
    call    cpct_isKeyPressed_asm
    ld      a, #0
    ret     nz

  jr input_loop

man_show_winner::

  ld hl, #0x8000
  call reset_buffer

  ld hl, #0xC000
  call reset_buffer

  call draw_components_winner
  call switch_buf

  ld b, #SCREEN_WAIT_B
  ld c, #SCREEN_WAIT_C
  call wait_halts

  ret

draw_components_winner:

 
  ; ------- winner ----------------

  ld d, #WINNER_HEIGHT
  ld e, #WINNER_WIDTH

  ld hl, #_spr_winner
  ld c, #WINNER_POSITION_X
  ld b, #WINNER_POSITION_Y

  call sys_draw_sprite
  ret

draw_components_gameover:

  ; ------- gameover ----------------
  ld d, #GAMEOVER_HEIGHT
  ld e, #GAMEOVER_WIDTH

  ld hl, #_spr_gameover
  ld c, #GAMEOVER_POSITION_X
  ld b, #GAMEOVER_POSITION_Y

  call sys_draw_sprite

  ; ------- R ----------------

  ld d, #R_HEIGHT
  ld e, #R_WIDTH

  ld hl, #_spr_r
  ld c, #R_POSITION_X
  ld b, #R_POSITION_Y

  call sys_draw_sprite

  ; ------- Q ----------------

  ld d, #Q_HEIGHT
  ld e, #Q_WIDTH

  ld hl, #_spr_q
  ld c, #Q_POSITION_X
  ld b, #Q_POSITION_Y

  call sys_draw_sprite

  ; ------- RETRY ----------------

  ld d, #RETRY_HEIGHT
  ld e, #RETRY_WIDTH

  ld hl, #_spr_retry
  ld c, #RETRY_POSITION_X
  ld b, #RETRY_POSITION_Y

  call sys_draw_sprite

  ; ------- BACKMENU ----------------

  ld d, #BACKMENU_HEIGHT
  ld e, #BACKMENU_WIDTH

  ld hl, #_spr_backmenu 
  ld c, #BACKMENU_POSITION_X
  ld b, #BACKMENU_POSITION_Y

  call sys_draw_sprite

  ret

show_menu::

  call man_init_menu

  loop:

    call draw_components
    call switch_buf
    
    call    cpct_scanKeyboard_asm

    ld      hl, #Key_Return
    call    cpct_isKeyPressed_asm
    ret     nz                      ; Enter: empezar partida

    ld      hl, #Key_I
    call    cpct_isKeyPressed_asm
    jr      z, loop

    jp      mostrar_instrucciones   ; sus RET vuelven al llamador de show_menu


mostrar_instrucciones:

  ld hl, #0x8000
  call reset_buffer

  ld hl, #0xC000
  call reset_buffer

  loop_ins:
    call draw_components_instructions
    call switch_buf

    call    cpct_scanKeyboard_asm
    ld      hl, #Key_Return
    call    cpct_isKeyPressed_asm
    jr      z, loop_ins

  ret                               ; Enter: empezar partida
