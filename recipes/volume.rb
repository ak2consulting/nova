#
# Cookbook nova:volume
# Recipe:: default
#

include_recipe "nova::nova-common"
include_recipe "osops-utils"

# Distribution specific settings go here
if platform?(%w{fedora})
  # Fedora
  nova_volume_package = "openstack-nova"
  nova_volume_service = "openstack-nova-volume"
  nova_volume_package_options = ""
else
  # All Others (right now Debian and Ubuntu)
  nova_volume_package = "nova-volume"
  nova_volume_service = nova_volume_package
  nova_volume_package_options = "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef' --force-yes"
end

package "python-keystone" do
  action :upgrade
end

package nova_volume_package do
  action :upgrade
  options nova_volume_package_options
end

service nova_volume_service do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources(:template => "/etc/nova/nova.conf"), :delayed
end

# Register Volume Service
keystone_register "Register Volume Service" do
  auth_host IPManagement.get_access_ip_for_role("keystone", "management", node)
  auth_port node[:keystone][:admin_port]
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token node[:keystone][:admin_token]
  service_name "volume"
  service_type "volume"
  service_description "Nova Volume Service"
  action :create_service
end

node[:volume][:adminURL] = "http://#{IPManagement.get_access_ip_for_role("nova-volume","management", node)}:#{node[:volume][:api_port]}/v1/%(tenant_id)s"
node[:volume][:internalURL] = node[:volume][:adminURL]
node[:volume][:publicURL] = node[:volume][:adminURL]

# Register Image Endpoint
keystone_register "Register Volume Endpoint" do
  auth_host IPManagement.get_access_ip_for_role("keystone", "management", node)
  auth_port node[:keystone][:admin_port]
  auth_protocol "http"
  api_ver "/v2.0"
  auth_token node[:keystone][:admin_token]
  service_type "volume"
  endpoint_region "RegionOne"
  endpoint_adminurl node[:volume][:adminURL]
  endpoint_internalurl node[:volume][:internalURL]
  endpoint_publicurl node[:volume][:publicURL]
  action :create_endpoint
end
