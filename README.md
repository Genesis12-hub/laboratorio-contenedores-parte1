# Laboratorio práctico de contenedores locales (Parte 1)

Repositorio de [Genesis12-hub](https://github.com/Genesis12-hub).

Esta parte prepara la infraestructura local: Redis 7 como caché y PostgreSQL 16 como base, con Docker Compose y con el ejercicio manual de persistencia. La parte 2, con .NET 10 y Aspire, corresponde a otro repositorio.

## Alcance

La publicación inicial (`a920bbab57707f9b9ebae5153a84f249f4f92363`) solo traía este README, `.gitignore` y [`docs/validacion-linux.txt`](docs/validacion-linux.txt). Esa comprobación del 7 de noviembre de 2026, en Linux, mostró un `PONG` de `redis:7-alpine` y describió el tramo inicial del video de clase: PowerShell, WSL2 y Docker 27.3.1. No implementaba el ejercicio completo. Esa salida se conserva como evidencia parcial.

El 8 de noviembre de 2026 se ejecutó aquí el ejercicio completo. El `uname` de la máquina dice `Linux cursor`; es el nombre del host, no un crédito. El sistema es Ubuntu 24.04.5 LTS, kernel 6.12.113+. No es Windows ni WSL. Docker Engine 29.9.3 y PowerShell 7.6.9. La transcripción está en [`docs/validacion-lab1-linux.txt`](docs/validacion-lab1-linux.txt).

## Compose

[`infra/docker-compose.yaml`](infra/docker-compose.yaml) define, en la raíz del archivo, `services`, `volumes` y `networks`.

| Pieza | Valor |
| --- | --- |
| Caché | servicio `cache-service`, contenedor `compose-redis`, imagen `redis:7-alpine` |
| Base | servicio `db-service`, contenedor `compose-postgres`, imagen `postgres:16-alpine` |
| Reinicio | `unless-stopped` |
| Puertos | `127.0.0.1:6379` y `127.0.0.1:5432` |
| Volúmenes | `vol_compose_redis:/data`, `vol_compose_postgres:/var/lib/postgresql/data` |
| Red | `red-infraestructura`, bridge |
| Base de datos | usuario `usuario_uleam`, base `db_integracion` |

Redis arranca con `redis-server --appendonly yes`. El ejercicio manual usa esa opción. El informe final del video no la repetía dentro de Compose; se conserva para que el reinicio no dependa solo de la memoria.

Los puertos se publican solo en el loopback. En la clase quedan en 6379 y 5432; aquí no se abren en otras interfaces. `docker port` mostró `127.0.0.1:6379` y `127.0.0.1:5432`.

La contraseña de PostgreSQL no está en el repositorio. Hay que copiar [`infra/.env.example`](infra/.env.example) a `infra/.env` y sustituir `REEMPLAZAR_CON_CONTRASENA_LOCAL`. La sustitución es obligatoria. No se recupera ni se reutiliza la contraseña de la demostración del docente.

## Ejercicio manual

[`scripts/infraestructura.ps1`](scripts/infraestructura.ps1) completa el flujo que en el video quedaba a medias. El archivo visto en clase ejecutaba las dos descargas y `docker images` con el formato de repositorio, etiqueta, ID y tamaño. Los apartados de volúmenes, contenedores, validación y estado eran comentarios vacíos. Este script los ejecuta. No es una transcripción literal.

La recuperación exigida borra `infra-redis` y crea `infra-redis-recuperado` con el mismo volumen `vol_redis_datos`. La clave de muestra `lab1:muestra` volvió a leerse. La copia `docker cp` de `appendonlydir` con Redis en marcha solo se lista en [`.backup_redis/`](.backup_redis/.gitkeep); no se presenta como respaldo consistente y esos archivos no se versionan.

Con `-VerificacionExtraRespaldo` hay una prueba aparte: copia en reposo, volumen vacío y puerto `127.0.0.1:16379`. No sustituye la recuperación por el mismo volumen. El contenedor y el volumen de esa prueba se eliminan al terminar.

## Resultado de la corrida

| Prueba | Resultado |
| --- | --- |
| `docker compose config` | código 0, proyecto `lab1-infraestructura` |
| Redis Compose | `healthy`, `PING` → `PONG`, lectura de `muestra-compose` |
| PostgreSQL | `healthy`, `PostgreSQL 16.15`, `SELECT 1` → `1` |
| Persistencia | tras `down` y `up`, siguen la clave de Redis y la fila `persistencia-postgres` |
| `down -v` | desaparecen `vol_compose_redis`, `vol_compose_postgres` y `red-infraestructura` |
| Aislamiento | `vol_redis_datos` sigue; no hubo `prune` global |

Antes de Compose se eliminó solo `infra-redis-recuperado`, para liberar `127.0.0.1:6379`. El volumen manual se conservó.

Capturas del terminal real:

- [`docs/capturas/01-imagenes.png`](docs/capturas/01-imagenes.png)
- [`docs/capturas/02-recuperacion-mismo-volumen.png`](docs/capturas/02-recuperacion-mismo-volumen.png)
- [`docs/capturas/05-compose-consultas.png`](docs/capturas/05-compose-consultas.png)
- [`docs/capturas/06-compose-persistencia.png`](docs/capturas/06-compose-persistencia.png)

## Uso

```bash
cp infra/.env.example infra/.env
# Sustituir POSTGRES_PASSWORD en infra/.env.
pwsh -File scripts/infraestructura.ps1
docker rm -f infra-redis-recuperado
docker compose -p lab1-infraestructura --env-file infra/.env -f infra/docker-compose.yaml up -d
```

`docker compose down -v` borra los volúmenes de este proyecto. El aviso también quedó en la transcripción. No alcanza a `vol_redis_datos`.

## Entrega

La entrega de la parte 1 es la URL de este repositorio. La migración a Azure y el acceso de lectura del docente no están configurados.

## Referencias

- Docker Engine en Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Compose: https://docs.docker.com/compose/
- Redis: https://hub.docker.com/_/redis
- PostgreSQL: https://hub.docker.com/_/postgres
