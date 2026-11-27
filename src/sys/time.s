.include "sys/time.h.s"
; 30 halts = 0,1 s
; 300 halts = 1 s

;========================================
; Espera 'c' * 'b' ciclos de reloj
; Entradas:
;   b: veces a repetir
;   c: halts a realizar por bucle
;========================================
wait_halts::
   
   loop:
    ld a, c
   
    loop_halt:
   	  halt
      dec a
      jr nz, loop_halt

    dec b 
    jr nz, loop
  ret