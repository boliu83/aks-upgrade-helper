#!/usr/bin/env bash
# work out scheduled delay in minutes until a future date in ISO 8601 format

calculate_minutes_until() {
    local future_date input_epoch now_epoch diff_seconds diff_minutes

    future_date="$1"


    # check if the data is formatted as mm/dd/yyyy hh:mm:ss
    # this is workaround for an ADO pipeline issue where the date variable is inexplicitly formatted as mm/dd/yyyy hh:mm:ss
    # https://developercommunity.visualstudio.com/t/iso-8601-timestamp-string-is-being-converted-to-da/989390
    if [[ "$future_date" =~ ^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}[[:space:]][0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]]; then
        # convert to ISO 8601 format
        future_date=$(date -d "$future_date" +%Y-%m-%dT%H:%M:%S 2>/dev/null)
    fi

    if [[ ! "$future_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]]; then
        printf "Error: Invalid ISO 8601 date format\n" >&2
        return 1
    fi

    # the future date must be UTC time
    if ! input_epoch=$(date -u -d "$future_date" +%s 2>/dev/null); then
        printf "Error: Unable to parse the future date\n" >&2
        return 1
    fi

    if ! now_epoch=$(date +%s); then
        printf "Error: Unable to retrieve current time\n" >&2
        return 1
    fi

    if (( input_epoch <= now_epoch )); then
        printf "Error: Provided date is not in the future\n" >&2
        return 1
    fi

    diff_seconds=$(( input_epoch - now_epoch ))
    diff_minutes=$(( diff_seconds / 60 ))

    printf "%d\n" "$diff_minutes"
}

main() {
    if [[ $# -ne 1 ]]; then
        printf "Usage: %s <future-date-in-ISO8601>\n" "$0" >&2
        return 1
    fi

    local result
    if ! result=$(calculate_minutes_until "$1"); then
        return 1
    fi

    printf "%s" "$result"
}

main "$@"