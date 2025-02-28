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
Enter SID of Database: <SID>
Enter Instance for SID: <Instance_no>

- `<SID>`: Enter the HANA System ID for which data needs to be validated.
- `<Instance_no>`: Enter the valid instance number of the provided HANA System SID.

## Function Descriptions:

