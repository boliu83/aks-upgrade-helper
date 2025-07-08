#!/usr/bin/env bash
set -euo pipefail

# Directory containing schedule files
SCHEDULE_DIR="schedules"

# Time window in seconds (8 hours)
TIME_WINDOW=$((8 * 3600))

# Stub for the actual upgrade function - assume implemented elsewhere
run_aks_upgrade() {
  local subscriptionId="$1"
  local resourceGroup="$2"
  local resourceName="$3"
  echo "Upgrading AKS cluster '$resourceName' in resource group '$resourceGroup' (subscription: $subscriptionId)..."
  # Example Azure CLI call (uncomment and adjust as needed):
  # az aks upgrade \
  #   --subscription "$subscriptionId" \
  #   --resource-group "$resourceGroup" \
  #   --name "$resourceName" \
  #   --control-plane-only \
  #   --yes
}

# Function to validate ISO 8601 UTC timestamp (YYYY-MM-DDThh:mm[:ss]Z)
validate_iso8601() {
  local ts="$1"
  # Regex: date T time Z, optional seconds
  if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?Z$ ]]; then
    return 0
  fi
  return 1
}


# Get current time in UTC (seconds since epoch)
NOW_UTC=$(date -u +"%s")

# Process each .txt file under the schedule directory
for file in "$SCHEDULE_DIR"/*.txt; do
  [[ -e "$file" ]] || continue
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines or lines starting with '#'
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    IFS=',' read -r subscriptionId resourceGroup resourceName targetVersion scheduledUtc <<< "$line"

    # Validate ISO 8601 format
    if ! validate_iso8601 "$scheduledUtc"; then
      echo $line " - Error: schedule time '$scheduledUtc' is not in ISO 8601 UTC format (YYYY-MM-DDThh:mm[:ss]Z). Skipping..."  
      continue
    fi

    # Parse scheduled time to epoch (UTC)
    scheduledEpoch=$(date -u -d "$scheduledUtc" +"%s" 2>/dev/null || echo "")
    if [[ -z "$scheduledEpoch" ]]; then
      echo "Warning: could not parse date '$scheduledUtc' in file $file" >&2
      continue
    fi

    # Compute time difference
    delta=$(( scheduledEpoch - NOW_UTC ))

    echo -n $line " - "
    # Check if the upgrade is within the next 8 hours
    if (( delta >= 0 && delta <= TIME_WINDOW )); then
      echo "Scheduled upgrade is in current upgrade window. Triggering upgrade."
      run_aks_upgrade "$subscriptionId" "$resourceGroup" "$resourceName"
    else
      if (( delta < 0 )); then
        echo "Scheduled upgrade is in the past. Skipping..."
      fi

      if (( delta > TIME_WINDOW )); then
        echo "Scheduled upgrade is beyond the current upgrade window. Skipping..."
      fi
    fi
  done < "$file"
done

