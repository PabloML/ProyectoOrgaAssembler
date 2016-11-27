;Programa "volcar", Vuelca el contenido de un archivo segun un formato.
;Autor:
;	Esteche Federico - Lencina Pablo.
;compilar:
;	$ yasm -f elf volcar.asm
;enlazar:
;	$ ld -o volcar volcar.o
;ejecutar:
;	$ ./volcar [parametros]
;-----------------------------------------------------------------------

%define hex_offset 8
%define char_offset 58

section .data
  ;El siguiente formato es el que va a tener la linea de salida.
  linea db "000000  hh hh hh hh hh hh hh hh hh hh hh hh hh hh hh hh  |................|"
  long_Linea equ $ - linea ; Tamaño de la linea
  ultima_Linea_Buffer db "000000"			;Buffer para escribir la ultima vez la cantidad de elementos leidos
  long_buffer_ultLinea equ $ - ultima_Linea_Buffer

  char_max dd 0				;cantidad de caracteres leidos del archivo
  contador dd 0 			;contador de lineas
  hex_pos dd hex_offset			;offset a la posicion de la linea para insertar la representacion hexadecim
  pos_caracter_en_linea dd char_offset		;offset a la posicion de la linea donde insertar el char


  salto db 10				;"\n"
  espacio db 0x20			;" "
  barra db 7ch				;"|"
  resto dd 0				;Diferencia entre el contador y la cantidad de lineas

  ;Mensaje de ayuda que se imprimira por pantalla con el argumento -h.
  help db "Programa para volcar el contenido de un archivo en formato hexadecimal y ASCII.", 10,
      db "Se detallan formato y opciones de invocacion: ", 10,
      db "Sintaxis: $ volcar [ -h ] < archivo_entrada >", 10,
      db "Los parametros entre corchetes denotan parametros opcionales. Las opciones separadas por ", 10,
      db " < > denotan parámetros obligatorios.", 10,
      db "-h muestra un mensaje de ayuda (este mensaje).", 10,
      db "archivo_entrada sera el archivo cuyo contenido será volcado por pantalla segun el siguiente formato", 10,
      db "El programa toma el contenido del archivo de entrada y mostrarlo por pantalla",10,
      db "organizado de la siguiente forma:",10,
      db "    [Dirección base] [Contenido hexadecimal] [Contenido ASCII]    ", 10,
	  db "La salida se organiza en filas de a 16 bytes. La primera columna muestra la dirección", 10 ,
	  db "base de los siguientes 16 bytes, expresada en hexadecimal. Luego siguen 16 columnas que", 10,
	  db "muestran el valor de los siguientes 16 bytes del archivo a partir de la dirección base, expresados", 10,
	  db "en hexadecimal. La última columna (delimitada por caracteres ‘|’) de cada fila muestra el", 10,
      db "valor de los mismos 16 bytes, pero expresados en formato ASCII, mostrando sólo los caracteres", 10,
	  db "imprimibles, e indicando la presencia de caracteres no imprimibles con ‘.’).", 10,
      db "Si no se especifica archivo alguno, la terminación será anormal, mostrando un 3", 10,
      db "Para mas informacion, consulte la documentacion del programa.", 10,
  longMensajeAyuda equ $ - help


section .bss

  buffer: resb 1048576		;Buffer para leer de archivo
	
section .text

global _start

imprimir_salto:

; imprimo un salto de linea por pantalla
mov EAX,4; SYS_WRITE
mov EBX, 1 ; STDOUT
mov ECX,salto
mov EDX,1
int 80h
ret

_start:

;Miro la cantidad de parametros

	pop eax	; eax=cantidad de argumentos del programa.
	pop ebx	; ebx=nombre del programa, se descarta. 
	dec eax	; Se descuenta 1 para no tener en cuenta el nombre del programa. 
			; Solo se consideran aquellos parametros dados por el usuario.
	cmp eax, 0				; 0 parametros?
	je 	tNormal			; No se imprime nada, terminación normal.
							 
	; Se pasa a determinar si tiene 1 o mas argumentos.
	cmp eax, 1
	je unArg	
	jg tErrorOtro	; El maximo n de argumentos es 1,si supera esta cantidad, es error.

;-----------------------------------------------------------------------
unArg:
	pop ebx	; Se extrae el argumento ingresado. 
	mov ecx, [ebx]
	cmp cl, '-'
	je .continuar
	push ebx					; Se devuelve el parametro a la pila. 
	jne	open_file    		; Si no hay un '-' solo puede haber un path
								; de archivo.
	.continuar								
	inc ebx			; Se saltea el '-'.
	mov ecx, [ebx]
	cmp cl, 'h'
	je mostrarAyuda
	
	jne tErrorOtro	; Sino es un -x para consola con numeracion hex, ya es error.

;--------------------------------------------------------------------------	
open_file:

;Abro el archivo que tiene el texto a imprimir, la ruta al archivo se encuentra en EBX
	mov EAX,5		;SYS_OPEN
	mov ECX,0		;Sin flags al abrir.
	mov EDX,0 		;RDONLY (abro el archivo en modo lectura)
	int 80h

    add EAX,2
	cmp EAX, 0 	;Si al abrir el archivo se produjo un error, el File Descriptor sera -1 y 
				;por lo que se produce una salida con codigo 2
	je tErrorArchivoEntrada
	sub EAX,2

	push EAX			;Se guarda el File Descriptor para cerrar el archivo al terminar.

	mov EBX,EAX			;Se mueve el FD a EBX
	mov EAX,3 	     	;SYS_READ 
	mov ECX,buffer		;Buffer donde se guarda el archivo.
	mov EDX,1048576		;Tamaño maximo del buffer (1 mb)
	int 80h				; Interrupcion del sistema

	cmp EAX, 0			;Si el archivo de entrada está vacío.
	je  tNormal		;Salgo sin error

	mov [char_max],EAX	;Se guarda la cantidad de caracteres leidos.

;-----------------------------------------------------------------------------------------
leer_linea:

; Busco el caracter que se quiere leer. La idea principal es manejar el 
; buffer como si fuese un arreglo, por lo cual para obtener un caracter en
; la posicion n se le suma "n" a la posicion inicial un contador de caracteres.

	mov EBX,buffer		;Pongo en EbX la direccion inicial del buffer
	add EBX,[contador]	;Le sumo el contador 
	mov CL,[EBX]		;Copio el caracter almacenado en EBX.

	push ECX			;Guardo el caracter

;Luego se escribe el caracter leido en la posicion que le corresponde.

	mov EAX,linea			 ;Se carga en EAX la direccion inicial de la linea.
	add EAX,[pos_caracter_en_linea]		 ;Luego se le suma el Offset.
	call caracter_imprimible ;Esta llamada a funcion retorna un caracter imprimible,
							 ;lo que significa que dado un caracter, si este es imprimible
							 ;lo retorna y si no es imprimible retorna un punto '.'.
							 
	mov [EAX],CL			 ;Se copia el caracter que leido

	pop ECX					 ;Se elimina de la pila el caracter leido.

	mov EAX,linea			 ;Se mueve la posicion inicial de la linea.
	add EAX,[hex_pos]		 ;se le suma el offset.
	call convertir_a_Hexa		 ;Esta funcion retorna la representacion hexadecimal del 
							 ;caracter que recibe como parametro.
	
	mov [EAX],CX			 ;Finalmente se lo escribe (agrega) en la linea.


	inc DWORD [pos_caracter_en_linea]		;Se incrementa la posicion en la linea, donde se va a escribir el proximo caracter.
	add [hex_pos],DWORD 3					;Incremento la posicion donde escribir el hexa en la linea

;Se suma 1 al contador, luego se controla si es EOF, en este caso se deja de leer.
	
	inc DWORD [contador]	
	mov EAX,[contador]		;Aca se lo mueve a EAX con el objetivo de poder comparar luego.
	cmp [char_max],EAX		;Si el contador es igual a la cantidad de caracteres leidos.
	je Eof					;salto a Eof

;Si el contador es 16 o multiplo de 16, se imprime la linea y se vuelve al formato inicial.
	
	mov EAX,[contador]	;Se pone el contador en el registro EAX.
	mov EBX,16			;cantidad de bit por linea.
	mov EDX,0			;Se pone EDX en cero, para comparar el resto de la division.
	idiv EBX			
	cmp EDX,0			;Si el resto es 0 Se imprime la linea por pantalla y se resetea la linea.
	je imprimir_linea

	jmp leer_linea		;Se vuelve a la lectura de un caracter.

;----------------------------------------------------------------------------------
;Reestablezco la linea para seguir leyendo caracteres
imprimir_linea:
	;Se imprime la linea por pantalla  
	mov EAX,4 	; SYS_WRITE
	mov EBX, 1 	; STDOUT
	mov ECX,linea
	mov EDX,long_Linea
	int 80h

;Reseteo las posiciones donde voy a escribir los caracteres   ****************************************************************
mov [pos_caracter_en_linea],DWORD char_offset		;pos_caracter_en_linea=57
mov [hex_pos],DWORD hex_offset						;hex_pos=8


;Escribo en la linea el contador, exceptuando la primera que ya esta en 000000
mov EAX,[contador]				;Cargo el contador para imprimir la cantidad actual en la linea
mov EBX,linea
call caracter_contador				;Llamo a la funcion que me escribe el contador en la linea

call imprimir_salto

jmp leer_linea					;Vuelvo a imprimir una linea    **************************************************************
;---------------------------------------------------------------------------------------------

Eof:

	;Si es el fin del archivo se imprime el contador.
	mov EAX,[contador]		;Pongo el contador en EAX
	mov EDX,0				;Pongo EDX en cero.
	mov EBX,16				;Se pone en EBX la cantidad maxima de bits por linea.
	idiv EBX				
	cmp EDX,0				;Si el resto es cero, se acabaron los caracteres
	je imprimir_contador	;por lo tanto imprimo el contador.

	;Si el resto no es cero, se debe guardar para saber con cuantos caracteres tengo que llenar la ultima
	;linea.
	
	sub EBX,EDX				;16-resto
	mov [resto], EBX		;Se guarda el resto en EBX.

	;Se agrega una barra vertical al final de los caracteres
	mov EAX,linea			;"|"
	add EAX,[pos_caracter_en_linea]
	mov BL,BYTE [barra]
	mov [EAX], BL
	inc BYTE [pos_caracter_en_linea]
;----------------------------------------------------------------------------------------------
; En esta sección se reemplazan todos los caracteres faltantes de la ultima linea por espacios
; en blanco.
reemplazar:
	
	  ;Reemplazo el caracter en la linea por un espacio
	  mov EAX,linea
	  add EAX,[pos_caracter_en_linea]		;Quiero agregarlo en linea+pos_caracter_en_linea que es donde deberia seguir escribiendo
	  mov BL,[espacio]
	  mov [EAX],BL
	  inc BYTE [pos_caracter_en_linea]		;Incremento pos_caracter_en_linea para no sobreescribir lo que acabo de escribir

	  ;Reemplazo los dos hexadecimales por dos espacios
	  mov EAX,linea
	  add EAX,[hex_pos]
	  mov BL,[espacio]
	  mov BH,[espacio]
	  mov [EAX],BX
	  add BYTE [hex_pos],3

	  dec BYTE [resto]
	  cmp [resto], WORD 0
	  je imprimir_faltante


	  jmp reemplazar
;-----------------------------------------------------------------------------------------------

imprimir_faltante:
	;Imprimo la linea que falta
	mov EAX,4 		; SYS_WRITE
	mov EBX, 1 		;STDOUT
	mov ECX,linea
	mov EDX,long_Linea
	int 80h

	call imprimir_salto
;-----------------------------------------------------------------------------------------------
;Imprimo el contador con el valor final de caracteres leidos
imprimir_contador:

	mov EAX,[contador]
	mov EBX,ultima_Linea_Buffer		;Buffer especial que contiene "000000"
	call caracter_contador

	mov EAX, 4		;SYS_WRITE
	mov EBX, 1 		;STDOUT
	mov ECX,ultima_Linea_Buffer
	mov EDX,long_buffer_ultLinea
	int 80h
	call imprimir_salto

	;Cierro el archivo
	pop EBX
	mov EAX, 6 		;SYS_CLOSE
	int 80h
;------------------------------------------------------------------------------------------------
tNormal:
	; Salgo sin error
	mov EAX,1 ; SYS_EXIT
	mov EBX,0
	int 80h
;------------------------------------------------------------------------------------------------
mostrarAyuda:
	;Imprimo el texto de ayuda
	mov EAX, 4  ;SYS_WRITE 
	mov EBX, 1	;STDOUT
	mov ECX,help
	mov EDX,longMensajeAyuda
	int 80h
	call imprimir_salto		;Imprimo un salto de linea
;------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------
; Terminaciones, en ebx se guarda el modo (indicadas en el enunciado).
;tNormal: 
 ;   mov     eax, 1		; sys_exit
  ;  xor     ebx, ebx 	; ebx=0, sin errores. 
   ; int     80h
    
tErrorArchivoEntrada: 
    mov     eax, 1	;sys_exit
    mov     ebx, 1 
    int     80h

tErrorOtro: 
    mov     eax, 1	;sys_exit
    mov     ebx, 3 
    int     80h
;--------------------------------------- Caracter_hexa ----------------------------------	
; Funcion convertir_a_Hexa: Convierte el caracter en CL a hexa ascii. Los caracteres hexa
; se almacenan en CH y CL EN ORDEN INVERTIDO.
; Para que los caracteres se impriman en el orden correcto se debe usar CX.
; PARAMETROS:
;  CL - Caracter
; RETORNO:
;  CL - Primer hexa en ascii. 
;  CH - Segundo hexa en ascii. 

convertir_a_Hexa:

  mov DL,CL		;Hago copia de caracter
  and DL,00001111b	;Obtengo ultimos 4 bits
  
  call convertir	;Convierto 4 bits a hexa ascii (0..9A..F)
  
  mov CH,DL		;Copio segundo hexa en CH. (ORDEN INVERTIDO)
  mov DL,CL		;Hago copia de caracter
  shr DL,4		;Obtengo primeros 4 bits
  
  call convertir	;Convierto 4 bits a hexa ascii (0..9A..F)

  mov CL,DL		;Copio primer hexa en CL. (ORDEN INVERTIDO)
  ret			;Fin
  
;--------------------------------- CARACATER CONTADOR -----------------------------	
; Funcion caracter_contador: convierte un numero (menor a 2^20) en EAX a ascii hexa y lo guarda en 
; los primeros 5 lugares del buffer de EBX
; PARAMETROS:
;   EAX - Numero
;   EBX - Buffer 
; RETORNO:
;   EBX - Con sus primeros 6 lugares representando al numero en hexa ascii

caracter_contador:

  add EBX, 5		;Sumo 4 a buffer, empiezo desde la posicion menos significativa
  mov ECX,16		;ECX=16 divisor

 
bucle_contador:
  
  mov EDX,0		;Preparo EDX=0 para usar idiv
  idiv ECX		;Divido por 16, EDX=resto, EAX=cociente
    
  call convertir	;Convierto 0<resto<16 en ascii hexa
  mov [EBX], DL		;Muevo ascii hexa a buffer
  dec EBX		;Decremento buffer. Muevo una posicion a la izquierda
  
  cmp EAX,0		;Comparo Cociente con 0.
  jne bucle_contador	;Si (Cociente!=0): sigo dividiendo
  
  ret			;Si (Cociente=0): Fin
 
 ;---------------------------------Caracter_imprimible ---------------------------------
  ; Funcion caracter_imprimible: Dado un caracter en CL, si no es imprimible lo convierte a "."
; PARAMETROS:
;   CL - Caracter
; RETORNO:
;   CL - Caracter original si este es imprimible, "." si no era imprimible

caracter_imprimible:

  cmp CL, 31		;Comparo Caracter con 31
  jg imprimible		;Si (Caracter>31): Voy a imprimible
  
no_imprimible:		;Sino (Caracter<=31): Caracter no es imprimble

  mov CL, 46		;Entonces Caracter="."
  jmp fin_car_imprimible;Ir a fin

imprimible:

  cmp CL, 127		;Comparo Caracter con 127 ( 127 en ascii es DEL )
  je no_imprimible	;Si (Caracter=127): Ir a no_imprimible

fin_car_imprimible:

  ret			;Fin

  ;----------------------------------------Convertir -----------------------------------
  
  ; Funcion convertir: Convierte el caracter en DL a hexa en ascii (0..9A..F)
; PARAMETROS:
;   DL - Caracter
; RETORNO:
;   DL - Caracter en hexa ascii (0..9A..F)
 
convertir:

  cmp DL,9		;Comparo Caracter con 9
  jg esletra		;Si Caracter>9: Ir a esletra

esnumero:		;(Caracter<=9)

  add DL,48		;Caracter es numero. Sumo 48 para convertir a ascii numero (0..9)
  jmp fin_convertir	;Ir a fin
  
esletra:		;(Caracter>9)

  add DL,55		;Caracter es letra. Sumo 55 para convertir a ascii letra (A..F)
   
fin_convertir:
  
  ret			;Fin

