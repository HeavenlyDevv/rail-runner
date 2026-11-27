.include "sys/screen.h.s"
start_mem:
  .dw #0x8000



;;============================================
;; Updates one entity render component
;; input :
;;   b -> position y
;;   c -> position x
;;   hl -> direccion del sprite
;;   d -> sprite height
;;   e -> sprite width
;; modifies: 
;; AF, BC , DE, HL
sys_draw_sprite::

  push hl ;; guardamos la direccion del sprite
  push de ;; guardamos width y height

  ld de, (start_mem)

  call cpct_getScreenPtr_asm ;; direccion de memoria donde corresponde "x" e "y" y se guarda en hl

  ex de, hl ;; volcamos la direccion a de, para que lo use cpct_drawSprite_asm

  pop bc ;; recuperamos width y height
  pop hl ;; recuperamos la direccion del sprite
  
  
  call cpct_drawSprite_asm
  ret

;==================================================================================================
;   Called by:  game/man_game_play
;   Input:  hl = direccion de memoria [80 / C0]   
;   Output:   
;   Desc:
;       Limpia la pantalla desde la direccion 0x8000 hasta 0xBFFF o 0xC000 hasta 0xFFFF
;       Copia lo que hay en hl en de, incrementa ambos y decrementa bc, hasta que bc sea 0
reset_buffer::
    ld      d, h
    ld      e, l
    inc     de
    ; Pone 0x00 en la dirección especificada en HL
    ld      (hl), #0x00

    ; BC = bytes que quedan por copiar: 0x4000 - 1 (el primero ya esta puesto).
    ; Con 0x4000 se escribia un byte de mas: al limpiar 0xC000 se pisaba la direccion 0x0000.
    ld      bc, #0x3FFF
    ldir
    ret

;==================================================================================================
;   Called by:  stats/sys_stats_init
;   Input:  
;   Output:   
;   Desc:
;      Muestra el buffer recien dibujado y pasa a dibujar en el otro
; ============================================
; 0xC0 |    0xC000    |  cpct_pageC0    |  0x30
; 0x80 |    0x8000    |  cpct_page80    |  0x20
;
switch_buf::
	ld          hl, #start_mem+1
  ld l, (hl)
  srl         l
  srl         l ; desplazamos a la derecha dos veces: 0xC0 -> 0x30, 0x80 -> 0x20
  
  call   cpct_setVideoMemoryPage_asm

	ld          hl, #start_mem+1 ; buscamos el 80 y C0, no 00
	ld          a, #0x40
	xor         (hl) ; invierte de 0x80 a 0xC0 y viceversa
	ld          (start_mem+1), a

ret

;==================================================================================================
;   Desc:   Cambia el buffer en el que se dibuja SIN cambiar el que se ve (para dibujar lo mismo
;           en los dos buffers al empezar un nivel)
switch_buf_silent::
    ld      a, (#start_mem + 1)
    xor     #0x40
    ld      (#start_mem + 1), a
    ret
