.globl man_show_level
  ; ------- PICO ----------------
PICO_POSITION_X = 10
PICO_POSITION_Y = 20
PICO_HEIGHT = 37
PICO_WIDTH = 18

  ; ------- AIL ----------------
AIL_POSITION_X = 28
AIL_POSITION_Y = 45
AIL_HEIGHT = 12
AIL_WIDTH = 16

  ; ------- RUNNER ----------------
RUNNER_POSITION_X = 30
RUNNER_POSITION_Y = 60
RUNNER_HEIGHT = 12
RUNNER_WIDTH = 37

  ; ------- PRESS PLAY ----------------
PRESS_PLAY_POSITION_X = 15
PRESS_PLAY_POSITION_Y = 100
PRESS_PLAY_HEIGHT = 8
PRESS_PLAY_WIDTH = 49

  ; ------- PRESS INSTRUCTIONS ----------------
PRESS_INSTRUCTIONS_POSITION_X = 20
PRESS_INSTRUCTIONS_POSITION_Y = 130
PRESS_INSTRUCTIONS_HEIGHT = 7
PRESS_INSTRUCTIONS_WIDTH = 39

 ; ------------- I N S T R U C T I O N S ----------

   ; ------- UP ----------------
ARROW_UP_POSITION_X = 35
ARROW_UP_POSITION_Y = 6
ARROW_UP_HEIGHT = 8
ARROW_UP_WIDTH = 4
  ; ------- DOWN ----------------
ARROW_DOWN_POSITION_X = 35
ARROW_DOWN_POSITION_Y = 36
ARROW_DOWN_HEIGHT = 8
ARROW_DOWN_WIDTH = 4
  ; ------- PRESS INSTRUCTIONS ----------------
O_POSITION_X = 65
O_POSITION_Y = 6
O_HEIGHT = 9
O_WIDTH = 6

P_POSITION_X = 65
P_POSITION_Y = 36
P_HEIGHT = 9
P_WIDTH = 6

; ------- tnt ----------------
TXT_TNT_POSITION_X = 32
TXT_TNT_POSITION_Y = 75
TXT_TNT_HEIGHT = 8
TXT_TNT_WIDTH = 14

PUNTOS_TNT_POSITION_X = 62
PUNTOS_TNT_POSITION_Y = 75
PUNTOS_TNT_HEIGHT = 4
PUNTOS_TNT_WIDTH = 11
; ------- oro ----------------
TXT_ORO_POSITION_X = 30
TXT_ORO_POSITION_Y = 105
TXT_ORO_HEIGHT = 8
TXT_ORO_WIDTH = 17

PUNTOS_ORO_POSITION_X = 62
PUNTOS_ORO_POSITION_Y = 105
PUNTOS_ORO_HEIGHT = 9
PUNTOS_ORO_WIDTH = 11
; ------- diamante ----------------
TXT_DIAMANTE_POSITION_X = 25
TXT_DIAMANTE_POSITION_Y = 135
TXT_DIAMANTE_HEIGHT = 8
TXT_DIAMANTE_WIDTH = 28

PUNTOS_DIAMANTE_POSITION_X = 62
PUNTOS_DIAMANTE_POSITION_Y = 135
PUNTOS_DIAMANTE_HEIGHT = 9
PUNTOS_DIAMANTE_WIDTH = 11
; ------- gema ----------------
TXT_GEMA_POSITION_X = 32
TXT_GEMA_POSITION_Y = 165
TXT_GEMA_HEIGHT = 8
TXT_GEMA_WIDTH = 13

PUNTOS_GEMA_POSITION_X = 62
PUNTOS_GEMA_POSITION_Y = 165
PUNTOS_GEMA_HEIGHT = 9
PUNTOS_GEMA_WIDTH = 11

; ------- GAME OVER -------------
GAMEOVER_POSITION_X = 25
GAMEOVER_POSITION_Y = 20
GAMEOVER_HEIGHT = 26
GAMEOVER_WIDTH = 25

R_POSITION_X = 15
R_POSITION_Y = 80
R_HEIGHT = 9
R_WIDTH = 6

Q_POSITION_X = 15
Q_POSITION_Y = 105
Q_HEIGHT = 9
Q_WIDTH = 6

BACKMENU_POSITION_X = 30
BACKMENU_POSITION_Y = 105
BACKMENU_HEIGHT = 8
BACKMENU_WIDTH = 43

RETRY_POSITION_X = 30
RETRY_POSITION_Y = 80
RETRY_HEIGHT = 8
RETRY_WIDTH = 19





.globl cpct_scanKeyboard_asm
.globl cpct_isKeyPressed_asm

.globl cpct_setVideoMode_asm

.globl cpct_setPALColour_asm

.globl cpct_setPalette_asm
.globl _myDrawStringM0
.globl cpct_setDrawCharM0_asm

.globl show_menu

.globl _spr_ail_text
.globl _spr_pico
.globl _spr_runner_text

.globl _spr_press_play
.globl _spr_press_instructions

;INSTRUCTIONS

.globl _spr_o
.globl _spr_p

.globl _spr_down
.globl _spr_up


.globl _spr_tnt
.globl _spr_oro
.globl _spr_diamante
.globl _spr_gema

.globl _spr_tnt_puntos
.globl _spr_oro_puntos
.globl _spr_diamante_puntos
.globl _spr_gema_puntos

;---------game over---------

.globl _spr_q
.globl _spr_r
.globl _spr_retry
.globl _spr_backmenu
.globl _spr_gameover

.globl man_show_game_over
.globl man_show_winner


;---------- winner --------

.globl _spr_winner
; ------------- WINNER -----------


WINNER_POSITION_X = 20
WINNER_POSITION_Y = 40
WINNER_HEIGHT = 14
WINNER_WIDTH = 50
