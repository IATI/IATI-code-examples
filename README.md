# IATI code examples

Here you'll find a small selection of code examples written to make use of IATI's APIs, data, and tools. Unless otherwise noted, all code is licensed under [GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.en.html). In other words, you are free to modify, distribute, warranty, or commercially use this code as long as it's also licensed under the GNU Affero GPL. If you have an idea for a code example to host here, or want to see an existing example written in a different programming language, please let us know at [code@iatistandard.org](mailto:code@iatistandard.org).

Setup and testing instructions for the code examples may be found in the corresponding README files:
- [Javascript](/Javascript/README.md)
- [Python](/Python/README.md)
- [R](/R/README.md)

Our code examples include:

## Applying codelist names to numerical codes

One common operation required to make semantic use of IATI data is the transformation of machine-readable codes into human-readable names. Below are some examples of how to make these transformations. These examples assume you're already familiar with the IATI Datastore API; if not, please see the documentation on the IATI API Gateway: [https://developer.iatistandard.org/](https://developer.iatistandard.org/).

We have examples of how to download our codelist mappings, download all codelists, and match code values downloaded from the Datastore in JSON to their codelist names in the following languages:

- [Javascript](/Javascript/codelists/index.js)
- [Python](/Python/codelists/codelists.py)
- [R](/R/codelists/index.R)

## Converting currencies

Another common operation required to make IATI data comparable is the conversion to a common currency. IATI does not have one official source for exchange rates, but in the data folder of this repository you'll find a sample of daily exchange rates sourced from the IMF from January 1, 1994 to July 6, 2022. As the sample data we're using comes from the Datastore, all fields required are already in the correct data types, and conversion is a simple matter of looking up the appropriate rate and multiplying.

We have examples of how to convert currencies for transactions and budgets available in the following languages:

- [Javascript](/Javascript/currency/index.js)
- [Python](/Python/currency/currency.py)
- [R](/R/currency/index.R)

## Converting IATI XML into nested JSON objects (deprecated as of [IATI Unified Platform Refresher v2.5.0](https://github.com/IATI/refresher/releases/tag/v2.5.0))

Note: This functionality has been fully replicated within the IATI Unified Platform, and may now be accessed without additional processing by the `/iati_json` endpoint of the Datastore API. Full documentation is available on the [IATI Developer Platform](https://developer.iatistandard.org/api-details#api=datastore).

We have examples of how to convert IATI XML into nested JSON objects available in the following languages:

- [Javascript](/Javascript/xml_to_json/index.js)
- [Python](/Python/xml_to_json/xml_to_json.py)
- [R](/R/xml_to_json/index.R)
