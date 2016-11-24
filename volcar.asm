section .bss
   resb buffer 1048576; Variable donde cargare cada linea binaria.
   resb lineHex 32; Variable donde cargare cada linea en hexadecimal.

section .data
   help db 'Programa para volcar el contenido de un archivo en formato hexadecimal y ASCII. Se detallan formato y opciones de invocacion: Sintaxis: $ volcar [ -h ] < archivo_entrada > Los parametros entre corchetes denotan parametros opcionales. Las opciones separadas por < > denotan parámetros obligatorios. -h muestra un mensaje de ayuda (este mensaje). archivo_entrada sera el archivo cuyo contenido será volcado por pantalla segun el siguiente formato. El programa toma el contenido del archivo de entrada y mostrarlo por pantalla organizado de la siguiente forma: [Dirección base] [Contenido hexadecimal] [Contenido ASCII] La salida se organiza en filas de a 16 bytes. La primera columna muestra la dirección base de los siguientes 16 bytes, expresada en hexadecimal. Luego siguen 16 columnas que muestran el valor de los siguientes 16 bytes del archivo a partir de la dirección base, expresados en hexadecimal. La última columna (delimitada por caracteres ‘|’) de cada fila muestra el valor de los mismos 16 bytes, pero expresados en formato ASCII, mostrando sólo los caracteres imprimibles, e indicando la presencia de caracteres no imprimibles con ‘.’). Si no se especifica archivo alguno, la terminación será anormal, mostrando un 3. Para mas informacion, consulte la documentacion del programa.', 10,
   longHelp equ $ - help
   hex db 123456789ABCDEF
   cont db 0
   
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
		 mov ecx, [ebx]
	     cmp cl, '-' ; Si el primer argumento tiene un -
		 jne error
		 inc ebx ; Se saltea el '-'.
	     mov ecx, [ebx]
	     cmp cl, 'h'
		 je printHelp; imprimo la ayuda.
		 jmp error
		 
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
		 jmp volcar
		 
	     volcar:
		   mov eax,[bufffer]
		   cmp eax,04
		   je closeAndExit
		   call calculateHexadecimal; calculo la expresion hexadecimal.
		   jmp volcar
		   
		 open:
           mov eax,5
           pop ebx; Desapilo el segundo archivo.
		   mov ecx,O_RDONLY
           int 80h
		   mov ecx,eax; Guardo el indicador del archivo para luego leerlo y escribirlo.
           ret
         
         read:
           mov eax,3
		   mov ebx,[ecx]
           mov ecx,buffer
           mov edx,1048576
           int 80h
           ret
         
         calculateHexadecimal:
           	mov bl,buffer; Cargo el primerbyte en ecx.
			mov dl,[bl]
			and dl,0Fh
			add hex,dl
            mov dl,[hex]			
			mov dh,[bl]
			sar dh,4
			mov lineHex,dh; decena del primer byte leido.
			inc lineHex
			mov lineHex,dl; Unidad del primer byte leido.
			inc buffer
			inc lineHex
		 	ret
		 
         closeAndExit:
           	mov eax,6
            mov ebx,[ecx]
            int 80h
            jmp exit
        
         exit:
           mov eax,1
           mov ebx,0
           int 80h		   
			
            			