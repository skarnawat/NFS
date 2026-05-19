# Manual Instructions for GCVE Storage Configuration

These instructions explain how to manually configure the necessary IAM permissions and enable deletion protection for Google Cloud VMware Engine (GCVE) to access external storage (Filestore or NetApp).

## 1. Prerequisites

*   **Install Google Cloud SDK:** Ensure the Google Cloud SDK (`gcloud`) is installed. If not, follow the instructions at [Google Cloud SDK installation](https://cloud.google.com/sdk/docs/install).
*   **Authenticate:** Log in to Google Cloud:
    ```bash
    gcloud auth login
    ```
*   **Permissions:** Confirm you have sufficient permissions in both the GCVE project and the Storage project to modify IAM policies and manage storage resources.

## 2. Gather Required Information

Collect the following details before proceeding:

*   **GCVE Project Number:** The project number where your VMware Engine Private Cloud is deployed (e.g., `123456789012`).
    *   Placeholder: `[GCVE_PROJECT_NUMBER]`
*   **Storage Type:** Specify `FILESTORE` or `NETAPP`.
*   **Storage Project ID:** The Project ID where the Filestore or NetApp resource resides (e.g., `my-storage-project`).
    *   Placeholder: `[STORAGE_PROJECT_ID]`
*   **Storage Resource Name:**
    *   For Filestore: **Filestore Instance Name** (e.g., `my-filestore-instance`).
        *   Placeholder: `[FILESTORE_INSTANCE_NAME]`
    *   For NetApp: **NetApp Volume Name** (e.g., `my-netapp-volume`).
        *   Placeholder: `[NETAPP_VOLUME_NAME]`
*   **Storage Resource Location:**
    *   For Filestore: **Filestore Instance Location** (e.g., `us-central1` or `us-central1-a`).
        *   Placeholder: `[FILESTORE_LOCATION]`
    *   For NetApp: **NetApp Volume Location** (e.g., `us-central1` or `us-central1-a`).
        *   Placeholder: `[NETAPP_LOCATION]`

## 3. Construct the Service Account Member String

The GCVE Service Agent service account used for these permissions is formatted as:

`serviceAccount=service-[GCVE_PROJECT_NUMBER]@gcp-sa-vmwareengine.iam.gserviceaccount.com`

Replace `[GCVE_PROJECT_NUMBER]` with the value from Step 2.

*   Placeholder for the full string: `[MEMBER_STRING]`

**Example:** If GCVE_PROJECT_NUMBER is `123456789012`, the member string is:
`serviceAccount:service-123456789012@gcp-sa-vmwareengine.iam.gserviceaccount.com`

`MEMBER="serviceAccount:${SERVICE_ACCOUNT}"`

## 4. Grant IAM Permissions

Run the following `gcloud` commands, replacing the placeholders with your collected information.

### Common Permission (All Storage Types)

Grant the `compute.networkViewer` role to the GCVE service account on the **Storage Project hosting Netapp Volume or Filestore Instance network**. **Note** Generally Storage Project and Network Project are same, however sometimes Storage project hosting Netapp Volume/Filestore Instance and Project hosting network of the Netapp Volume/Filestore Instance can be different. 
:


```bash
gcloud projects add-iam-policy-binding [STORAGE_NETWORK_PROJECT_ID] \
    --member="[MEMBER_STRING]" \
    --role="roles/compute.networkViewer" \
    --condition=None
```

### Storage Type Specific Permissions

A. If using **FILESTORE**
Grant the file.viewer role to the service account on the storage project:


```bash
gcloud projects add-iam-policy-binding [STORAGE_PROJECT_ID] \
    --member="[MEMBER_STRING]" \
    --role="roles/file.viewer" \
    --condition=None
```
    
B. If using **NETAPP**
Grant the netapp.viewer role to the service account on the storage project:


```bash
gcloud projects add-iam-policy-binding [STORAGE_PROJECT_ID] \
    --member="[MEMBER_STRING]" \
    --role="roles/netapp.viewer" \
    --condition=None
```

## 5. Enable Deletion Protection
Choose the section below based on your storage type.

A. If using **FILESTORE**
Enable deletion protection on the Filestore instance:


```bash
gcloud filestore instances update [FILESTORE_INSTANCE_NAME] \
    --project=[STORAGE_PROJECT_ID] \
    --location=[FILESTORE_LOCATION] \
    --deletion-protection
```

B. If using **NETAPP**
Enable deletion protection (by restricting delete actions) on the NetApp volume:


```bash
gcloud netapp volumes update [NETAPP_VOLUME_NAME] \
    --project=[STORAGE_PROJECT_ID] \
    --location=[NETAPP_LOCATION] \
    --restricted-actions="delete"
```

## 6. Verification
While the commands provide success or error messages, you can also verify in the Google Cloud Console:

* **IAM Permissions:** Navigate to the IAM page of the [STORAGE_PROJECT_ID] and check if the [MEMBER_STRING] service account has the specified roles.
* **Deletion Protection:**
 + **Filestore:** View the Filestore instance details to see if "Deletion protection" is enabled.
 + **NetApp:** View the NetApp volume details to check the "Restricted actions".
This completes the manual configuration.
