#!/bin/bash

set -e

logger "Arrancando instalacion y configuracion de MongoDB"

USO="Uso : instalar-mongodb.sh -f config.ini
Ejemplo:
instalar-mongodb.sh -f config.ini
Opciones:
-f fichero de configuracion (obligatorio)
-a muestra esta ayuda"

function ayuda() {
  echo "${USO}"
  if [[ ${1} ]]; then
    echo ${1}
  fi
}

# Gestionar los argumentos
while getopts ":f:a" OPCION; do
  case ${OPCION} in
    f ) CONFIG_FILE=$OPTARG
        echo "Usando fichero de configuracion: '${CONFIG_FILE}'";;
    a ) ayuda; exit 0;;
    : ) ayuda "Falta el parametro para -$OPTARG"; exit 1;;
    \?) ayuda "La opcion no existe : $OPTARG"; exit 1;;
  esac
done

if [[ -z ${CONFIG_FILE} ]]; then
  ayuda "El fichero de configuracion (-f) debe ser especificado"; exit 1
fi

# Leer parametros del fichero de configuracion
if [[ ! -f ${CONFIG_FILE} ]]; then
  echo "El fichero ${CONFIG_FILE} no existe"; exit 1
fi

source ${CONFIG_FILE}

if [[ -z ${user} || -z ${password} || -z ${port} ]]; then
  echo "El fichero de configuracion debe contener las claves 'user', 'password' y 'port'"; exit 1
fi

# Preparar el repositorio (apt-get) de mongodb añadir su clave apt

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 4B7C549A058F8B6B

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb.list

echo "-------- Installing mongodb----------------"

if [[ -z "$(mongo --version 2> /dev/null | grep '4.2.1')" ]]
then
  # Instalar paquetes comunes, servidor, shell, balanceador de shards y herramientas

  apt-get -y update \
  && apt-get install -y \
  mongodb-org=4.2.1 \
  mongodb-org-server=4.2.1 \
  mongodb-org-shell=4.2.1 \
  mongodb-org-mongos=4.2.1 \
  mongodb-org-tools=4.2.1 \
  && rm -rf /var/lib/apt/lists/* \
  && pkill -u mongodb || true \
  && pkill -f mongod || true \
  && rm -rf /var/lib/mongodb
fi
# Crear las carpetas de logs y datos con sus permisos

[[ -d "/datos/bd" ]] || mkdir -p -m 755 "/datos/bd"
[[ -d "/datos/log" ]] || mkdir -p -m 755 "/datos/log"
# Establecer el dueño y el grupo de las carpetas db y log

chown mongodb /datos/log /datos/bd
chgrp mongodb /datos/log /datos/bd

echo "-------- configuracion mongodb----------------"

# Crear el archivo de configuracion de mongodb con el puerto solicitado
mv /etc/mongod.conf /etc/mongod.conf.orig
(
cat <<MONGOD_CONF
# /etc/mongod.conf
systemLog:
   destination: file
   path: /datos/log/mongod.log
   logAppend: true
storage:
   dbPath: /datos/bd
   engine: wiredTiger
   journal:
      enabled: true
net:
   port: ${port}
   bindIp: 127.0.0.1
security:
  authorization: enabled
MONGOD_CONF
) > /etc/mongod.conf

# Reiniciar el servicio de mongod para aplicar la nueva configuracion

systemctl restart mongod

echo "Esperando a que MongoDB esté listo para aceptar conexiones..."

while ! mongo --eval "db.stats()" admin >/dev/null 2>&1; do
  echo "MongoDB aún no está listo. Reintentando en 1 segundo..."
  sleep 1
done

echo "MongoDB está listo para aceptar conexiones."

# Crear usuario con la password proporcionada como parametro

mongo admin << CREACION_DE_USUARIO
db.createUser({
    user: "${user}",
    pwd: "${password}",
    roles:[{
        role: "root",
        db: "admin"
    },{
        role: "restore",
        db: "admin"
}] })
CREACION_DE_USUARIO

echo "-------- fin --------"

logger "El usuario ${user} ha sido creado con exito!"
exit -1
