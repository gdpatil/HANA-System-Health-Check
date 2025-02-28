# HANA-System-Health-Check
This script provides insights into your HANA cluster systems by comparing key configurations across both nodes. It gathers information about the kernel version, installed cluster packages, OS version, database version, and hostagent status. By comparing these details, the script highlights any discrepancies between the nodes, helping you identify potential issues and ensure consistency across your cluster environment.

### DISCLAIMER
This script is provided as-is, without warranty of any kind. Use it at your own risk.

## Prerequisites
- Bash shell
- Linux system

## Usage
To execute the script, provide the following inputs:

$ ./hana_checks.sh

Enter SID of Database: `<SID>`

Enter Instance for SID: `<Instance_no>`

- `<SID>`: Enter the HANA System ID for which data needs to be validated.
- `<Instance_no>`: Enter the valid instance number of the provided HANA System SID.

## Function Descriptions:
**get_cluster_nodes()**

This function extracts the names of the nodes in the cluster. These names are used to establish SSH connections for gathering system details.

**check_ssh_connection()**

This function verifies that passwordless SSH connections are working correctly between both nodes in the cluster.

**compare_node_details()**

This is the core function of the script. It compares the following details between both nodes:

*Kernel version*
*Installed cluster packages*
*Hostagent details*
*OS version*
*Database version*
*check_hana_system*

This function verifies that the target system is a valid HANA system.

**check_hana_system_type()**

This function determines whether the HANA system is a scale-up or scale-out system.

**check_saptune()**

This function checks if SAPtune is correctly configured for the HANA system on both nodes.

**check_database_status()**

This function checks if the database is currently accessible using the command systemd-cgls -u SAP.slice.

**check_replication_status()**

This function checks the replication status of the HANA system from both nodes.

**check_ha_dr_providers()**

This function extracts the global.ini and sudoers configuration, allowing verification of their correctness.

**check_hook_integration()**

This function verifies if the hooks are correctly configured and are able to list the expected logs.
