PLUGIN_NAME = custom-data-type-gnd-ubhd
PLUGIN_NAME_CAMELCASE = CustomDataTypeGNDUBHD

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
JS_FILES = $(subst .coffee,.js,$(COFFEE_FILES))

TEST_COFFEE_FILES = test/mock.browser.coffee \
	 test/mock.CUI.coffee \
	 test/mock.easyDB.coffee \
	 test/smoke.test.coffee
TEST_JS_FILES = $(subst .coffee,.js,$(TEST_COFFEE_FILES))

JS = build/webfrontend/$(PLUGIN_NAME).js

BROWSERIFY = ./node_modules/.bin/browserify
COFFEE     = ./node_modules/.bin/coffee -cpb
NODEMON    = ./node_modules/.bin/nodemon

.PHONY: clean wipe build all

all: $(JS) $(TEST_JS_FILES)

# {{{ Build

build: entry.js $(JS)

$(JS_FILES): %.js : %.coffee
	$(COFFEE) $< > $@

$(JS): entry.js $(JS_FILES)
	$(BROWSERIFY) -o "$@" entry.js

# }}}

# {{{ clean

clean: clean/build clean/test

clean/build: 
	@rm -fv $(JS_FILES) $(JS)

clean/test:
	rm -rfv $(TEST_JS_FILES)

# }}}

# {{{ Testing

test: build $(TEST_JS_FILES)

$(TEST_JS_FILES): %.js: %.coffee
	$(COFFEE) $< > $@

test/serve: test
	$(MAKE) build
	python -mSimpleHTTPServer
	@echo " -> http://localhost:8000/test/TestRunnner.html"

test/watch:
	$(NODEMON) -e coffee -w entry.js -w src/ -w easydb-library/src/ -w test/ -x make test/serve

# }}}

