#!env python3.8

import json
import gzip
import requests
from base64 import b64decode

from cryptography.utils import int_to_bytes
from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicKey
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey
from cryptography.hazmat.primitives import serialization

DEFAULT_TRUST_URL = 'https://verifier-api.coronacheck.nl/v4/verifier/public_keys'
DEFAULT_TRUST_UK_URL = 'https://covid-status.service.nhsx.nhs.uk/pubkeys/keys.json'

mykeys = []

url = DEFAULT_TRUST_URL
response = requests.get(url)
pkg = response.json()
payload = b64decode(pkg['payload'])
trustlist = json.loads(payload)
eulist = trustlist['eu_keys']
for kid_b64 in eulist:
    asn1data = b64decode(eulist[kid_b64][0]['subjectPk'])
    pub = serialization.load_der_public_key(asn1data)
    usage = eulist[kid_b64][0]['keyUsage']
    if len(usage) == 0:
        usage = ["v","t","r"]

    if (isinstance(pub, RSAPublicKey)):
        mykeys.append({"kid": kid_b64, "algo": "RSA", "usage": usage, "e": list(int_to_bytes(pub.public_numbers().e)), "n": list(int_to_bytes(pub.public_numbers().n))})
    if (isinstance(pub, EllipticCurvePublicKey)):
        mykeys.append({"kid": kid_b64, "algo": "EC", "usage": usage, "x": list(pub.public_numbers().x.to_bytes(32, byteorder="big")), "y": list(pub.public_numbers().y.to_bytes(32, byteorder="big"))})


url = DEFAULT_TRUST_UK_URL
response = requests.get(url)
trustlist = response.json()
for e in trustlist:
    asn1data = b64decode(e['publicKey'])
    pub = serialization.load_der_public_key(asn1data)
    usage = ["v","t","r"]
    if (isinstance(pub, RSAPublicKey)):
            mykeys.append({"kid": e['kid'], "algo": "RSA", "usage": usage, "e": list(int_to_bytes(pub.public_numbers().e)), "n": list(int_to_bytes(pub.public_numbers().n))})
    if (isinstance(pub, EllipticCurvePublicKey)):
        mykeys.append({"kid": e['kid'], "algo": "EC", "usage": usage, "x": list(pub.public_numbers().x.to_bytes(32, byteorder="big")), "y": list(pub.public_numbers().y.to_bytes(32, byteorder="big"))})

json_str = json.dumps(mykeys) + "\n"               # 2. string (i.e. JSON)
json_bytes = json_str.encode('utf-8')            # 3. bytes (i.e. UTF-8)

with gzip.open("../iOS/Green Pass/ehn-dcc-valuesets-main/pub_keys.json.gz","w") as f:
    f.write(json_bytes)

prefix = "https://raw.githubusercontent.com/ehn-dcc-development/ehn-dcc-valuesets/release/2.0.0/"
files = [ "country-2-codes.json", "disease-agent-targeted.json", "vaccine-prophylaxis.json",
                "vaccine-medicinal-product.json", "vaccine-mah-manf.json", "country-2-codes.json",
                "test-type.json", "test-result.json", "test-manf.json" ]

for filename in files:
    url = prefix+filename
    response = requests.get(url)
    pkg = response.json()
    with open("../iOS/Green Pass/ehn-dcc-valuesets-main/"+filename,"w") as f:
        json.dump(pkg, f)
