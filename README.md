Full implementation of COVID-19 Digital Green Pass as described here: https://ec.europa.eu/health/sites/default/files/ehealth/docs/covid-certificate_json_specification_en.pdf.

The code scans any Green Pass compliant with the stadard sketched in the EU document,
extract the data from the CBOR structure and verify the signature of the pass against the list of public keys available here: https://verifier-api.coronacheck.nl/v4/verifier/public_keys.

The pass is also displayed on the Apple Watch, when available.

The color of the pass is green when the signature is valid and the date of expiration is at least a week in the future.
If the expiration date is within a week the color will become orange and in all the other cases (invalid signature or expired pass) the color will be red.