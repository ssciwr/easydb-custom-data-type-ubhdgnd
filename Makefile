DATA_TYPE_NAME=GND

L10N2JSON = docker exec -t -i easydb-server-unib-heidelberg /usr/bin/env LD_LIBRARY_PATH=/easydb-5/lib /easydb-5/bin/l10n2json
all: ${JS_FILE} build-stamp-l10n

include easydb-custom-data-type-boilerplate.make
