# 1. Usar una imagen base súper ligera (Alpine Linux)
FROM alpine:latest

# 2. Instalar Apache
RUN apk update && apk add --no-cache apache2

# 3. SEGURIDAD: Ocultar las firmas del servidor (Server Tokens)
# Esto cambia la configuración para que los atacantes no vean la versión exacta
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/httpd.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/httpd.conf

# 4. SEGURIDAD: Cambiar el puerto al 8080
# Los puertos menores a 1024 (como el 80) requieren permisos de "root". 
# Usar el 8080 nos permite correr el servidor de forma segura.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf

# 5. SEGURIDAD: Crear un usuario que NO sea root
RUN addgroup -S webgroup && adduser -S webuser -G webgroup

# 6. Darle permisos al nuevo usuario sobre las carpetas que necesita Apache
RUN chown -R webuser:webgroup /var/www/localhost/htdocs/ \
    && chown -R webuser:webgroup /var/log/apache2/ \
    && chown -R webuser:webgroup /run/apache2/

# 7. Copiar tu página web personalizada al contenedor
# (Ahorita crearemos este archivo index.html)
COPY index.html /var/www/localhost/htdocs/

# 8. Cambiar a nuestro usuario seguro antes de arrancar
USER webuser

# 9. Exponer el puerto
EXPOSE 8080

# 10. Arrancar Apache
CMD ["httpd", "-D", "FOREGROUND"]1~kdkk# 1. Usar una imagen base súper ligera (Alpine Linux)
FROM alpine:latest

# 2. Instalar Apache
RUN apk update && apk add --no-cache apache2

# 3. SEGURIDAD: Ocultar las firmas del servidor (Server Tokens)
# Esto cambia la configuración para que los atacantes no vean la versión exacta
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/httpd.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/httpd.conf

# 4. SEGURIDAD: Cambiar el puerto al 8080
# Los puertos menores a 1024 (como el 80) requieren permisos de "root". 
# Usar el 8080 nos permite correr el servidor de forma segura.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf

# 5. SEGURIDAD: Crear un usuario que NO sea root
RUN addgroup -S webgroup && adduser -S webuser -G webgroup

# 6. Darle permisos al nuevo usuario sobre las carpetas que necesita Apache
RUN chown -R webuser:webgroup /var/www/localhost/htdocs/ \
    && chown -R webuser:webgroup /var/log/apache2/ \
    && chown -R webuser:webgroup /run/apache2/

# 7. Copiar tu página web personalizada al contenedor
# (Ahorita crearemos este archivo index.html)
COPY index.html /var/www/localhost/htdocs/

# 8. Cambiar a nuestro usuario seguro antes de arrancar
USER webuser

# 9. Exponer el puerto
EXPOSE 8080

# 10. Arrancar Apache
CMD ["httpd", "-D", "FOREGROUND"]1~# 1. Usar una imagen base súper ligera (Alpine Linux)
FROM alpine:latest

# 2. Instalar Apache
RUN apk update && apk add --no-cache apache2

# 3. SEGURIDAD: Ocultar las firmas del servidor (Server Tokens)
# Esto cambia la configuración para que los atacantes no vean la versión exacta
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/httpd.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/httpd.conf

# 4. SEGURIDAD: Cambiar el puerto al 8080
# Los puertos menores a 1024 (como el 80) requieren permisos de "root". 
# Usar el 8080 nos permite correr el servidor de forma segura.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf

# 5. SEGURIDAD: Crear un usuario que NO sea root
RUN addgroup -S webgroup && adduser -S webuser -G webgroup

# 6. Darle permisos al nuevo usuario sobre las carpetas que necesita Apache
RUN chown -R webuser:webgroup /var/www/localhost/htdocs/ \
    && chown -R webuser:webgroup /var/log/apache2/ \
    && chown -R webuser:webgroup /run/apache2/

# 7. Copiar tu página web personalizada al contenedor
# (Ahorita crearemos este archivo index.html)
COPY index.html /var/www/localhost/htdocs/

# 8. Cambiar a nuestro usuario seguro antes de arrancar
USER webuser

# 9. Exponer el puerto
EXPOSE 8080

# 10. Arrancar Apache
CMD ["httpd", "-D", "FOREGROUND"]1~# 1. Usar una imagen base súper ligera (Alpine Linux)
FROM alpine:latest

# 2. Instalar Apache
RUN apk update && apk add --no-cache apache2

# 3. SEGURIDAD: Ocultar las firmas del servidor (Server Tokens)
# Esto cambia la configuración para que los atacantes no vean la versión exacta
RUN sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/httpd.conf
RUN sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/httpd.conf

# 4. SEGURIDAD: Cambiar el puerto al 8080
# Los puertos menores a 1024 (como el 80) requieren permisos de "root". 
# Usar el 8080 nos permite correr el servidor de forma segura.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/httpd.conf

# 5. SEGURIDAD: Crear un usuario que NO sea root
RUN addgroup -S webgroup && adduser -S webuser -G webgroup

# 6. Darle permisos al nuevo usuario sobre las carpetas que necesita Apache
RUN chown -R webuser:webgroup /var/www/localhost/htdocs/ \
    && chown -R webuser:webgroup /var/log/apache2/ \
    && chown -R webuser:webgroup /run/apache2/

# 7. Copiar tu página web personalizada al contenedor
# (Ahorita crearemos este archivo index.html)
COPY index.html /var/www/localhost/htdocs/

# 8. Cambiar a nuestro usuario seguro antes de arrancar
USER webuser

# 9. Exponer el puerto
EXPOSE 8080

# 10. Arrancar Apache
CMD ["httpd", "-D", "FOREGROUND"]
