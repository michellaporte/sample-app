#!/bin/bash
#Script to do Proxmox Api Calls
#Maintainer: Michel Laporte
#Essence Digital
#V0.1

CAT << EOF
###################################################################################
#This Script needs the following packages on your machine:                        #
#-Curl                                                                            #
#-JQ                                                                              #
# Installation:                                                                   #
#    Please check out the GitHub Page https://stedolan.github.io/jq/download/     #
#    For ubuntu, please run apt-get instsall jq                                   #
#                                                                                 #
# !!!!!!!Please be aware that cookie and headers are only valid for 2 hours!!!!!! #
###################################################################################

EOF

##############################
#All global Variables go here#
##############################
case_close=0 
#######################
#All Functions go here#
#######################

#Authentication to the Prox Host. This is run first
function authentication() {

    echo -e "Enter the host IP of the proxmox (e.g 192.168.0.1) Default is 192.168.32.90: "
    read -rp "Proxmox IP: " prox_ip
    prox_ip="${prox_ip:-192.168.32.90}"
    
    echo -e "Enter the username of the Proxmox host. The default is root: "
    read -rp "Proxmox Username: " prox_username
    prox_ip="${prox_ip:-root}"

    echo -e "Enter the password to authenticate with the Proxmox Hypervisor: "
    read -sp "Password: " prox_pass
    echo -e "\n"

    echo -e "Enter prox port. The default 8006, if haven't haven't changed it, just press [Enter]: "
    read -p  "Enter the new Prox Post or Press [Enter] for default: " prox_port
    prox_port="${prox_port:-8006}"

    echo -e "Current Config \n\
    Proxmox Endpoint=${prox_ip} \n\
    Proxmox Password=**hidden for security** \n\
    Proxmox Port=${prox_port}"

    pause 'Press [Enter] key to acknowledge...'
    echo -e "Getting Cookie and Headers, please wait \n"
    sleep 1
    
    get_cookie
    get_header
    sleep 1

}
#Authentication to the Prox Host. This is run first
function authentication_vars() {

    echo -e "Enter the host IP of the proxmox (e.g 192.168.0.1) Default is 192.168.32.90: "
    read -rp "Proxmox IP: " prox_ip
    prox_ip="${prox_ip:-192.168.32.90}"
    
    echo -e "Enter the username of the Proxmox host. The default is root: "
    read -rp "Proxmox Username: " prox_username
    prox_ip="${prox_ip:-root}"

    echo -e "Enter the password to authenticate with the Proxmox Hypervisor: "
    read -sp "Password: " prox_pass
    echo -e "\n"

    echo -e "Enter prox port. The default 8006, if haven't haven't changed it, just press [Enter]: "
    read -p  "Enter the new Prox Post or Press [Enter] for default: " prox_port
    prox_port="${prox_port:-8006}"

    echo -e "Current Config \n\
    Proxmox Endpoint=${prox_ip} \n\
    Proxmox Password=**hidden for security** \n\
    Proxmox Port=${prox_port}"

    pause 'Press [Enter] key to acknowledge...'
}
#Get Cookie Function that retrieves a 2 hour Cookie
function get_cookie {
    curl --silent --insecure --data "username=${prox_username}@pam&password=${prox_pass}" \
    https://${prox_ip}:${prox_port}/api2/json/access/ticket\
    | jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie
    echo -e "Your cookie is saved in `pwd`/cookie\n"
}
#Get Headers Cookie that is needed to HTTP Post methods.
function get_header {
    curl --silent --insecure --data "username=${prox_username}@pam&password=${prox_pass}" \
    https://${prox_ip}:${prox_port}/api2/json/access/ticket\
    | jq --raw-output '.data.CSRFPreventionToken' | sed 's/^/CSRFPreventionToken:/' > csrftoken
    echo "Your header is saved in `pwd`/csrftoken"
}
#Next VMID available
function get_next_vmid {
    unset next_vmid
    next_vmid=$(curl --silent --insecure --cookie "$(<cookie)" https://192.168.32.90:8006/api2/json/cluster/nextid | sed 's/"//g; s/{//g; s/}//g; s/data://g';)
    echo -e "Please use VMID ${next_vmid}"
    sleep 2
}
#Function for a prompt without using read
function pause() {
   read -p "$*"
}
#List OS Images for LXC
function list_lxc_images() {
curl  --silent --insecure --cookie "$(<cookie)" https://${prox_ip}:${prox_port}/api2/json/nodes/michel-prox/storage/local/content | jq '.data[] | [{volid}][0]' | sed 's/volid//g; s/""://g; s/"//g; s/{//g; s/}//g;'
}
#Create LXC
function create_lxc_container() {
echo "What Image would you like? Please copy and paste the whole line."
    sleep 1
    list_lxc_images
    read -p "Which image? : " image_iso
echo -e "Please wait while we find a VMID for you"
    sleep 1
    get_next_vmid
    read -p "Enter the VM ID: " vmid
echo -e "Enter the IP Address"
    read -p "IP: " ip_address
echo -e "Enter the Gateway IP"
    read -p "Enter the Gateway: " gw_ip
echo -e "Enter the Search Domain e.g essence.internal.com"
    read -p "Enter DNS Search: " dns_ip
echo -e "Enter a hostname"
    read -p "Enter Hostname: " hostname_var
echo -e "Enter RAM in units. E.G 1024"
    read -p "Enter Ram Units: " memory_var
echo -e "Creating LXC container with distro ${image_iso} & VMID ${vmid} "
    sleep 2
 curl --silent --insecure  --cookie "$(<cookie)" --header "$(<csrftoken)" -X POST --data-urlencode ostemplate="${image_iso}" --data-urlencode net0="name=myct0,bridge=vmbr0,ip=${ip_address}/22,gw=${gw_ip}" --data-urlencode searchdomain="${dns_ip}" --data vmid=${vmid} --data hostname=${hostname_var} --data memory=${memory_var} --data storage=local-lvm https://${prox_ip}:${prox_port}/api2/json/nodes/michel-prox/lxc
}

if [ -f cookie ] && [ -f csrftoken ]
then
    echo -e "This is the latest stats of the files, do you wish to create new ones?\n"
    sleep 1
    stat -l cookie csrftoken   
    while true; do
    read -p "Y or N: " decision
        case $decision in
            [Yy]* ) authentication; break;;
            [Nn]* ) echo "Using Defaults, Please enter information..."; authentication_vars ;;
            * ) echo "Please answer Y or N.";;
        esac
    done
else
echo "Not here, Getting new headers...."
authentication
fi

####################################
#Code Definitions                  #
####################################

while (( !case_close )); do
PS3='What would you like to do?: '
    options=("Get list of LXC" "Get a new VMID" "Create a LXC container" "Start|Stop a LXC" "List Operating System Images" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Get list of LXC")
                curl --silent --insecure --cookie "$(<cookie)" https://${prox_ip}:8006/api2/json/nodes/michel-prox/lxc | jq '.'; break ;;
            "Get a new VMID")
                get_next_vmid; break ;;
            "Create a LXC container")
                create_lxc_container; ;;
                "Start|Stop a LXC")
                curl --silent --insecure  --cookie "$(<cookie)" --header "$(<csrftoken)" -X POST https://192.168.32.90:8006/api2/json/nodes/michel-prox/lxc/${vmid}/status/start | jq '.';
                if [ $? -eq 0 ]
                then
                    echo -e "\n Started successfully, details are as follows on current state of VM ${vmid} \n"
                    sleep 2
                    curl --silent --insecure  --cookie "$(<cookie)" --header "$(<csrftoken)" https://192.168.32.90:8006/api2/json/nodes/michel-prox/lxc/${vmid}/status/current | jq '.';
                else
                    echo "error in starting"
                fi;
                    break;;
                "List Operating System Images")
                list_lxc_images; break ;;
            "Quit")
                case_close=1; break;;
            *) echo invalid option;;
        esac
    done
done      