#!/bin/bash
if [ "$VERBOSE_LOGGING" = 'true' ]; then
    set -x
fi

all_secrets_file=$(mktemp)
new_secrets_file=$(mktemp)

scan_new_secrets() {
    detect-secrets scan $DETECT_SECRET_ADDITIONAL_ARGS --baseline "$BASELINE_FILE"
    detect-secrets audit "$BASELINE_FILE" --report --json > "$all_secrets_file"
    jq 'map(select(.category == "UNVERIFIED"))' "$all_secrets_file" > "$new_secrets_file"

    if [ "$VERBOSE_LOGGING" = 'true' ]; then
        echo "BASELINE FILE" && cat "$BASELINE_FILE"
        echo "ALL SECRETS" && cat "$all_secrets_file"
        echo "NEW SECRETS" && cat "$new_secrets_file"
    fi
}

markdown_from_new_secrets() {
    secrets_table_body_with_json_chars=$(jq -r '.[] | "|\(.filename)|\(.lines | keys)|\(.types)|"' "$new_secrets_file")
    secret_table_body=$(echo "$secrets_table_body_with_json_chars" | tr -d '"' | tr -d ']'| tr -d '[')

    baseline_with_all_secrets_marked_ok=$(jq 'setpath(["results"]; (.results | map_values(. | map_values(setpath(["is_secret"]; (.is_secret // false))))))' "$BASELINE_FILE")

    cat << EOF
# Secret Scanner Report
## Potential new secrets discovered
|FILE|LINES|TYPES|
|----|-----|-----|
$secret_table_body

## What you should do
### If any of these are secrets
Secrets pushed to GitHub are not safe to use.

For the secrets you have just compromised (it is NOT sufficient to rebase to remove the commit), you should:
* Rotate the secret

### If none of these are secrets
Replace the file \`.secrets.baseline\` with:

<details>
    <summary>Updated Secrets Baseline</summary>

\`\`\`json
$baseline_with_all_secrets_marked_ok
\`\`\`
</details>

EOF
}

echo "::add-matcher::$GITHUB_ACTION_PATH/secret-problem-matcher.json"
scan_new_secrets

if [ "$(cat $new_secrets_file)" = "[]" ]; then
    echo "No secrets found"
    exit 0
fi
markdown_from_new_secrets | tee "$GITHUB_STEP_SUMMARY"
exit 1
