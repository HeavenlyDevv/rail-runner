.include "cpctelera.h.s"
.include "man/interruptions.h.s"

;; Frames que han pasado desde que el bucle de juego lo leyo por ultima vez.
;; Con esto la logica avanza a 50 pasos por segundo aunque un frame tarde mas en dibujarse:
;; si el render se pasa de un frame, el bucle ejecuta 2 pasos de logica y el juego no se ralentiza.
frame_count:: .db 0

int_phase:    .db 1         ; interrupciones que faltan para el siguiente frame

; =============================
; La interrupcion salta 6 veces por frame (300 Hz) y el Gate Array la sincroniza con el VSYNC.
; Se cuenta un frame cada 6 interrupciones. Si una interrupcion ve el VSYNC activo (bit 0 del
; puerto B del PPI) es la primera del frame y se reajusta la fase.
; Ojo: NO basta con contar solo cuando se ve el VSYNC. El dibujo con la pila (draw_masked,
; railes) desactiva las interrupciones hasta ~2.6 ms; si la del VSYNC llega en ese rato se
; atiende cuando el pulso de VSYNC ya ha terminado y ese frame no se contaria. Como cada
; tramo sin interrupciones dura menos de 52 lineas (3.3 ms), ninguna interrupcion se pierde
; y la cuenta de 6 en 6 no falla.
; Los registros los guarda el wrapper de cpct_setInterruptHandler, que tambien hace ei + reti.
; =============================
man_interruption::
  ld    hl, #int_phase
  ld    b, #0xF5            ; PPI puerto B
  in    a, (c)
  rra                       ; carry = VSYNC activo
  jr    nc, .count
  ld    (hl), #1            ; primera interrupcion del frame: contar ahora
.count:
  dec   (hl)
  ret   nz
  ld    (hl), #6

  ld    hl, #frame_count
  inc   (hl)
  jp    cpct_scanKeyboard_if_asm  ; su RET vuelve al wrapper
