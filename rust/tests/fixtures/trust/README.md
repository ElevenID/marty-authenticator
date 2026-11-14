# Trust availability fixture

`public_ca.pem` is a synthetic P-256 CA certificate generated solely for registry
loading tests. Its private key was generated in memory and was never stored.
It is not an issuer trust anchor for any deployed environment.

The configured-registry regression loads this certificate and confirms that
invalid chain bytes reach native certificate validation. It does not establish
AAMVA certificate-profile conformance or an installed-device trust flow.
