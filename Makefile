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
	$(PLUGIN_NAME_CAMELCASE).config.yml

COFFEE_FILES = easydb-library/src/commons.coffee \
    src/UBHDGNDUtil.coffee \
	src/webfrontend/OptionsTreeConfigPlugin.coffee \
	src/webfrontend/$(PLUGIN_NAME_CAMELCASE).coffee

SCSS_FILES = src/webfrontend/CustomDataTypeUBHDGND.scss

UPDATE_SCRIPT_COFFEE_FILES = \
	src/UBHDGNDUtil.coffee \
	src/script/UBHDGNDUpdate.coffee

UPDATE_SCRIPT_BUILD_FILE = build/scripts/ubhdgnd-update.js

${UPDATE_SCRIPT_BUILD_FILE}: $(subst .coffee,.coffee.js,${UPDATE_SCRIPT_COFFEE_FILES})
	mkdir -p $(dir $@)
	cat $^ > $@

include easydb-library/tools/base-plugins.make

build: code $(L10N) ${UPDATE_SCRIPT_BUILD_FILE}

JS = $(WEB)/${PLUGIN_NAME}.raw.js

export

all: build

include easydb-library/tools/base-plugins.make

scss_call = node-sass --scss --no-cache --sourcemap=inline

build: code css $(L10N)

code: webpack

clean: clean-base

wipe: wipe-base

.PHONY: clean wipe

JS = $(WEB)/${PLUGIN_NAME}.raw.js

$(WEB)/$(PLUGIN_NAME).raw.coffee: $(COFFEE_FILES)
	mkdir -p $(dir $@)
	cat $^ > $@

$(WEB)/$(PLUGIN_NAME).raw.js: $(WEB)/$(PLUGIN_NAME).raw.coffee
	coffee -cb $<

$(WEB)/$(PLUGIN_NAME).js: $(JS)
	$(WEBPACK) $< $@

webpack: $(WEB)/$(PLUGIN_NAME).js
	@echo $(JS)
	-rm src/webfrontend/$(PLUGIN_NAME_CAMELCASE).coffee.js

watch:
	./node_modules/.bin/nodemon -e 'coffee scss' -x make scss webpack

l10n: build-stamp-l10n

help:
	@echo "l10n       Rebuild l10n JSON"
	@echo "code       Compile coffeescript and concatenate"
	@echo "webpack    Compile to deployable bundle"
	@echo "watch      Run 'make webpack' whenever source changes"
	@echo "clean      Remove intermediary and built files"

