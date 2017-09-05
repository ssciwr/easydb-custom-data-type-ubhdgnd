PLUGIN_NAME = custom-data-type-ubhdgnd
PLUGIN_NAME_CAMELCASE = CustomDataTypeUBHDGND

WEBPACK = webpack --config webpack.config.js 

L10N_FILES = l10n/$(PLUGIN_NAME).csv
L10N_GOOGLE_KEY = 1Z3UPJ6XqLBp-P8SUf-ewq4osNJ3iZWKJB83tc6Wrfn0
L10N_GOOGLE_GID = 1200588352
L10N2JSON = python easydb-library/tools/l10n2json.py

INSTALL_FILES = \
	$(WEB)/l10n/cultures.json \
	$(WEB)/l10n/de-DE.json \
	$(WEB)/l10n/en-US.json \
	$(WEB)/l10n/es-ES.json \
	$(WEB)/l10n/it-IT.json \
	$(JS) \
	$(PLUGIN_NAME_CAMELCASE).config.yml

COFFEE_FILES = easydb-library/src/commons.coffee \
	src/webfrontend/$(PLUGIN_NAME_CAMELCASE).coffee

JS = $(WEB)/${PLUGIN_NAME}.raw.js

all: build

include easydb-library/tools/base-plugins.make

build: code $(L10N)

clean: clean-base

wipe: wipe-base

.PHONY: clean wipe

$(WEB)/$(PLUGIN_NAME).raw.coffee: $(COFFEE_FILES)
	cat $^ > $@

$(WEB)/$(PLUGIN_NAME).raw.js: $(WEB)/$(PLUGIN_NAME).raw.coffee
	coffee -cb $<

$(WEB)/$(PLUGIN_NAME).js: $(WEB)/$(PLUGIN_NAME).raw.js
	$(WEBPACK) $^ $@

webpack: $(WEB)/$(PLUGIN_NAME).js
	-rm src/webfrontend/$(PLUGIN_NAME_CAMELCASE).coffee.js

watch:
	./node_modules/.bin/nodemon -e coffee -x make webpack
