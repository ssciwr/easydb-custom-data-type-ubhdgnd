PATH := ./node_modules/.bin:$(PATH)

PLUGIN_NAME = custom-data-type-ubhdgnd
PLUGIN_NAME_CAMELCASE = CustomDataTypeUBHDGND

WEBPACK = webpack --config webpack.config.js

L10N_FILES = easydb-library/src/commons.l10n.csv l10n/$(PLUGIN_NAME).csv
L10N_GOOGLE_KEY = 1Z3UPJ6XqLBp-P8SUf-ewq4osNJ3iZWKJB83tc6Wrfn0
L10N_GOOGLE_GID = 1200588352
L10N2JSON = python easydb-library/tools/l10n2json.py

INSTALL_FILES = \
	$(WEB)/l10n/cultures.json \
	$(WEB)/l10n/de-DE.json \
	$(WEB)/l10n/en-US.json \
	$(WEB)/l10n/es-ES.json \
	$(WEB)/l10n/it-IT.json \
	build/scripts/gnd-update.js \
	$(JS) \
	$(CSS) \
	manifest.yml

COFFEE_FILES = easydb-library/src/commons.coffee \
    src/UBHDGNDUtil.coffee \
	src/webfrontend/OptionsTreeConfigPlugin.coffee \
	src/webfrontend/$(PLUGIN_NAME_CAMELCASE).coffee

SCSS_FILES = src/webfrontend/CustomDataTypeUBHDGND.scss

UPDATE_SCRIPT_COFFEE_FILES = \
	src/UBHDGNDUtil.coffee \
	src/script/UBHDGNDUpdate.coffee

UPDATE_SCRIPT_BUILD_FILE = build/scripts/ubhdgnd-update.js

all: build

include easydb-library/tools/base-plugins.make

build: code css $(L10N)

${UPDATE_SCRIPT_BUILD_FILE}: $(subst .coffee,.coffee.js,${UPDATE_SCRIPT_COFFEE_FILES})
	mkdir -p $(dir $@)
	cat $^ > $@


export

code: ${JS} ${UPDATE_SCRIPT_BUILD_FILE}

clean: clean-base

wipe: wipe-base

.PHONY: clean wipe

${JS}: $(subst .coffee,.coffee.js,${COFFEE_FILES})
	mkdir -p $(dir $@)
	cat $^ > $(WEB)/$(PLUGIN_NAME).entry.js
	$(WEBPACK) $(WEB)/$(PLUGIN_NAME).entry.js $@
	rm $(WEB)/$(PLUGIN_NAME).entry.js

watch:
	./node_modules/.bin/nodemon -e 'coffee scss' -x make css ${JS}

l10n: build-stamp-l10n

help:
	@echo "l10n       Rebuild l10n JSON"
	@echo "code       Compile coffeescript and concatenate"
	@echo "webpack    Compile to deployable bundle"
	@echo "watch      Run 'make webpack' whenever source changes"
	@echo "clean      Remove intermediary and built files"

