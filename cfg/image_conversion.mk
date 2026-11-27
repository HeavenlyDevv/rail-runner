##-----------------------------LICENSE NOTICE------------------------------------
##  This file is part of CPCtelera: An Amstrad CPC Game Engine 
##  Copyright (C) 2018 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
##
##  This program is free software: you can redistribute it and/or modify
##  it under the terms of the GNU Lesser General Public License as published by
##  the Free Software Foundation, either version 3 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU Lesser General Public License for more details.
##
##  You should have received a copy of the GNU Lesser General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##------------------------------------------------------------------------------
############################################################################
##                        CPCTELERA ENGINE                                ##
##                 Automatic image conversion file                        ##
##------------------------------------------------------------------------##
## This file is intended for users to automate image conversion from JPG, ##
## PNG, GIF, etc. into C-arrays.                                          ##
############################################################################

##
## NEW MACROS
##

## 16 colours palette
PALETTE=0 1 2 3 4 9 10 11 12 13 14 15 16 20 25 26
## 17 -> 15

## Default values
#$(eval $(call IMG2SP, SET_MODE        , 0                  ))  { 0, 1, 2 }
#$(eval $(call IMG2SP, SET_MASK        , none               ))  { interlaced, none }
$(eval $(call IMG2SP, SET_FOLDER      , src/sprites/             ))
#$(eval $(call IMG2SP, SET_EXTRAPAR    ,                    ))
#$(eval $(call IMG2SP, SET_IMG_FORMAT  , sprites            ))	{ sprites, zgtiles, screen }
#$(eval $(call IMG2SP, SET_OUTPUT      , c                  ))  { bin, c }
$(eval $(call IMG2SP, SET_PALETTE_FW  , $(PALETTE)         ))
$(eval $(call IMG2SP, CONVERT_PALETTE , $(PALETTE), main_palette ))

# Minero, vagones (con sus mascaras) y railes no se convierten aqui: los genera
# tools/make_sprites.py en src/sprites/masked_sprites.s y src/sprites/rails_data.s
#$(eval $(call IMG2SP, CONVERT         , assets/minero.png ,8, 16, spr_minero))

$(eval $(call IMG2SP, CONVERT         , assets/lampara_1.png ,20, 20, spr_lampara_1))
$(eval $(call IMG2SP, CONVERT         , assets/lampara_2.png ,20, 20, spr_lampara_2))
$(eval $(call IMG2SP, CONVERT         , assets/lampara_3.png ,20, 20, spr_lampara_3))




$(eval $(call IMG2SP, CONVERT         , assets/full_heart.png ,14, 12, spr_full_heart))
$(eval $(call IMG2SP, CONVERT         , assets/empty_heart.png ,14, 12, spr_empty_heart))







$(eval $(call IMG2SP, CONVERT         , assets/marco_top_left.png ,160, 17, spr_marco_top_left))
$(eval $(call IMG2SP, CONVERT         , assets/marco_top_right.png ,160, 17, spr_marco_top_right))
$(eval $(call IMG2SP, CONVERT         , assets/marco_left.png ,6, 30, spr_marco_left))

# MENU
$(eval $(call IMG2SP, CONVERT         , assets/menu/enter_play.png ,98, 8, spr_press_play))

#$(eval $(call IMG2SP, CONVERT         , assets/menu/options.png ,138, 7, spr_press_options))
$(eval $(call IMG2SP, CONVERT         , assets/menu/press_instructions.png ,78, 7, spr_press_instructions))
#$(eval $(call IMG2SP, CONVERT         , assets/menu/instructions.png ,86, 7, spr_press_instructions))

$(eval $(call IMG2SP, CONVERT         , assets/menu/pico.png ,36, 37, spr_pico))
$(eval $(call IMG2SP, CONVERT         , assets/menu/ail_text.png ,32, 12, spr_ail_text))
$(eval $(call IMG2SP, CONVERT         , assets/menu/runner_text.png ,74, 12, spr_runner_text))


##INSTRUCCIONES
$(eval $(call IMG2SP, CONVERT         , assets/menu/o.png ,12, 9, spr_o))
$(eval $(call IMG2SP, CONVERT         , assets/menu/p.png ,12, 9, spr_p))
$(eval $(call IMG2SP, CONVERT         , assets/menu/flecha_abajo.png ,8, 8, spr_down))
$(eval $(call IMG2SP, CONVERT         , assets/menu/flecha_arriba.png ,8, 8, spr_up))

$(eval $(call IMG2SP, CONVERT         , assets/menu/tnt.png ,28, 8, spr_tnt))
$(eval $(call IMG2SP, CONVERT         , assets/menu/oro.png ,34, 8, spr_oro))
$(eval $(call IMG2SP, CONVERT         , assets/menu/diamante.png ,56, 8, spr_diamante))
$(eval $(call IMG2SP, CONVERT         , assets/menu/gema.png ,26, 8, spr_gema))

$(eval $(call IMG2SP, CONVERT         , assets/menu/1_life_less.png ,22, 4, spr_tnt_puntos))
$(eval $(call IMG2SP, CONVERT         , assets/menu/10_points.png ,22, 9, spr_oro_puntos))
$(eval $(call IMG2SP, CONVERT         , assets/menu/50_points.png ,22, 9, spr_diamante_puntos))
$(eval $(call IMG2SP, CONVERT         , assets/menu/100_points.png ,22, 9, spr_gema_puntos))

##GAMEOVER
$(eval $(call IMG2SP, CONVERT         , assets/gameover/q.png ,12, 9, spr_q))
$(eval $(call IMG2SP, CONVERT         , assets/gameover/r.png ,12, 9, spr_r))
$(eval $(call IMG2SP, CONVERT         , assets/gameover/retry.png ,38, 8, spr_retry))
$(eval $(call IMG2SP, CONVERT         , assets/gameover/back_menu.png ,86, 8, spr_backmenu))
$(eval $(call IMG2SP, CONVERT         , assets/gameover/gameover.png ,50, 26, spr_gameover))

###imagenes tren
#$(eval $(call IMG2SP, CONVERT         , assets/tren_v2_1.png ,24, 16, spr_tren_v2_1))
#$(eval $(call IMG2SP, CONVERT         , assets/tren_v2_2.png ,24, 16, spr_tren_v2_2))
#$(eval $(call IMG2SP, CONVERT         , assets/tren_v2_3.png ,24, 16, spr_tren_v2_3))
#$(eval $(call IMG2SP, CONVERT         , assets/tren_v2_4.png ,24, 16, spr_tren_v2_4))

#$(eval $(call IMG2SP, CONVERT         , assets/tren_v2_mask.png ,24, 16, spr_tren_v2_mask))

#$(eval $(call IMG2SP, CONVERT         , assets/tren.png ,18, 10, spr_tren))


##WINNER
$(eval $(call IMG2SP, CONVERT         , assets/winner/winner.png ,100, 14, spr_winner))

##
## OLD MACROS (For compatibility)
##

## Example firmware palette definition as variable in cpct_img2tileset format

# PALETTE={0 1 3 4 7 9 10 12 13 16 19 20 21 24 25 26}

## AUTOMATED IMAGE CONVERSION EXAMPLE (Uncomment EVAL line to use)
##
##    This example would convert img/example.png into src/example.{c|h} files.
##    A C-array called pre_example[24*12*2] would be generated with the definition
##    of the image example.png in mode 0 screen pixel format, with interlaced mask.
##    The palette used for conversion is given through the PALETTE variable and
##    a pre_palette[16] array will be generated with the 16 palette colours as 
##	  hardware colour values.

#$(eval $(call IMG2SPRITES,img/example.png,0,pre,24,12,$(PALETTE),mask,src/,hwpalette))



############################################################################
##              DETAILED INSTRUCTIONS AND PARAMETERS                      ##
##------------------------------------------------------------------------##
##                                                                        ##
## Macro used for conversion is IMG2SPRITES, which has up to 9 parameters:##
##  (1): Image file to be converted into C sprite (PNG, JPG, GIF, etc)    ##
##  (2): Graphics mode (0,1,2) for the generated C sprite                 ##
##  (3): Prefix to add to all C-identifiers generated                     ##
##  (4): Width in pixels of each sprite/tile/etc that will be generated   ##
##  (5): Height in pixels of each sprite/tile/etc that will be generated  ##
##  (6): Firmware palette used to convert the image file into C values    ##
##  (7): (mask / tileset / zgtiles)                                       ##
##     - "mask":    generate interlaced mask for all sprites converted    ##
##     - "tileset": generate a tileset array with pointers to all sprites ##
##     - "zgtiles": generate tiles/sprites in Zig-Zag pixel order and     ##
##                  Gray Code row order                                   ##
##  (8): Output subfolder for generated .C/.H files (in project folder)   ##
##  (9): (hwpalette)                                                      ##
##     - "hwpalette": output palette array with hardware colour values    ##
## (10): Aditional options (you can use this to pass aditional modifiers  ##
##       to cpct_img2tileset)                                             ##
##                                                                        ##
## Macro is used in this way (one line for each image to be converted):   ##
##  $(eval $(call IMG2SPRITES,(1),(2),(3),(4),(5),(6),(7),(8),(9), (10))) ##
##                                                                        ##
## Important:                                                             ##
##  * Do NOT separate macro parameters with spaces, blanks or other chars.##
##    ANY character you put into a macro parameter will be passed to the  ##
##    macro. Therefore ...,src/sprites,... will represent "src/sprites"   ##
##    folder, whereas ...,  src/sprites,... means "  src/sprites" folder. ##
##                                                                        ##
##  * You can omit parameters but leaving them empty. Therefore, if you   ##
##  wanted to specify an output folder but do not want your sprites to    ##
##  have mask and/or tileset, you may omit parameter (7) leaving it empty ##
##     $(eval $(call IMG2SPRITES,imgs/1.png,0,g,4,8,$(PAL),,src/))        ##
############################################################################
