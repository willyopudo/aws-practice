# kcov + bats, for `make coverage`. Pinned by digest; bump deliberately.
FROM kcov/kcov@sha256:481289ae32e55e5b733019515acd10948a4f76dfed381765577db909664fc603
RUN apt-get update \
 && apt-get install -y --no-install-recommends bats jq git \
 && rm -rf /var/lib/apt/lists/*
