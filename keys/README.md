# keys/

`stunmesh.pub` is the public half of the RSA 4096 key that signs this
repository's pkg catalogs. The private half is kept out of this repo, in
the `PKG_PRIVATE_KEY` GitHub Actions secret; the CI "feed" job uses it to
sign each ABI's catalog with `pkg repo`, and the same job verifies the
result against this committed public key before anything is published.

Before trusting a fresh install, check this file's fingerprint against
the copy fetched over HTTPS:

```sh
openssl rsa -pubin -in keys/stunmesh.pub -outform DER | openssl dgst -sha256
```

Compare that against the fingerprint of the key fetched by `install.sh`
or by hand from `https://tjjh89017.github.io/stunmesh-opnsense/stunmesh.pub`.
They must match exactly. See the main [README](../README.md#signing-key)
for how this key is generated and rotated.
