#!/bin/bash


# Copyright 2026 Google LLC

#

# Licensed under the Apache License, Version 2.0 (the "License");

# you may not use this file except in compliance with the License.

# You may obtain a copy of the License at

#

#    https://www.apache.org/licenses/LICENSE-2.0

#

# Unless required by applicable law or agreed to in writing, software

# distributed under the License is distributed on an "AS IS" BASIS,

# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# See the License for the specific language governing permissions and

# limitations under the License.


# ==============================================================================

# Script to configure IAM permissions and Deletion Protection for GCVE storage

# ==============================================================================

#

# This script grants the Google Cloud VMware Engine (GCVE) Service Agent

# the necessary permissions on either a Filestore instance or a NetApp volume.

# It also enables deletion protection on the specified storage resource.

#

# Requirements:

#   - gcloud CLI installed and authenticated.

#     (https://cloud.google.com/sdk/docs/install)

#   - Appropriate permissions to modify IAM policies and storage resources

#     in the respective projects.

#

# Instructions:

#   1. Run the script: ./configure_gcve_storage.sh

#   2. Enter the requested information when prompted.

#


# --- Global error flag ---

error_occurred=false


# --- Function to report errors ---

report_error() {

  echo "ERROR: $1" >&2

  error_occurred=true

}


# --- Function to prompt for input ---

prompt_for_input() {

  local prompt_text="$1"

  local var_name="$2"

  local regex="${3:-}" # Optional regex for validation

  local regex_error_msg="${4:-Invalid format}" # Optional custom message for regex failure

  local input_value


  while true; do

    read -p "$prompt_text: " input_value

    printf -v "$var_name" "%s" "$input_value" # Assign value to the variable name passed in var_name


    local value="${!var_name}"


    if [[ -z "$value" ]]; then

      echo "Error: This field cannot be empty." >&2

      continue

    fi


    if [[ -n "$regex" ]]; then

      if [[ ! "$value" =~ $regex ]]; then

        echo "Error: $regex_error_msg" >&2

        continue

      fi

    fi

    break

  done

}


# --- Get Configuration Variables ---


PROJECT_NUMBER_REGEX='^[1-9][0-9]*$'

prompt_for_input "Enter your GCVE Project Number (e.g., 123456789012)" GCVE_PROJECT_NUMBER "$PROJECT_NUMBER_REGEX" "Please enter a valid GCP Project Number (numbers only, no letters, hyphens, or leading zeros. e.g., 123456789012)"


while true; do

  read -p "Enter the Storage Type (FILESTORE or NETAPP): " STORAGE_TYPE

  STORAGE_TYPE=$(echo "$STORAGE_TYPE" | tr 'a-z' 'A-Z') # Convert to uppercase

  if [[ "$STORAGE_TYPE" == "FILESTORE" ]] || [[ "$STORAGE_TYPE" == "NETAPP" ]]; then

    break

  else

    echo "Error: Invalid STORAGE_TYPE. Must be either FILESTORE or NETAPP." >&2

  fi

done


PROJECT_ID_REGEX='^[a-z][a-z0-9-]{4,28}[a-z0-9]$'

prompt_for_input "Enter the Project ID where the $STORAGE_TYPE resource resides" STORAGE_PROJECT_ID "$PROJECT_ID_REGEX" "Project ID must be 6-30 chars, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."


# --- Get Resource Specific Variables ---


RESOURCE_NAME_REGEX='^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$'

RESOURCE_NAME_MSG="Must be 1-63 characters, start with a lowercase letter, end with a lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."


NETAPP_VOLUME_NAME_REGEX='^[a-zA-Z][a-zA-Z0-9-]{0,62}$'

NETAPP_VOLUME_NAME_MSG="Must be 1-63 characters, start with a letter, and contain only letters, numbers, and hyphens."


if [[ "$STORAGE_TYPE" == "FILESTORE" ]]; then

  prompt_for_input "Enter the Filestore Instance Name" FILESTORE_INSTANCE_NAME "$RESOURCE_NAME_REGEX" "$RESOURCE_NAME_MSG"

  prompt_for_input "Enter the Filestore Instance Location (e.g., us-central1 or us-central1-a)" FILESTORE_LOCATION

elif [[ "$STORAGE_TYPE" == "NETAPP" ]]; then

  prompt_for_input "Enter the NetApp Volume Name" NETAPP_VOLUME_NAME "$NETAPP_VOLUME_NAME_REGEX" "$NETAPP_VOLUME_NAME_MSG"

  prompt_for_input "Enter the NetApp Volume Location (e.g., us-central1)" NETAPP_LOCATION

fi


# --- Check for gcloud CLI ---

if ! command -v gcloud &> /dev/null

then

    echo "Error: gcloud CLI not found. Please install and initialize it to continue." >&2

    echo "See: https://cloud.google.com/sdk/docs/install-sdk" >&2

    exit 1

fi


# Optional: Suggest updating gcloud

echo "Ensuring gcloud components are up to date..."

if ! gcloud components update --quiet; then

  report_error "gcloud components update failed. Continuing, but issues may arise."

fi


# --- Derived Variables ---

SERVICE_ACCOUNT="service-$GCVE_PROJECT_NUMBER@gcp-sa-vmwareengine.iam.gserviceaccount.com"


MEMBER="serviceAccount:${SERVICE_ACCOUNT}"


echo "--- Summary ---"

echo "GCVE Project Number: $GCVE_PROJECT_NUMBER"

echo "Storage Type: $STORAGE_TYPE"

echo "Storage Project ID: $STORAGE_PROJECT_ID"

echo "Service Account: $MEMBER"


if [[ "$STORAGE_TYPE" == "FILESTORE" ]]; then

  echo "Filestore Instance: $FILESTORE_INSTANCE_NAME"

  echo "Filestore Location: $FILESTORE_LOCATION"

elif [[ "$STORAGE_TYPE" == "NETAPP" ]]; then

  echo "NetApp Volume: $NETAPP_VOLUME_NAME"

  echo "NetApp Location: $NETAPP_LOCATION"

fi

echo "---------------"


read -p "Do you want to proceed? (y/N): " confirm

if ! [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then

  echo "Operation cancelled."

  exit 0

fi


# --- Set IAM Permissions ---

echo "Setting IAM permissions..."


if [[ "$STORAGE_TYPE" == "FILESTORE" ]]; then

  echo "Granting roles/file.viewer to $MEMBER on project $STORAGE_PROJECT_ID..."

  if ! gcloud projects add-iam-policy-binding "$STORAGE_PROJECT_ID" --member="$MEMBER" --role="roles/file.viewer" --condition=None; then

    report_error "Failed to grant roles/file.viewer."

  fi


  echo "Granting roles/compute.networkViewer to $MEMBER on project $STORAGE_PROJECT_ID..."

  if ! gcloud projects add-iam-policy-binding "$STORAGE_PROJECT_ID" --member="$MEMBER" --role="roles/compute.networkViewer" --condition=None; then

    report_error "Failed to grant roles/compute.networkViewer."

  fi


elif [[ "$STORAGE_TYPE" == "NETAPP" ]]; then

  echo "Granting roles/netapp.viewer to $MEMBER on project $STORAGE_PROJECT_ID..."

  if ! gcloud projects add-iam-policy-binding "$STORAGE_PROJECT_ID" --member="$MEMBER" --role="roles/netapp.viewer" --condition=None; then

    report_error "Failed to grant roles/netapp.viewer."

  fi


  echo "Granting roles/compute.networkViewer to $MEMBER on project $STORAGE_PROJECT_ID..."

  if ! gcloud projects add-iam-policy-binding "$STORAGE_PROJECT_ID" --member="$MEMBER" --role="roles/compute.networkViewer" --condition=None; then

    report_error "Failed to grant roles/compute.networkViewer."

  fi

fi


# --- Set Deletion Protection ---

if ! $error_occurred; then # Only proceed if IAM was successful

  echo "Setting Deletion Protection..."


  if [[ "$STORAGE_TYPE" == "FILESTORE" ]]; then

    echo "Enabling deletion protection for Filestore instance: $FILESTORE_INSTANCE_NAME..."

    if gcloud filestore instances update "$FILESTORE_INSTANCE_NAME" --project="$STORAGE_PROJECT_ID" --location="$FILESTORE_LOCATION" --deletion-protection; then

      echo "Filestore deletion protection enabled successfully."

    else

      report_error "Failed to enable Filestore deletion protection."

    fi


  elif [[ "$STORAGE_TYPE" == "NETAPP" ]]; then

    echo "Enabling deletion protection for NetApp volume: $NETAPP_VOLUME_NAME..."

    if gcloud netapp volumes update "$NETAPP_VOLUME_NAME" --project="$STORAGE_PROJECT_ID" --location="$NETAPP_LOCATION" --restricted-actions="delete"; then

      echo "NetApp volume deletion protection enabled successfully."

    else

      report_error "Failed to enable NetApp volume deletion protection."

    fi

  fi

else

    echo "Skipping Deletion Protection due to previous errors."

fi


# --- Final Message ---

echo "--------------------------------------------------"

if $error_occurred; then

  echo "Errors occurred during the script execution."

  echo "Please review the messages above, correct any issues (e.g., permissions, project/instance names, locations), and try again."

  exit 1

else

  echo "Configuration complete."

  exit 0

fi
