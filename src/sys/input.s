.include "man/entity.h.s"
.include "sys/input.h.s"
.include "keyboard/keyboard.h.s"

;; Direccion que pide el jugador en este momento (KEY_NONE / KEY_UP / KEY_DOWN).
;; La lee sys_physics_update_on_input cuando el minero esta quieto en un carril.
keyIdentifier::  .db KEY_NONE

;==================================================================================================
;   Called by:  game/man_game_init
;   Desc:       Olvida cualquier tecla pendiente al empezar un nivel

sys_input_init::
    xor     a
    ld      (#keyIdentifier), a
    ret

;==================================================================================================
;   Called by:  game/man_game_play->gameloop
;   Desc:
;       O / joystick arriba = subir, P / joystick abajo = bajar.
;       (El teclado se escanea en la interrupcion, aqui solo se consulta el buffer.)

sys_typeInput::
    ld      hl, #Key_O
    call    cpct_isKeyPressed_asm
    jr      nz, .up

    ld      hl, #Joy0_Up
    call    cpct_isKeyPressed_asm
    jr      nz, .up

    ld      hl, #Key_P
    call    cpct_isKeyPressed_asm
    jr      nz, .down

    ld      hl, #Joy0_Down
    call    cpct_isKeyPressed_asm
    jr      nz, .down

    xor     a                       ; nada pulsado: un toque mueve un carril, mantener sigue
    ld      (#keyIdentifier), a     ; moviendo (no se acumulan pulsaciones durante el cambio)
    ret

  .up:
    ld      a, #KEY_UP
    ld      (#keyIdentifier), a
    ret

  .down:
    ld      a, #KEY_DOWN
    ld      (#keyIdentifier), a
    ret
