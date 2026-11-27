.globl _myDrawStringM0

.globl  cpct_setDrawCharM0_asm

HEARTS_POSITION_START_X = 46
HEARTS_POSITION_Y = 160
HEARTS_HEIGHT = 12
HEARTS_WIDTH = 7
HEARTS_PADDING = 10

SCORE_HEIGHT = 12
SCORE_WIDTH = 7

MARCO_TOP_LEFT_POSITION_X = 0
MARCO_TOP_RIGHT_POSITION_X = 40
MARCO_TOP_POSITION_Y = 138
MARCO_BOTTOM_POSITION_Y = 180
MARCO_HALF_TOP_HEIGHT = 17
MARCO_HALF_TOP_WIDTH = 40


MARCO_LEFT_POSITION_X = 2
MARCO_RIGHT_POSITION_X = 75
MARCO_LEFT_POSITION_Y = 150
MARCO_LEFT_HEIGHT = 30
MARCO_LEFT_WIDTH = 3

.globl newPoints
.globl  points
.globl points_string

.globl sys_stats_update
.globl sys_stats_init

.globl _spr_full_heart
.globl _spr_empty_heart
.globl player_hits
.globl player_lives

.globl _spr_marco_top_left
.globl _spr_marco_top_right

.globl _spr_marco_left

.globl sys_hud_render
.globl hud_dirty
