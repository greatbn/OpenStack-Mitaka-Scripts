#!/bin/bash -ex
#
source config.cfg
source functions.sh

echocolor "Install Manila-share on compute node"
sleep 3

apt-get install manila-share python-pymysql -y
manila_ctl=/etc/manila/manila.conf

echocolor "Config manila-share with DHSS= TRue"

## [DEFAULT] section

ops_edit $manila_ctl DEFAULT rpc_backend rabbit
ops_edit $manila_ctl DEFAULT auth_strategy keystone
ops_edit $manila_ctl DEFAULT default_share_type default_share_type
ops_edit $manila_ctl DEFAULT rootwrap_config /etc/manila/rootwrap.conf
ops_edit $manila_ctl DEFAULT my_ip $COM1_MGNT_IP
ops_edit $manila_ctl DEFAULT enabled_share_backends generic
ops_edit $manila_ctl DEFAULT enabled_share_protocols NFS,CIFS
## [database] section
ops_edit $manila_ctl database \
connection mysql+pymysql://manila:$MANILA_DBPASS@$CTL_MGNT_IP/manila

## [oslo_messaging_rabbit] section
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_userid openstack
ops_edit $manila_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS

## [keystone_authtoken] section
ops_edit $manila_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $manila_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $manila_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $manila_ctl keystone_authtoken auth_type password
ops_edit $manila_ctl keystone_authtoken project_domain_name default
ops_edit $manila_ctl keystone_authtoken user_domain_name default
ops_edit $manila_ctl keystone_authtoken project_name service
ops_edit $manila_ctl keystone_authtoken username manila
ops_edit $manila_ctl keystone_authtoken password $MANILA_PASS

## [oslo_concurrency] section
ops_edit $manila_ctl oslo_concurrency lock_path /var/lib/manila/tmp


cat << EOF >> /etc/manila/manila.conf
[neutron]
url = http://$CTL_MGNT_IP:9696
auth_uri = http://$CTL_MGNT_IP:5000
auth_url = http://$CTL_MGNT_IP:35357
memcached_servers = $CTL_MGNT_IP:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS

[nova]
auth_uri = http://$CTL_MGNT_IP:5000
auth_url = http://$CTL_MGNT_IP:35357
memcached_servers = $CTL_MGNT_IP:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[cinder]
auth_uri = http://$CTL_MGNT_IP:5000
auth_url = http://$CTL_MGNT_IP:35357
memcached_servers = $CTL_MGNT_IP:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = cinder
password = $CINDER_PASS

[generic]
share_backend_name = GENERIC
share_driver = manila.share.drivers.generic.GenericShareDriver
driver_handles_share_servers = True
service_instance_flavor_id = 100
service_image_name = manila-service-image
service_instance_user = manila
service_instance_password = manila
#interface_driver = manila.network.linux.interface.BridgeInterfaceDriver
interface_driver = manila.network.linux.interface.OVSInterfaceDriver
EOF

service manila-share restart
