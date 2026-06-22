# Guía de Comprobación y Despliegue - Práctica 12

Este documento contiene las instrucciones detalladas y comandos paso a paso para desplegar, verificar y probar el servidor de correo (`docker-mailserver`) y el cliente webmail (`Roundcube`) en tu **Ubuntu Server**.

---

## 1. Verificación de Requisitos Previos

Antes de levantar el entorno, asegúrate de que los puertos necesarios no estén siendo ocupados por otros servicios en el host (como un servicio postfix local o Apache/Nginx en el puerto 8081).

Ejecuta el siguiente comando para comprobar que los puertos **25, 143, 587, 993 y 8081** están libres:
```bash
sudo ss -tuln | grep -E ':(25|143|587|993|8081)\s'
```
*Si este comando no devuelve nada, significa que todos los puertos están libres y listos para ser usados por Docker.*

---

## 2. Despliegue del Entorno

1. **Accede al directorio de la práctica:**
   ```bash
   cd /ruta/a/tu/practica12
   ```

2. **Levanta los contenedores en segundo plano:**
   ```bash
   docker compose up -d
   ```

3. **Verifica que los contenedores estén corriendo correctamente:**
   ```bash
   docker compose ps
   ```
   Deberías ver los tres contenedores con estado `Up` o `healthy`:
   * `mailserver`
   * `roundcube-db` (deberá indicar `healthy` tras unos segundos)
   * `roundcubemail`

---

## 3. Comprobación de Configuración y Cuentas de Correo

La práctica ya viene pre-configurada con cuentas de correo en el archivo `postfix-accounts.cf`. Puedes verificar que el servidor las reconoce correctamente con el siguiente comando:

```bash
docker exec -it mailserver setup email list
```

Deberías ver listadas las siguientes cuentas de prueba:
* `director@reprobados.com`
* `admin@reprobados.com`
* `kami@reprobados.com`
* `goku@reprobados.com`
* `vegeta@reprobados.com`

*Nota: La contraseña para estas cuentas preconfiguradas es la que se definió al crearlas (p. ej., `Sistemas.2026!`).*

### Crear una nueva cuenta (Opcional)
Si deseas crear una cuenta adicional para pruebas, utiliza:
```bash
docker exec -it mailserver setup email add usuario@reprobados.com "TuContrasenaSegura"
```

---

## 4. Pruebas de Conectividad (Verificación de Puertos de Red)

Puedes verificar desde el propio servidor o desde otra máquina en la misma red si los puertos del servidor de correo responden:

* **Probar SMTP (Puerto 25):**
  ```bash
  nc -zv localhost 25
  # O con telnet:
  telnet localhost 25
  ```
  *(Escribe `QUIT` para salir de la sesión SMTP de telnet)*

* **Probar IMAP (Puerto 143):**
  ```bash
  nc -zv localhost 143
  # O con telnet:
  telnet localhost 143
  ```
  *(Escribe `. LOGOUT` para salir)*

* **Probar SMTP Seguro / Submission (Puerto 587):**
  ```bash
  nc -zv localhost 587
  ```

---

## 5. Pruebas de Envío y Recepción

### Método A: A través del Webmail (Roundcube)
1. Abre tu navegador web e ingresa a:
   ```text
   http://<IP_DE_TU_UBUNTU_SERVER>:8081
   ```
2. Inicia sesión con cualquiera de las cuentas existentes:
   * **Usuario:** `goku@reprobados.com`
   * **Contraseña:** *(la contraseña establecida en la práctica, p. ej. `Sistemas.2026!`)*
3. Redacta un correo nuevo y envíalo a otra cuenta local (p. ej., `vegeta@reprobados.com`).
4. Cierra sesión e ingresa como `vegeta@reprobados.com` para comprobar que el correo llegó a su bandeja de entrada.

### Método B: Envío rápido de prueba desde la Terminal (Local)
Puedes forzar el envío de un correo de prueba interno directamente usando `sendmail` dentro del contenedor `mailserver`:

```bash
docker exec -it mailserver bash -c 'echo "Subject: Prueba de Correo desde Terminal" | sendmail -v vegeta@reprobados.com'
```

Luego puedes comprobar si el correo fue recibido inspeccionando los logs de correo en tiempo real:
```bash
docker compose logs -f mailserver
```
O leyendo el archivo de logs directamente desde el host:
```bash
tail -n 50 ./datos_compartidos/logs/mail.log
```

---

## 6. Comprobación del Estado de DKIM y Seguridad (Opcional)

Para verificar si las firmas DKIM están cargadas e integradas correctamente en el servidor Postfix/OpenDKIM:

```bash
docker exec -it mailserver opendkim-testkey -d reprobados.com -s mail -vvv
```
*Nota: Si aún no has configurado los registros DNS externos en un servidor DNS real, es normal que retorne "key not secure" o "query failed", pero sirve para verificar que la clave privada local coincide con la configuración.*

---

## 7. Comandos de Mantenimiento y Parada

* **Ver logs en tiempo real de todos los servicios:**
  ```bash
  docker compose logs -f
  ```
* **Detener los servicios manteniendo los datos:**
  ```bash
  docker compose down
  ```
* **Detener los servicios eliminando los volúmenes (Limpieza absoluta):**
  ```bash
  docker compose down -v
  ```
