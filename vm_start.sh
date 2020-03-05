#!/bin/bash
# this scripts to start multiple VMs. Please list all the resoucegroup name and vms list on vm.txt file with comma seperated.
#please put all the Resource group name 7 vm names and save the file as vm.txt.
# example = sst-eastus,sst-demo-vm (resouce group,vm name)
#please use the command ./start_vm.sh (vm.txt file should be in same path)
# example commmand below: ./start_vm.sh

INPUT=vm.txt
OLDIFS=$IFS
IFS=,
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
while read resourcegroup vmname
do
az vm start --resource-group $resourcegroup --name $vmname
az vm list -d -o table --query "[?name=='$vmname']"

done < $INPUT
IFS=$OLDIFS
