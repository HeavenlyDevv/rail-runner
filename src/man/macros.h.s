;;;;;;; MACROS
;; 
;; .mdelete <name>
;;    Delete a macro in case it already exists
;; .macro <name> <args>
;;    Define a macro
;; .endm
;;    End a macro
;; '
;;    Concatenate two tokens

.mdelete BeginStruct
.macro BeginStruct structname
  structname'_offset = 0
.endm

;; Con esta macro, podemos asegurarnos de manejar los offsets de los campos de una estructura y no tener que hacerlo a mano, 
;; de manera que si añadimos un campo nuevo, no tenemos que preocuparnos de actualizar los offsets de los campos anteriores.
.mdelete SField
.macro SField structname, fieldname, sizeoffield
  structname'_'fieldname = structname'_offset
  structname'_offset = structname'_offset + sizeoffield
.endm

.mdelete EndStruct
.macro EndStruct structname
  sizeof_'structname = structname'_offset ;; asignamos el tamaño de la estructura ocupado en memoria
.endm

;;;;; ########## 8-bit bitfields ##########

.mdelete BeginBitField8
.macro BeginBitField8 bitfield
  bitfield'_numbit = 7
.endm

.mdelete Bit8
.macro Bit8 bitfield, bitname
  bitfield'_'bitname'_bit = bitfield'_numbit
  bitfield'_'bitname'_mask = (1 << bitfield'_numbit) ;; 1 shifted left by numbit
  bitfield'_numbit = bitfield'_numbit - 1 ;; decrement numbit
.endm


.mdelete EndBitField8
.macro EndBitField8 bitfield
  ;; check for numbit < -1
  .if (bitfield'_numbit+1) & 0x80000000
    .error "Bitfield has more than 8 bits"
  .else
    ;; ok
  .endif
.endm
