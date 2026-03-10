**PASOS DE INSTLACION Y PUSHEAR MIS SCRIPTS** 



**LINUX | Configuración Inicial**

Esta guía es para cuando instalas todo desde cero o reinicias una máquina.



En Debian (Terminal Negra - Usuario Root)

Como ya eres root, no uses sudo.



1. *Activar el carpetas compartidas en la configuración inicial de la vm* 
   Seleccionar una nueva carpeta y abrir la carpeta de mi host 
   Asignar nombre "repo\_linux" y seleccionar automontar
   
2. *Instalar Git:*
apt update \&\& apt install git -y
   
3. *Preparar la carpeta compartida:*
mkdir /mnt/practicas
   
4. *Conectar con tu Laptop:*

&nbsp;   mount -t vboxsf repo\_linux /mnt/practicas



5\. *Entra desde el host a powershell y entra a la carpeta de los archivos "ADMINISTRACION DE SISTEMAS"*



6\. *Ejecuta los siguientes comandos:* 

&nbsp;	git add .

&nbsp;	git commit -m "Comentario"

&nbsp;	git push -f origin main





***Nota:***<i> Para mover un archivo que no esta dentro de la carpeta compartida ejecutar: mv /root/nombre\_de\_tu\_script.sh /mnt/practicas/</i>



<i>Como entrar a mis scripts desde Debian </i>



<i>	cd /mnt/practicas</i>

<i>	chmod +x \*.sh (por si a caso no se puede ejecutar)</i>

<i>	./nom\_script.sh</i>



<i>Hacer un nuevo script </i>

	

<i>	nano /mnt/practicas/nuevo\_script.sh</i>

