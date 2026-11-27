.include 'man/entity.h.s'
.include 'sys/prerender.h.s'
.include 'sys/render.h.s'

.globl cpct_memset_asm
.globl cpct_memcpy_asm


next_free_entity:   ; Direccion de memoria a la siguiente entidad libre.
  .ds 2

e_array:            ; Posicion de memoria donde empieza array de entidades.
  .ds e_array_size
e_array_end:
  .db #0            ; centinela: el bucle forall para en el primer tipo 0

;============================================
;; Return:
;;    ix -> siguiente entidad libre
man_get_next_free_entity::
  ld ix, (#next_free_entity)
  ret

;==================================================================================================
;   Called by:  game.s/man_game_init
;   Desc:
;       Inicializa el array de entidades a 0
;       Inicializa etiqueta next_free_entity = primera posicion array

man_entity_init::

  ld    de, #e_array            ; guarda direccion de memoria a la primera posicion del array de ent.
  xor   a                       ; guarda valor con el que queremos rellenar
  ld    bc, #e_array_size       ; tamaño total del array (tam. ent. * num. ent.)

  call  cpct_memset_asm         ; rellenar el array de entidades con 0

  ld    hl, #e_array            ; guarda direccion a primera pos. array de ent.
  ld    (#next_free_entity), hl ; primera entidad libre = primera entidad del array

  ret

;==================================================================================================
;   Called by:  render/create_template
;   Output: hl = entidad reservada, carry = 1 si el array esta lleno (no se reserva nada)
;   Desc:
;       Reserva la siguiente entidad libre. Si el array esta lleno no reserva nada, asi nunca
;       se pisa el centinela del final.

man_entity_create::
    ld      hl, (#next_free_entity)
    ld      de, #e_array_end
    or      a                   ; carry = 0
    sbc     hl, de              ; hl - e_array_end
    jr      nz, .hay_sitio
    scf                         ; lleno
    ret
  .hay_sitio:
    add     hl, de              ; restaurar hl = next_free_entity
    ld      (hl), #e_type_renderable  ; tipo provisional (create_template copia el template encima)

    ld      de, #e_size
    ex      de, hl
    add     hl, de              ; hl = siguiente libre
    ld      (#next_free_entity), hl
    ex      de, hl              ; hl = entidad reservada
    or      a                   ; carry = 0
    ret

;==================================================================================================
;   Input:
;       hl = funcion que se quiere aplicar a las entidades que cumplan el tipo
;       a  = firma con la mascara/tipo con la que han de cumplir las entidades
;   Desc:
;       Aplica la funcion (con ix = entidad) a todas las entidades que tengan algun bit de la firma.
;       La funcion y la firma se escriben en el propio codigo (CALL nn / AND n): llamar cuesta
;       ~17 us por entidad. Es reentrante: guarda los valores
;       anteriores y los repone al salir, asi que una funcion llamada desde aqui puede volver a
;       usar man_entity_forall_matching (colisiones). ix se conserva entre llamadas.

man_entity_forall_matching::
    ld      de, (#.fa_call + 1)     ;; guardar destino y firma de un forall exterior
    push    de
    ld      e, a
    ld      a, (#.fa_sig + 1)
    ld      d, a
    push    de                      ;; d = firma anterior
    ld      a, e
    ld      (#.fa_sig + 1), a
    ld      (#.fa_call + 1), hl

    ld      ix, #e_array
  .fa_loop:
    ld      a, indx_type(ix)
    or      a                       ;; tipo 0 = fin del array
    jr      z, .fa_end
  .fa_sig:
    and     #0x00
    jr      z, .fa_next
    push    ix
  .fa_call:
    call    0x0000
    pop     ix
  .fa_next:
    ld      de, #e_size
    add     ix, de
    jr      .fa_loop

  .fa_end:
    pop     de                      ;; reponer firma y destino anteriores
    ld      a, d
    ld      (#.fa_sig + 1), a
    pop     de
    ld      (#.fa_call + 1), de
    ret

;==================================================================================================
;   Called by:  physics, colisions
;   Input:  ix -> entidad en cuestion
;   Desc:   Marca la entidad como muerta (se elimina en man_entity_update)

man_entity_set4Destruction::

    ld      a, indx_type(ix)
    or      #e_type_dead
    ld      indx_type(ix), a

    ret

;==================================================================================================
;   Called by:  game/logic_step
;   Desc:
;       Elimina las entidades muertas cuyo dibujo ya se ha borrado de los DOS buffers de video
;       (here_y = there_y = NOT_DRAWN), asi no quedan restos en pantalla.
;       Al eliminar, la ultima entidad se copia en el hueco, asi que NO se avanza: hay que
;       revisar otra vez la misma posicion.

man_entity_update::
    ld      ix, #e_array
  .eu_loop:
    ld      a, indx_type(ix)
    or      a
    ret     z
    and     #e_type_dead
    jr      z, .eu_next
    ld      a, indx_here_y(ix)
    and     indx_there_y(ix)
    inc     a                               ;; 0xFF & 0xFF + 1 = 0 -> borrada de los dos buffers
    jr      nz, .eu_next
    call    man_entity_destroy
    jr      .eu_loop
  .eu_next:
    ld      de, #e_size
    add     ix, de
    jr      .eu_loop

;==================================================================================================
;   Input:  ix = entidad a eliminar
;   Desc:   Copia la ultima entidad en ix y borra la ultima

man_entity_destroy::
    ld      hl, (#next_free_entity)         ;; Guardo la siguiente pos de memoria
    ld      bc, #-e_size                    ;; Guardo tamaño de una entidad
    add     hl, bc                          ;; Resta a next free entity el tamaño de una entidad
    ld      (#next_free_entity), hl         ;; hl = ultima entidad

    push    ix
    pop     de                              ;; Donde quiero copiar
    ld      bc, #e_size                     ;; Numero de bytes a copiar
    call    cpct_memcpy_asm                 ;; Copiamos los bytes

    ld      de, (#next_free_entity)         ;; El que acabamos de mover
    xor     a                               ;; Valor a escribir
    ld      bc, #e_size                     ;; Numero de bytes
    call    cpct_memset_asm                 ;; Colocamos ceros en la posicon que acabamos de mover.

    ret
