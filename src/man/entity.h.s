.include "man/macros.h.s"

.globl e_array

;==== ENTIDAD =====================================================================================
;; Los offsets se calculan con las macros de macros.h.s: se puede añadir o mover un campo sin
;; renumerar nada a mano. Cada campo queda como indx_<nombre>.

BeginStruct indx
SField indx, type,       1      ; bits e_type_*
SField indx, x,          1      ; x en bytes (2 pixeles en modo 0)
SField indx, y,          1      ; y en lineas
SField indx, vx,         1      ; velocidad hacia la izquierda en 1/256 de byte por frame
SField indx, vy,         1      ; velocidad vertical maxima (lineas por frame, minero)
SField indx, sprite_w,   1      ; ancho en bytes
SField indx, sprite_h,   1      ; alto en lineas
SField indx, xfrac,      1      ; parte fraccionaria de x (1/256 de byte)
SField indx, sprite,     2      ; frame actual (enmascarado: pares mascara/color)
SField indx, frames,     2      ; tabla de frames de la animacion
SField indx, frame_,     1      ; indice (4 bits altos) | num. frames (4 bits bajos)
SField indx, anim_frec,  1      ; frames entre cambios de animacion - 1
SField indx, anim_counter, 1
SField indx, flags,      1      ; is_masked | tipo de vagon
;; Lo que hay dibujado en cada buffer de video (render por cambios: solo se redibuja lo que cambia)
SField indx, here_x,     1      ; en el buffer oculto (el que se va a dibujar este frame)
SField indx, here_y,     1      ;   here_y = NOT_DRAWN si no hay nada dibujado
SField indx, here_spr,   2
SField indx, there_x,    1      ; en el buffer visible (se intercambian cada frame)
SField indx, there_y,    1
SField indx, there_spr,  2
SField indx, rflags,     1      ; bits de trabajo del render (RF_*)
EndStruct indx

e_size          = sizeof_indx           ; 25 bytes
num_entities    = 14                    ; minero + vagones + lamparas
e_array_size    = e_size*num_entities

frame_index     = 0xf0                  ; indx_frame_: indice del frame actual
frame_num       = 0x0f                  ; indx_frame_: numero de frames

NOT_DRAWN       = 0xFF                  ; here_y / there_y: nada dibujado en ese buffer

;; rflags
RF_DIRTY        = 0x01                  ; hay que dibujarla este frame
RF_RESTORED     = 0x02                  ; se ha borrado (restaurado el fondo) este frame

;==== MINERO PROPERTIES ====

MINERO_SPRITE_WIDTH     = 7                                         ;(BYTES)
MINERO_SPRITE_HEIGHT    = 24                                        ;(BYTES)
MINERO_SPRITE_BYTES     = MINERO_SPRITE_WIDTH*MINERO_SPRITE_HEIGHT  ;(BYTES)

;==== TREN PROPERTIES ====

TREN_SPRITE_WIDTH       = 11                                        ;(BYTES)
TREN_SPRITE_HEIGHT      = 16                                        ;(BYTES)
TREN_SPRITE_BYTES       = TREN_SPRITE_WIDTH*TREN_SPRITE_HEIGHT      ;(BYTES)

;==== FLAGS ====

is_masked               = 0x01  ; 0b 0000 0001. Indica si tiene mascara o no
is_bgdraw               = 0x80  ; 0b 1000 0000. Se dibuja leyendo el fondo de los railes (vagones)

;==== TRAINS ====
train_gemas     =   0x02  ;   0b 0000 0010
train_oro       =   0x04  ;   0b 0000 0100
train_diamante  =   0x08  ;   0b 0000 1000
train_tnt       =   0x10  ;   0b 0001 0000

;==== ENTITY TYPES ====

e_type_invalid      = 0x00  ; 0b 0000 0000
e_type_renderable   = 0x01  ; 0b 0000 0001
e_type_movable      = 0x02  ; 0b 0000 0010
e_type_input        = 0x04  ; 0b 0000 0100
e_type_colider      = 0x08  ; 0b 0000 1000
e_type_colisionable = 0x10  ; 0b 0001 0000
e_type_animated     = 0x20  ; 0b 0010 0000
e_type_dead         = 0x40  ; 0b 0100 0000

;==== POSICION CARRILES ====

offset          = 13
train_offset    = 7

row_1 = 40 - offset         ;; 27
row_2 = 80 - offset         ;; 67
row_3 = 120 - offset        ;; 107

RAIL_Y_1        = row_1 + 13    ;; 40: primera linea de cada banda de railes
RAIL_Y_2        = row_2 + 13    ;; 80
RAIL_Y_3        = row_3 + 13    ;; 120
RAIL_H          = 11            ;; lineas de cada banda

;==== FUNCTIONS ====

.globl man_entity_init
.globl man_entity_create
.globl man_entity_forall_matching
.globl man_entity_update
.globl man_get_next_free_entity
.globl man_entity_set4Destruction
.globl man_entity_destroy
