#!/bin/bash

# This script runs a `forge script` command and retries up to a maximum number of times with an increasing backoff 
# if the initial attempt fails. The retry will only proceed if a specified broadcast JSON file is available, 
# which indicates that the script has already broadcasted some transaction and need to resume from an interrupted process.

# Requirements:
# - `FORGE_BROADCAST_JSON`: This environment variable must be set outside this script. It should point to the path 
#   of the broadcast JSON file, which stores transaction data and allows `forge` to resume from the last 
#   successful broadcast step. If this file is not found after the first failure, the script will exit.
#
# Hardcoded Retry Settings:
# - `MAX_RETRIES`: Maximum number of retry attempts.
# - `BACKOFF`: Initial backoff time in seconds between retry attempts.

# Maximum number of retries and initial backoff time
MAX_RETRIES=20
BACKOFF=20
BROADCAST_JSON=${FORGE_BROADCAST_JSON}

# Capture all arguments passed to the script for the forge command
forge_args=("$@")

# Step 1: Initial attempt to run the `forge script` without the --resume flag
echo "Initial attempt: Running forge script with args: ${forge_args[*]}"
forge script "${forge_args[@]}"

# Check if the script succeeded on the first attempt
if [ $? -eq 0 ]; then
  echo "Script succeeded on initial attempt."
  exit 0
else 
  echo "Script failed on initial attempt."
fi

# Step 2: Check if the broadcast JSON file exists to decide on retrying with --resume
if [ -f $BROADCAST_JSON ]; then
  echo "Broadcast JSON file found: ${BROADCAST_JSON}. Preparing to retry with --resume."
  forge_args+=("--resume")  # Add the --resume flag to the arguments for resuming previous transactions
else
  echo "Broadcast JSON file not found. Exiting with failure."
  exit 1
fi

# Step 3: Retry loop with --resume
for ((attempts=1; attempts<=MAX_RETRIES; attempts++)); do
  echo "Retry attempt ${attempts} of ${MAX_RETRIES}: Running forge script with --resume."

  # Run the forge script with --resume and real-time output
  forge script "${forge_args[@]}"

  # Check if the script succeeded during the retry
  if [ $? -eq 0 ]; then
    echo "Script succeeded on retry attempt $attempts."
    exit 0
  fi

  # Wait with an increasing backoff before retrying
  echo "Retry attempt ${attempts} failed. Waiting $((BACKOFF * attempts)) seconds before next retry."
  sleep $((BACKOFF * attempts))
done

# Final failure message if all retries are exhausted
echo "Script failed after $MAX_RETRIES attempts."
exit 1
