section .bss
   resb buffer 16; Variable donde cargare cada linea binaria.
   resb bufferH 16; Variable para cargar los valores hexadecimales.

section .data
   help db 'Programa para volcar el contenido de un archivo en formato hexadecimal y ASCII. Se detallan formato y opciones de invocacion: Sintaxis: $ volcar [ -h ] < archivo_entrada > Los parametros entre corchetes denotan parametros opcionales. Las opciones separadas por < > denotan parámetros obligatorios. -h muestra un mensaje de ayuda (este mensaje). archivo_entrada sera el archivo cuyo contenido será volcado por pantalla segun el siguiente formato. El programa toma el contenido del archivo de entrada y mostrarlo por pantalla organizado de la siguiente forma: [Dirección base] [Contenido hexadecimal] [Contenido ASCII] La salida se organiza en filas de a 16 bytes. La primera columna muestra la dirección base de los siguientes 16 bytes, expresada en hexadecimal. Luego siguen 16 columnas que muestran el valor de los siguientes 16 bytes del archivo a partir de la dirección base, expresados en hexadecimal. La última columna (delimitada por caracteres ‘|’) de cada fila muestra el valor de los mismos 16 bytes, pero expresados en formato ASCII, mostrando sólo los caracteres imprimibles, e indicando la presencia de caracteres no imprimibles con ‘.’). Si no se especifica archivo alguno, la terminación será anormal, mostrando un 3. Para mas informacion, consulte la documentacion del programa.', 10,
   longHelp equ $ - help
   
section .text
   global _start
   
   _start:
       pop eax; Desapilo la cantidad de argumentos.
	   pop ebx; Desapilo el nombre del programa.
	   dec eax
	   cmp eax,2; Si tiene 2 argumentos
	   je then; ejecuto then.
	   cmp eax,1; sino si tiene un argumento
	   je else; ejecuto el else.
	   jmp error; sino termino con error.
       
       error:	   
	     mov eax,1
	     mov ebx,1
	     int 80h
	   
	   then:
	     pop ebx; Desapilo el primer argumento.
		 cmp ebx,'-h'; Si el primer argumento es -h
		 je printHelp; imprimo la ayuda.
		 jmp error;sino termino con error.
		 
	     printHelp:
	       mov eax,4; Imprimo
		   mov ebx,1; por pantalla
		   mov ecx,help; la ayuda
           mov edx,longHelp
           int 80h
           jmp else
       
       else:
		 call open; Abro el archivo.
		 call read; Leo el archivo.
		 call calculateHexadecimal; calculo la expresion hexadecimal.
		 
		 open:
           mov eax,5
           pop ebx; Desapilo el segundo archivo.
           int 80h
           ret
         
         read:
           mov eax,3
           mov ecx,buffer
           mov edx,16
           int 80h
           ret
         
         calculateHexadecimal:
           	mov ecx,buffer[0]; Cargo el primerbyte en ecx.
            			