## created by Shashi_Rao
MyEcho ()
{
   # prepend timestamp to text ($2) on both screen and a file ($1)
   myCurrentTime=`date "+%Y-%m-%d-%T"`
   echo "${myCurrentTime} $2" | tee -a $1
}


CreateRG ()
{
   # Create resource group to ease Azure resource management
   # Need owner permission in Azure
   myLogfile="${myLogTag}${1}"
   MyEcho "$myLogfile" "Started creating Resource Group $myResourceGroup"
   az group create --name $myResourceGroup --location $myLocation 2>&1 | tee -a $myLogfile
   MyEcho "$myLogfile" "Finished creating Resource Group $myResourceGroup"
}


CreateNet ()
{
   # 1. Create private network and subnet
   myLogfile="${myLogTag}${1}"
   MyEcho "$myLogfile" "Started creating private network $myNet ($myNetPrefix) and subnet $mySubnet ($mySubnetPrefix)"

   az network vnet create \
      --resource-group $myResourceGroup --location $myLocation \
      --name $myNet --address-prefix $myNetPrefix \
      --subnet-name $mySubnet --subnet-prefix $mySubnetPrefix \
      2>&1 | tee -a ${myLogfile}
   MyEcho "$myLogfile" "Finished creating private network $myNet ($myNetPrefix) and subnet $mySubnet ($mySubnetPrefix)"


   # 2. Create one NIC for each VM
   # 2a. Edge node get a public IP address for access from outside of Azure.
   for ((i=0; i<$numEdgeNode; i++)); do { {

      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myLogfile="${myLogTag}${1}$myVM"

      # Create public IP address of the edge node for external access
      MyEcho "$myLogfile" "Started creating public IP address $myPublicIPaddr$i for ${myVM}"
      az network public-ip create \
         --resource-group $myResourceGroup --location $myLocation \
         --allocation-method Static --name $myPublicIPaddr$i \
         2>&1 | tee -a "${myLogfile}"
      MyEcho "$myLogfile" "Finished creating public IP address $myPublicIPaddr$i for ${myVM}"

      MyEcho "$myLogfile" "Started creating Nic for ${myVM}"
      az network nic create \
         --resource-group $myResourceGroup --location $myLocation \
         --vnet-name $myNet --subnet $mySubnet \
         --name $myVM$myNicSuffix \
         --private-ip-address ${ArrayVMs[$((i*$numAttr+$offsetIPaddr))]} \
         --public-ip-address $myPublicIPaddr$i \
         2>&1 | tee -a "${myLogfile}"
      MyEcho "$myLogfile" "Finished creating Nic for ${myVM}"
      } & }
   done

   # 2b. Non-edge nodes do not get a public IP address for access from outside of Azure
   for ((i=$numEdgeNode; i<$numVMs; i++)); do { {
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myLogfile="${myLogTag}${1}$myVM"

      MyEcho "$myLogfile" "Started creating Nic for ${myVM}"
      az network nic create \
         --resource-group $myResourceGroup --location $myLocation \
         --vnet-name $myNet --subnet $mySubnet \
         --name $myVM$myNicSuffix \
         --private-ip-address ${ArrayVMs[$(($i*$numAttr+$offsetIPaddr))]} \
         2>&1 | tee -a "${myLogfile}"
      MyEcho "$myLogfile" "Finished creating Nic for ${myVM}"
      } & }
   done
   wait
}


CreateRawVMs ()
{
   for ((i=0; i<$numVMs; i++)); do { {
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myLogfile="${myLogTag}${1}$myVM"

      MyEcho "$myLogfile" "Started creating VM ${myVM}"
      az vm create \
         --resource-group $myResourceGroup --location $myLocation \
         --image $myOSimage --admin-username $myAdminUser --admin-password $myAdminPw \
         --size ${ArrayVMs[$(($i*$numAttr+$offsetVMsize))]} \
         --name $myVM \
         --nics $myVM$myNicSuffix \
         2>&1 | tee -a "${myLogfile}"
      MyEcho "$myLogfile" "Finished creating VM ${myVM}"
      } & }
   done
   wait
}


DeactivateVM ()
{
   for ((i=0; i<$numVMs; i++)); do { {
      myLogfile="${myLogTag}${1}${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      MyEcho "$myLogfile" "Started deactivating VM $myVM"
      az vm deallocate --resource-group $myResourceGroup --name $myVM \
         2>&1 | tee -a "$myLogfile"
      MyEcho "$myLogfile" "Finished deactivating VM $myVM"
      } & }
   done;
   wait
}


ActivateVM ()
{
   for ((i=0; i<$numVMs; i++)); do { {
      myLogfile="${myLogTag}${1}${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      MyEcho "$myLogfile" "Started activating VM $myVM"
      az vm start --resource-group $myResourceGroup --name $myVM \
         2>&1 | tee -a "$myLogfile"
      MyEcho "$myLogfile" "Finished activating VM $myVM"
   } & }
   done;
   wait
}

DeleteNetAndVM ()
{
Cleanup $1
}

ArchiveNetAndVM ()
{
Cleanup $1
}

Cleanup ()
{
   for ((i=0; i<$numVMs; i++)); do { {
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myLogfile="${myLogTag}${1}${myVM}"

      if [ $1 = "Archive" ]; then

         MyEcho "$myLogfile" "Started deallocating VM $myVM"
         az vm deallocate --resource-group $myResourceGroup --name $myVM \
            2>&1 | tee -a "${myLogfile}"
         MyEcho "$myLogfile" "Finished deallocating VM $myVM"

         MyEcho "$myLogfile" "Started generalizing VM $myVM"
         az vm generalize --resource-group $myResourceGroup --name $myVM \
            2>&1 | tee -a "${myLogfile}"
         MyEcho "$myLogfile" "Finished generalizing VM $myVM"

         MyEcho "$myLogfile" "Started creating VM image $myVM$myImgSuffix"
         az image create \
            --resource-group $myResourceGroup --name $myVM$myImgSuffix --source $myVM \
            2>&1 | tee -a "${myLogfile}"
         MyEcho "$myLogfile" "Finished creating VM image $myVM$myImgSuffix"
      fi

      vmdisk=$(az vm show \
         --resource-group $myResourceGroup --name $myVM \
         --query "storageProfile.osDisk.name" --output tsv)

      MyEcho "$myLogfile" "Started deleting VM $myVM"
      az vm delete --resource-group $myResourceGroup --name $myVM --yes \
         2>&1 | tee -a "${myLogfile}"

      MyEcho "$myLogfile" "deleting $vmdisk"
      az disk delete \
         --resource-group $myResourceGroup --name $vmdisk --yes \
         2>&1 | tee -a "${myLogfile}"

      MyEcho "$myLogfile" "deleting Nic for $myVM"
      az network nic delete --resource-group $myResourceGroup --name $myVM$myNicSuffix \
         2>&1 | tee -a "${myLogfile}"

      MyEcho "$myLogfile" "Finished deleting VM $myVM"
   } & }
   done;
   wait

   # delete network
   myLogfile="${myLogTag}${1}Net"
   MyEcho "$myLogfile" "Started deleting network $myNet"
   az network vnet delete --resource-group $myResourceGroup --name $myNet \
      2>&1 | tee -a ${myLogfile}
   MyEcho "$myLogfile" "Finished deleting network $myNet"

   # Delete public IP address of edge node(s)
   for ((i=0; i<$numEdgeNode; i++)); do {
      MyEcho "$myLogfile" "Started deleting public-ip address $myPublicIPaddr$i"
      az network public-ip delete \
         --resource-group $myResourceGroup --name $myPublicIPaddr$i \
         2>&1 | tee -a ${myLogfile}
      MyEcho "$myLogfile" "Finished deleting public-ip address $myPublicIPaddr$i"
   }
   done;
}


RestoreNetAndVM ()
{
   CreateNet "${1}Net"

   # Restore = Create VM from image
   for ((i=0; i<$numVMs; i++)); do { {
      myVM="${myCluster}${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}"
      myLogfile="${myLogTag}${1}${myVM}"
      MyEcho "$myLogfile" "Started restoring VM $myVM"
      az vm create \
         --resource-group $myResourceGroup --location $myLocation \
         --admin-user $myAdminUser --admin-password $myAdminPw \
         --image $myCluster${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}$myImgSuffix \
         --size ${ArrayVMs[$(($i*$numAttr+$offsetVMsize))]} \
         --name $myCluster${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]} \
         --nics $myCluster${ArrayVMs[$(($i*$numAttr+$offsetSuffix))]}$myNicSuffix \
         2>&1 | tee -a "${myLogfile}"
      MyEcho "$myLogfile" "Finished restoring VM $myVM"
      } & }
   done;
   wait
}
