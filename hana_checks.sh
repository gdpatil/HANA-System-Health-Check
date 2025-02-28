#!/bin/bash
#------------------------------------------------------
# Author: Gaurav Patil
# Contact: gaurav.patil@suse.com
# VERSION_NUMBER=1.0
#-------------------------------------------------------

# Log file names
LOG_FILE="hana_system_info.html"
ERROR_LOG="error.log"

# Function to log output with color
log_output() {
    local message="$1"
    local color="$2"
    local hostname="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="${message//\\n/<br>}"   
   echo "<p>[$timestamp] <span style=\"color:$color;\">[$hostname] $message</span></p>" >> "$LOG_FILE"
}

# Function to log headers
log_header() {
    echo "<h2><b>$1</b></h2>" >> "$LOG_FILE"
}

# Function to log subheaders
log_subheader() {
    #echo "<h3><b>$1</b></h3>" >> "$LOG_FILE"
    echo "<h3><b>${1//\\n/<br>}</b></h3>" >> "$LOG_FILE"
}

log_content_list() {
    echo "<h4><b>${1//\\n/<br>}</b></h4>" >> "$LOG_FILE"
}

# Function to start HTML file
start_html() {
    echo "<html><head><title>HANA Cluster System Info</title></head><body>" > "$LOG_FILE"
}

# Function to end HTML file
end_html() {
    echo "</body></html>" >> "$LOG_FILE"
}

# Function to add seperator line between 2 outputs
add_separator_line() {
    echo "<hr style=\"border-color: green;\">" >> "$LOG_FILE"
    echo "<hr style=\"border-color: black;\">" >> "$LOG_FILE"
}

# Funciton to check if ssh connection is working 

check_ssh_connection()
{
   get_cluster_nodes
log_subheader "Checking connection to: $cluster_node_list"
	for node in $cluster_node_list; do
	    if ! ssh "$node" "true"; then
            	message="Error: Unable to connect to node: $node"
            	log_output "$message" "red" "$node"
            	echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] $message" | tee -a "$ERROR_LOG"
        	exit 1
	else
                message="Success: Connected to node: $node"
            log_output "$message" "green" "$node"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] $message" 

	    fi
       done
add_separator_line
}

# Function to check if the system is HANA
check_hana_system() {
 for node in $cluster_node_list; do
        if ! ssh "$node" "[ -d \"/usr/sap/$sid\" ]"; then
            message="Error: SID not found: $sid"
            log_output "$message" "red" "$node"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] $message" | tee -a "$ERROR_LOG"
            exit 1
        elif ! ssh "$node" "[ -d \"/usr/sap/$sid/HDB$instance\" ]"; then
            message="Error: Instance not found for SID: $sid, Instance: $instance"
            log_output "$message" "red" "$node"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] $message" | tee -a "$ERROR_LOG"
            exit 1
        fi
    done
}

# Function to get cluster node names
get_cluster_nodes() {
    cluster_node_list=$(crm node show | grep -oP '\w+\(\d+\)' | awk -F'(' '{print $1}')
}

# Function to check HANA system type - SCALE-UP OR SCALE-OUT
check_hana_system_type() {
log_subheader "Check HANA System Type (scale-out or scale-up)\n"
    for node in $cluster_node_list; do
        log_output "HANA System Type:" "black" "$node"
        hana_system_overview=$(ssh "$node" "su - $sid_lower\adm -c 'HDBSettings.sh systemOverview.py' 2>/dev/null" 2>>"$ERROR_LOG")
        distributed_value=$(echo "$hana_system_overview" | grep "Distributed" | awk '{print $7}')
        if [[ "$distributed_value" == "No" ]]; then
            log_output "Scale-Up System" "green" "$node"
        elif [[ "$distributed_value" == "Yes" ]]; then
            log_output "Scale-Out System" "green" "$node"
        else
            log_output "Could not determine system type" "red" "$node"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] Could not determine system type" >> "$ERROR_LOG"
        fi
    done
add_separator_line
}

#check_hostagent() {
#    for node in $cluster_node_list; do
#        log_output "Hostagent:" "black" "$node"
#        echo "<pre>" >> "$LOG_FILE"
#        ssh "$node" "systemctl list-unit-files | grep -i sap" >> "$LOG_FILE" 2>>"$ERROR_LOG"
#        echo "</pre>" >> "$LOG_FILE"
#    done
#}


# Function to check database status
check_database_status() {
log_subheader "DB status check\n"
    for node in $cluster_node_list; do
        log_output "Database Status:" "black" "$node"
        echo "<pre>" >> "$LOG_FILE"
        ssh "$node" "su - $sid_lower\adm -c 'systemd-cgls -u SAP.slice' 2>/dev/null" >> "$LOG_FILE" 2>>"$ERROR_LOG"
        echo "</pre>" >> "$LOG_FILE"
    done
add_separator_line
}

# Function to check replication status
check_replication_status() {
log_subheader "Replication status check\n"
    for node in $cluster_node_list; do
        log_output "Replication Status:" "black" "$node"
        echo "<pre>" >> "$LOG_FILE"
        ssh "$node" "su - $sid_lower\adm -c 'HDBSettings.sh systemReplicationStatus.py' 2>/dev/null" >> "$LOG_FILE" 2>>"$ERROR_LOG"
        ssh "$node" "su - $sid_lower\adm -c 'hdbnsutil -sr_state' 2>/dev/null" >> "$LOG_FILE" 2>>"$ERROR_LOG"
        echo "</pre>" >> "$LOG_FILE"
    done
add_separator_line
}

# Function to check HA/DR providers
check_ha_dr_providers() {
log_subheader "HA-DR provider check\n"
    for node in $cluster_node_list; do
        log_output "HA/DR Providers:" "black" "$node"
        global_ini="/usr/sap/$sid/SYS/global/hdb/custom/config/global.ini"
        if ssh "$node" "[ -f '$global_ini' ]"; then
            echo "<pre>" >> "$LOG_FILE"
            ssh "$node" "cat '$global_ini'" >> "$LOG_FILE" 2>>"$ERROR_LOG"
            echo "</pre>" >> "$LOG_FILE"
            add_separator_line
	    
	    log_output "Sudoers entries:" "black" "$node"
            echo "<pre>" >> "$LOG_FILE"
            ssh "$node" "cat /etc/sudoers.d/*" 2>/dev/null >> "$LOG_FILE" 2>>"$ERROR_LOG"
            echo "</pre>" >> "$LOG_FILE"
        add_separator_line
	else
            log_output "global.ini not found" "red" "$node"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$node] global.ini not found" >> "$ERROR_LOG"
        add_separator_line
	fi
    done
add_separator_line
}

# Function to check hook integration
check_hook_integration() {
log_subheader "Hook integration check\n"
    log_output "Hook Integration:" "black"
    for node in $cluster_node_list; do
        echo "<pre>" >> "$LOG_FILE"
        ssh "$node" "su - $sid_lower\adm -c \"cdtrace; grep HADR.*load.*SAPHanaSR nameserver_*.trc | head -n 5; grep SAPHanaSR.init nameserver_*.trc | head -n 5; grep HADR.*load.*susTkOver nameserver_*.trc | head -n 5; grep susTkOver.init nameserver_*.trc | head -n 5; grep HADR.*load.*susChkSrv nameserver_*.trc | head -n 5; grep susChkSrv.init nameserver_*.trc | head -n 5; egrep '(LOST:|STOP:|START:|DOWN:|init|load|fail)' nameserver_suschksrv.trc | head -n 5; grep SAPHanaSR.srConnection.*CRM nameserver_*.trc | head -n 5; grep SAPHanaSR.srConnection.*fallback nameserver_*.trc | head -n 5; grep susTkOver.preTakeover.*permit nameserver_*.trc | head -n 5; grep susTkOver.preTakeover.*failed.*50277 nameserver_*.trc | head -n 5\"" 2>/dev/null >> "$LOG_FILE" 2>>"$ERROR_LOG"
        echo "</pre>" >> "$LOG_FILE"
add_separator_line
    done
}

# Function to check saptune status
check_saptune() {
    for node in $cluster_node_list; do
        log_output "saptune Solution Applied:" "black" "$node"
        saptune_output=$(ssh "$node" "saptune solution applied" 2>>"$ERROR_LOG")
        if echo "$saptune_output" | grep -qE "HANA|S4HANA-DBSERVER"; then
            log_output "saptune Solution Applied: $(echo "$saptune_output" | grep -E 'HANA|S4HANA-DBSERVER')" "green" "$node"
        else
            log_output "saptune Solution Applied: $saptune_output" "red" "$node"
	fi
    done
add_separator_line
}


compare_node_details() {
    get_cluster_nodes

    declare -A node_details
log_subheader "Compare both nodes for \n 1. Kernel version\n 2. Cluster packages\n 3. OS version\n 4. DB version\n 5. Hostagent details\n"
add_separator_line

    for node in $cluster_node_list; do
        #log_subheader "Checking details for node: $node"

log_content_list "1. Kernel version\n"
        # Kernel version
        kernel_version=$(ssh "$node" "uname -r")
        log_output "Kernel version: $kernel_version" "black" "$node"
add_separator_line

log_content_list "2.Cluster packages\n"
        # Installed cluster packages version
        echo "<pre>" >> "$LOG_FILE"
	cluster_packages=$(ssh "$node" "rpm -qa | grep -E 'pacemaker-cli|corosync|SAPHanaSR|sap-suse-cluster-connector|patterns-sap-hana|supportutils-plugin-ha-sap'")
#	cluster_packages=$(ssh "$node" "rpm -qa") 
    	log_output "Cluster packages: $cluster_packages" "black" "$node"
	echo "</pre>" >> "$LOG_FILE"	
add_separator_line

log_content_list "3. OS version\n"
        # OS version
        echo "<pre>" >> "$LOG_FILE"
	 os_version=$(ssh "$node" "cat /etc/os-release | grep -E 'VERSION|VARIANT_ID'")
        log_output "OS version: $os_version" "black" "$node"
	echo "</pre>" >> "$LOG_FILE"
add_separator_line

log_content_list "4. DB version\n"
        # DB version
        sid_lower=$(echo "$sid" | tr '[:upper:]' '[:lower:]')
        db_version=$(ssh "$node" "su - $sid_lower\adm -c 'HDBSettings.sh systemOverview.py' 2>/dev/null | grep 'Version' | awk '{print \$7}'")
        log_output "DB version: $db_version" "black" "$node"
add_separator_line		

log_content_list "5. Hostagent details\n"
	# Hostagent details
	# log_output "Hostagent:" "black" "$node"
        echo "<pre>" >> "$LOG_FILE"
        hostagent=$(ssh "$node" "systemctl list-unit-files | grep -i sap")
        log_output "Hostagent details: $hostagent" "black" "$node"
        echo "</pre>" >> "$LOG_FILE"
add_separator_line		
        # Store the details in an associative array
        node_details["$node,kernel_version"]=$kernel_version
        node_details["$node,cluster_packages"]=$cluster_packages
        node_details["$node,os_version"]=$os_version
        node_details["$node,db_version"]=$db_version
		node_details["$node,hostagent"]=$hostagent
    done

    # Compare the details between nodes
    log_subheader "Comparing details between nodes"
    first_node=""
    for node in $cluster_node_list; do
        if [ -z "$first_node" ]; then
            first_node=$node
        else
            log_subheader "Comparing $first_node and $node"

	    # Kernel version comparison
            if [ "${node_details["$first_node,kernel_version"]}" != "${node_details["$node,kernel_version"]}" ]; then
                log_output "Kernel version mismatch: $first_node (${node_details["$first_node,kernel_version"]}) vs $node (${node_details["$node,kernel_version"]})" "red" "$node"
            else
                log_output "Kernel version match: $first_node (${node_details["$first_node,kernel_version"]}) vs $node (${node_details["$node,kernel_version"]})" "green" "$node"
            fi
add_separator_line
            # Cluster packages comparison
            if [ "${node_details["$first_node,cluster_packages"]}" != "${node_details["$node,cluster_packages"]}" ]; then
        echo "<pre>" >> "$LOG_FILE"        
	log_output "Cluster packages mismatch:" "red" "$node"
	log_output "$first_node (${node_details["$first_node,cluster_packages"]})" "red" "$node"
	log_output "vs" "red" "$node"
	log_output "$node (${node_details["$node,cluster_packages"]})" "red" "$node"
        echo "</pre>" >> "$LOG_FILE"
        
	    else
	echo "<pre>" >> "$LOG_FILE"
        log_output "Cluster packages match:" "green" "$node"
        log_output "$first_node (${node_details["$first_node,cluster_packages"]})" "green" "$node"
        log_output "vs" "green" "$node"
        log_output "$node (${node_details["$node,cluster_packages"]})" "green" "$node"
        echo "</pre>" >> "$LOG_FILE"

	    fi
add_separator_line
            # OS version comparison
            if [ "${node_details["$first_node,os_version"]}" != "${node_details["$node,os_version"]}" ]; then
        echo "<pre>" >> "$LOG_FILE"        
	log_output "OS version mismatch:" "red" "$node"
	log_output "$first_node (${node_details["$first_node,os_version"]})" "red" "$node" 
	log_output "vs" "red" "$node"
	log_output "$node (${node_details["$node,os_version"]})" "red" "$node"
	echo "</pre>" >> "$LOG_FILE"

            else
		echo "<pre>" >> "$LOG_FILE"
	log_output "OS version match:" "green" "$node"
        log_output "$first_node (${node_details["$first_node,os_version"]})" "green" "$node"
        log_output "vs" "green" "$node"
        log_output "$node (${node_details["$node,os_version"]})" "green" "$node"
		echo "</pre>" >> "$LOG_FILE"
            fi
add_separator_line
            # DB version comparison
            if [ "${node_details["$first_node,db_version"]}" != "${node_details["$node,db_version"]}" ]; then
                log_output "DB version mismatch: $first_node (${node_details["$first_node,db_version"]}) vs $node (${node_details["$node,db_version"]})" "red" "$node"
            else
                log_output "DB version match: $first_node (${node_details["$first_node,db_version"]}) vs $node (${node_details["$node,db_version"]})" "green" "$node"
            fi
add_separator_line			
	    # hostagent Compare
	    if [ "${node_details["$first_node,hostagent"]}" != "${node_details["$node,hostagent"]}" ]; then
            	echo "<pre>" >> "$LOG_FILE"
		log_output "Hostagent version mismatch:" "red" " "
                log_output "$first_node \n(${node_details["$first_node,hostagent"]})" "red" " "
                log_output "vs" "red" "$node"
                log_output "$node \n(${node_details["$node,hostagent"]})" "red" " "
		echo "</pre>" >> "$LOG_FILE"
            else
		echo "<pre>" >> "$LOG_FILE"
                log_output "Hostagent version match:" "green" " "
                log_output "$first_node \n ${node_details["$first_node,hostagent"]}" "green" " "
                log_output "vs" "green" " "
                log_output "$node \n ${node_details["$node,hostagent"]}" "green" " "
		echo "</pre>" >> "$LOG_FILE"
            fi
add_separator_line			
        fi
    done
add_separator_line
}


# Main script execution
start_html

# Prompt user for SID and instance number
read -p "Enter SID of Database: " sid
read -p "Enter Instance for SID: " instance
sid_lower=$(echo "$sid" | tr '[:upper:]' '[:lower:]')


log_header "HANA System health check for $sid:"
add_separator_line

log_content_list " 1. Check cluster nodes\n\n 2. Kernel version check\n\n 3. Cluster packages check\n\n 4. OS version Check\n\n 5. DB version check\n\n 6. System Type check\n\n 7. saptune check\n\n 8. Hosagent check\n\n 9. DB status check\n\n 10. Replication status check\n\n 11. HA-DR provider check\n\n 12. Hook integration check\n"
add_separator_line

get_cluster_nodes

check_ssh_connection

compare_node_details

check_hana_system

check_hana_system_type

check_saptune

check_database_status

check_replication_status

check_ha_dr_providers

check_hook_integration

end_html

exit 0

