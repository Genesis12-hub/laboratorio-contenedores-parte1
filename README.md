# Laboratorio práctico de contenedores locales (Parte 1)

Repositorio de [Genesis12-hub](https://github.com/Genesis12-hub).

Comprobación del 7 de noviembre de 2026 en una máquina Linux remota (Ubuntu 24.04, kernel 6.12.113+). En esa máquina se instaló Docker Engine, se descargó `redis:7-alpine` y el contenedor aislado `parte1-redis` respondió `PONG`.

El video de la clase es otra sesión: Windows, PowerShell y WSL2, con Docker 27.3.1. El docente deja escrito `docker pull redis:7-alpine` y la grabación termina en la búsqueda de redis/alpine en Docker Hub. El `PING` de este repositorio es una validación complementaria de esta máquina Linux, con Docker Engine 29.9.3, hecha después de descargar la imagen y arrancar Redis.

## Resultado

| Dato | Valor observado |
| --- | --- |
| Docker Engine | 29.9.3, cliente y servidor, `linux/amd64` |
| Imagen | `redis:7-alpine` |
| Digest | `sha256:c5d34a98396a4775e223c74e929162c35c5a2182901ba26b50ade939941ce14b` |
| Tamaño de la imagen | 57297625 bytes |
| Contenedor | `parte1-redis` (`944927cf649ddce6dc9c8df6701ec28cc7da62f008381ab6b567dfcd074177af`) |
| Publicación | `127.0.0.1:6379` hacia el puerto 6379 del contenedor |
| `redis-cli PING` | `PONG` |
| `redis_version` | 7.4.12 |

La salida copiada está en [`docs/validacion-linux.txt`](docs/validacion-linux.txt).

La máquina llegó sin Docker Engine. La instalación usó el repositorio apt oficial. El daemon se arrancó con `sudo dockerd` porque el proceso 1 es distinto de systemd y `policy-rc.d` rechazó el arranque del servicio. El socket quedó `srw-rw----`, limitado al grupo `docker`. La política de reinicio del contenedor es `no`: sigue en marcha mientras ese daemon siga activo.

```bash
sudo docker version
sudo docker pull redis:7-alpine
sudo docker run -d --name parte1-redis --restart no -p 127.0.0.1:6379:6379 redis:7-alpine
sudo docker exec parte1-redis redis-cli PING
```

`/proc/net/tcp` mostró una sola escucha en `127.0.0.1:6379`. Una conexión al puerto 6379 por otra dirección de la misma máquina recibió `Connection refused`.

## Video de la clase

La clase abre la carpeta con PowerShell:

```powershell
cd d:
mkdir ClaseIntegracionContenedoresB
cd .\ClaseIntegracionContenedoresB\
code .
```

`cd d:` cambia a la unidad D: y conserva el directorio que PowerShell recuerda en esa unidad. `Set-Location D:\` fija la raíz. Esos comandos pertenecen a la sesión grabada.

En el video también se consultan `wsl --status` y `wsl -l -v`, con Ubuntu en WSL2. El docente escribe la descarga de `redis:7-alpine` y la grabación sigue en Docker Hub. El video consulta la imagen; este repositorio añade la comprobación del contenedor en ejecución y la respuesta `PONG`.

## Referencias

- Instalación de Docker Engine en Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Imagen oficial Redis: https://hub.docker.com/_/redis
