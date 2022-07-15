# Secret Scanner
## The Problem
People will sometimes commit secrets to a GitHub repository

## How it works
Uses [`Yelp/detect-secrets`](https://github.com/Yelp/detect-secrets) to look for newly committed secrets. If it finds any potential secrets, it will:
* Fail
* Create a Job Summary with a list of the potential secrets found, and some advice on how to deal with the issue
* Provide an updated secrets baseline that contains the newly added secrets. This is useful if secrets that were discovered are not actually secrets.

## How to use it
First, create a `.secrets.baseline` in the repo you want to add this action to. For more details on what this file represents, visit [the README for Yelp/detect-secrets](https://github.com/Yelp/detect-secrets#detect-secrets):
```
cd PATH_TO_REPOSITORY
pip install detect-secrets[gibberish]==1.2.0
detect-secrets scan > .secrets.baseline
detect-secrets audit .secrets.baseline
```

Second, add this GitHub action to your workflow or create a new one. A basic workflow would be:
```yaml
# File: .github/workflows/detect-new-secrets.yml
name: Checking for Secrets
on: push
jobs:
  check-secrets:
    name: Checking for Secrets
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v3
      - name: Secret Scanner
        uses: secret-scanner/action@0.0.2
```

You can also pass arguments to `detect-secrets` by using `detect-secret-additional-args`. For information on the arguments that you can pass, visit [Yelp/detect-secrets#filters](https://github.com/Yelp/detect-secrets#filters). For example:
```yaml
name: Checking for Secrets
on: push
env:
  SCANNER_ARGS: |
      --exclude-files \.github/actions/spelling/.*
      --exclude-lines ^\s+with\s+imageTag\s*=.*$
jobs:
  check-secrets:
    name: Checking for Secrets
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Configuration
        uses: actions/checkout@v3
      - name: Secret Scanner
        uses: secret-scanner/action@0.0.2
        with:
          detect-secret-additional-args: ${{ env.SCANNER_ARGS }}
```

This will ignore everything in `.github/actions/spelling/*`, and any line that matches the regex `^\s+with\s+imageTag\s*=.*$`.

### Inputs
|Input|Description|Required|default value|
|-----|-----------|--------|-------------|
|detect-secrets-version|The version of Yelp/detect-secrets to use|no|1.2.0|
|detect-secret-additional-args|Extra arguments to pass to the `detect-secret` binary when it is looking for secrets|no|No additional arguments (empty string)|
|baseline-file|A path to the baseline secrets file|no|.secrets.baseline|
|python-version|The version of python to use|no|3.10.4|
