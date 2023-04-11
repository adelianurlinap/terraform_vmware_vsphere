locals {
# Alternative value for disks, an empty list
  disks = []
# Alternative value for disk_format_args, an empty string
  disk_format_args = ""
}

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datasource
  datacenter_id = data.vsphere_datacenter.dc.id
}
# unfortunately, providering datastore cluster name to vm resource is not possible
#data "vsphere_datastore_cluster" "datastore_cluster" {
#  name          = var.vsphere_datasource
#  datacenter_id = data.vsphere_datacenter.dc.id
#}

#
# resource_pool_id can either come from cluster or from esxi host
#
data "vsphere_compute_cluster" "cluster" {
  count         = var.vsphere_cluster=="" ? 0:1
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_host" "esxihost" {
  count         = var.vsphere_cluster=="" ? 1:0
  # name not needed if there is only 1 esxi host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_template
  datacenter_id = data.vsphere_datacenter.dc.id
}


resource "vsphere_virtual_machine" "vm" {
  name             = var.jumphost_name

  # resource pool id comes from cluster or esxi host
  resource_pool_id = var.vsphere_cluster=="" ? data.vsphere_host.esxihost[0].resource_pool_id:data.vsphere_compute_cluster.cluster[0].resource_pool_id

  # unfortunately providing datastore cluster is not possible, must use specific store
  #datastore_id     = data.vsphere_datastore_cluster
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.jumphost_vm_folder

  # can use these if vmtools agent will not respond with client IP and fails
  #wait_for_guest_net_routable = false
  #wait_for_guest_net_timeout = 0
  #wait_for_guest_ip_timeout = 3

  num_cpus = var.jumphost_cpu
  memory   = var.jumphost_ram_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
     label            = "disk0"
     unit_number      = 0
     #size             = var.jumphost_disk_gb # can expand template disk, but will need parted
     size             = data.vsphere_virtual_machine.template.disks.0.size
     eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
     thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  cdrom { 
    client_device = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.jumphost_name
        domain    = var.jumphost_domain
      }

      network_interface {
        ipv4_address = var.jumphost_ip
        ipv4_netmask = var.jumphost_subnet
      }

      ipv4_gateway = var.jumphost_gateway
      dns_server_list = var.dns_server_list
      dns_suffix_list = var.dns_suffix_list
    }
  }

  connection {
    type = "ssh"
    agent = "false"
    host = var.jumphost_ip
    user = var.jumphost_user
    password = var.jumphost_password
  }
}
