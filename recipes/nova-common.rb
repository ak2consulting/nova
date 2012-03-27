#
# Cookbook Name:: memcache
# Recipe:: default
#
# Copyright 2009, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "osops-utils"

volume_info = {
  "iet" => {
    "volume_driver" => "nova.volume.driver.ISCSIDriver",
    "volume_group" => node[:volume][:iscsi_volume_group],
    "iscsi_helper" => node[:volume][:iscsi_helper]
  },
  "rbd" => {
    "volume_driver" => "nova.volume.driver.RBDDriver",
    "rbd_pool" => node[:volume][:rbd_pool]
  }
}

# Distribution specific settings go here
if platform?(%w{fedora})
  # Fedora
  nova_common_package = "openstack-nova"
  nova_common_package_options = ""
  include_recipe "selinux::disabled"
else
  # All Others (right now Debian and Ubuntu)
  nova_common_package = "nova-common"
  nova_common_package_options = "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef' --force-yes"
end

package nova_common_package do
  action :upgrade
  options nova_common_package_options
end

api_ip_address = IPManagement.get_ip_for_net("management", node)
if not node.run_list.expand(node[:environment]).recipes.include?("nova::api") then
  api_ip_address = IPManagement.get_access_ip_for_role("nova-api", "management", node)
end

template "/etc/nova/nova.conf" do
  source "nova.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
            :user => node[:nova][:db_user],
            :passwd => node[:nova][:db_passwd],
            :db_name => node[:nova][:db],
            :api_port => node[:glance][:api_port],
            :ipv4_cidr => node[:public][:ipv4_cidr],
            :virt_type => node[:virt_type],
            :keystone_ip_address => IPManagement.get_access_ip_for_role("keystone", "management", node),
            :api_ip_address => api_ip_address,
            :rabbit_ip_address => IPManagement.get_access_ip_for_role("nova-controller", "management", node),
            :vncproxy_ip_address => IPManagement.get_access_ip_for_role("nova-controller", "management", node),
            :glance_ip_address => IPManagement.get_access_ip_for_role("glance", "management", node),
            :mysql_ip_address => IPManagement.get_access_ip_for_role("mysql-master", "management", node),
            :volume_options => volume_info[node[:volume][:driver]]
            )
end

template "/root/.novarc" do
  source "novarc.erb"
  owner "root"
  group "root"
  mode "0600"
  variables(
    :user => 'admin',
    :tenant => 'openstack',
    :password => 'secrete',
    :nova_api_ip => IPManagement.get_access_ip_for_role("nova-api", "management", node),
    :keystone_api_ip => IPManagement.get_access_ip_for_role("keystone", "management", node),
    :keystone_service_port => node[:keystone][:service_port],
    :nova_api_version => '1.1',
    :keystone_region => 'RegionOne',
    :auth_strategy => 'keystone'
  )
end
