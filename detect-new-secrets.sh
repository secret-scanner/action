#!/bin/bash
all_secrets_file=$(mktemp)
new_secrets_file=$(mktemp)
command_to_update_baseline_file=$(mktemp)

fetch_flags_from_file() {
    flag_to_add="$1"
    file_to_check="$2"
    
    flags=()
    while read line; do 
        if [[ "${line::1}" != '#' ]] && [[ ! -z "$line" ]]; then
            flag="$flag_to_add $line "
            flags+="$flag"
        fi
    done < "$file_to_check"

    echo "$flags"
}

scan_new_secrets() {
    excluded_files=$(fetch_flags_from_file '--exclude-files' "$EXCLUDE_FILES_PATH")
    excluded_secrets=$(fetch_flags_from_file '--exclude-secrets' "$EXCLUDE_SECRETS_PATH")
    excluded_lines=$(fetch_flags_from_file '--exclude-lines' "$EXCLUDE_LINES_PATH")
    detect_secret_args="$excluded_files $excluded_secrets $excluded_lines $DETECT_SECRET_ADDITIONAL_ARGS"

    detect-secrets scan $detect_secret_args --baseline "$BASELINE_FILE"
    detect-secrets audit "$BASELINE_FILE" --report --json > "$all_secrets_file"
    jq 'map(select(.category == "UNVERIFIED"))' "$all_secrets_file" > "$new_secrets_file"
}

advice_if_none_are_secret_short() {
    jobs_summary_link="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT"

    cat << EOF
### If none of these are secrets or you don't care about these secrets
1. Visit →→→"$jobs_summary_link"
2. Run the command under \`Command to Update Secrets Baseline\`
3. Push the generated commit to GitHub
EOF
}

generate_command_to_update_secrets_baseline() {
    cat << EOF > "$command_to_update_baseline_file"
currently_staged_files=\`git diff --name-only --cached\`
git reset HEAD

echo '$(jq 'setpath(["results"]; (.results | map_values(. | map_values(setpath(["is_secret"]; (.is_secret // false))))))' "$BASELINE_FILE")' > "$BASELINE_FILE"
git add "$BASELINE_FILE"
git commit -m "Updating baseline file"

if [ "\$currently_staged_files" ]; then
    git add $currently_staged_files
fi
EOF
}

advice_if_none_are_secret_verbose() {
    generate_command_to_update_secrets_baseline

    cat << EOF
### If none of these are secrets or you don't care about these secrets
Replace the file \`$BASELINE_FILE\` with:

<details>
    <summary>Command to Update Secrets Baseline</summary>

\`\`\`sh
EOF
    cat "$command_to_update_baseline_file" << EOF
\`\`\`
</details>
EOF
}

markdown_from_new_secrets() {
    secrets_table_body_with_json_chars=$(jq -r '.[] | "|\(.filename)|\(.lines | keys)|\(.types)|"' "$new_secrets_file")
    secret_table_body=$(echo "$secrets_table_body_with_json_chars" | tr -d '"' | tr -d ']'| tr -d '[')

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
EOF
}

echo "::add-matcher::$GITHUB_ACTION_PATH/secret-problem-matcher.json"
scan_new_secrets

if [ "$(cat $new_secrets_file)" = "[]" ]; then
    echo "No new secrets found"
    exit 0
fi

markdown_limited_advice=$(markdown_from_new_secrets)
markdown_console_advice=$(advice_if_none_are_secret_short)

# Print a short message to the console
echo "$markdown_limited_advice"
echo "$markdown_console_advice"

# Write a more detailed message to the jobs summary
echo "$markdown_limited_advice" > "$GITHUB_STEP_SUMMARY"
advice_if_none_are_secret_verbose >> "$GITHUB_STEP_SUMMARY"

exit 1
