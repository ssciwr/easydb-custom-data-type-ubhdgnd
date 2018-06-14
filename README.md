# easydb-custom-data-type-ubhdgnd

This is a plugin for [easyDB 5](http://5.easydb.de/) with Custom Data Type
`CustomDataTypeUBHDGND` for references to entities of the [Integrated
Authority File (GND)](https://en.wikipedia.org/wiki/Integrated_Authority_File).

The plugin uses
[authorities-client](https://gitlab.ub.uni-heidelberg.de/Webservices/authorities-client)
supporting different authority data services, such as

  - http://ws.gbv.de/suggest/gnd/ 
  - EntityFacts API Deutsche Nationalbibliothek
    (http://www.dnb.de/DE/Wir/Projekte/Abgeschlossen/entityFacts.html) for
    additional informations about GND entities.
  - https://digi.ub.uni-heidelberg.de/normdaten/

## Setup

In the following replace `unib-heidelberg` with the name of your easydb instance.

```
git clone --recursive https://gitlab.ub.uni-heidelberg.de/kba/easydb-custom-data-type-ubhdgnd \
	/srv/easydb/unib-heidelberg/config/plugin/easydb-custom-data-type-ubhdgnd
cd /srv/easydb/unib-heidelberg/config/plugin/easydb-custom-data-type-ubhdgnd
npm install
make
```

Edit `/srv/easydb/unib-heidelberg/config/easydb5-master.yml`.

Add to or create an array `easydb-server.extension.plugins`:

```yaml
- name: custom-data-type-ubhdgnd
  file: plugin/custom-data-type-ubhdgnd/CustomDataTypeUBHDGND.config.yml
```

Add to or create an array `easydb-server.plugins.enabled+` (**Note** the `+` in the final key):

    - extension.custom-data-type-ubhdgnd

Restart the server docker instance to propagate propagate the new fields to the database system:

    docker restart easydb-server-unib-heidelberg && docker logs --tail=1000 -f easydb-server-unib-heidelberg 

There should be no errors (obviously) but if there are, they will show up in this log.

## Development

This plugin uses [webpack](https://github.com/webpack/webpack) to bundle the
source code and libraries as a single deployable script.

## Configuration

As defined in `CustomDataTypeUBHDGND.config.yml` this datatype can be configured:

### Schema options

* which entity types are offered for search
* which exact type is offered

### Mask options

* whether additional informationen is loaded if the mouse hovers a suggestion in the search result

### Search mapping

The mapping allows fields to be searchable with facets ("Filter"):
```yaml
custom_types:
  ubhdgnd:
    mapping:
      conceptName:
        type: text
      conceptURI:
        type: text
      conceptSeeAlso:
        type: text       
```

See https://github.com/programmfabrik/easydb-documentation/issues/3

Fulltext search is implemented as the concatenation of "conceptName" and "conceptSeeAlso".

## Sources

The source code of this plugin is managed in a git repository at
<https://gitlab.ub.uni-heidelberg.de/kba/easydb-custom-data-type-gnd>. Please
use [the issue
tracker](https://gitlab.ub.uni-heidelberg.de/kba/easydb-custom-data-type-gnd/issues)
for bug reports and feature requests!

It is built upon the
[easydb-library](https://github.com/programmfabrik/easydb-library) base class
for custom easydb data types.

