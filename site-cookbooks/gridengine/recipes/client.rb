#
# Load gridengine packages
#
#right now only Debian Ubuntu
case node['platform_family']

when "debian"
 if node['platform_version'].to_f == 12.04
  node['gridengine']['packages'] = %w{ gridengine-common gridengine-client gridengine-exec libdrmaa1.0 }
 else
  node['gridengine']['packages'] = %w{ gridengine-common gridengine-client gridengine-exec gridengine-drmaa1.0 }
 end
end

node['gridengine']['packages'].each do |sgepkg|
  package sgepkg
end

#
# libdrmaa expects bootstrap and act_qmaster to live in $SGE_HOME/default/common
#
directory "/usr/share/gridengine/default/common" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

bash "lndrmaa" do
  not_if {File.symlink?('/usr/lib/libdrmaa.so')}
  code <<-EOC
    ln -s /usr/lib/gridengine-drmaa/lib/libdrmaa.so.1 /usr/lib/libdrmaa.so
  EOC
end

bash "lnbootstrap" do
    not_if {File.symlink?('/usr/share/gridengine/default/common/bootstrap')}
    code <<-EOC
    ln -s /usr/share/gridengine/default-bootstrap /usr/share/gridengine/default/common/bootstrap
  EOC
end


#
# This host as to be defined as an execution host before it can
# be added to a hostgroup
#
bash "dokey" do
  code <<-EOC
      ssh-keygen -t rsa -N "" -f /root/.ssh/sge_rsa
      PKEY=$(cat /root/.ssh/sge_rsa.pub)
      curl -k -d "key=#{node['gridengine']['token_key']}" --data-urlencode "input=$PKEY" https://#{node['gridengine']['master']}:10111/pushthekey
  EOC

end

bash "doconfig" do
  
  only_if {File.exists?('/root/.ssh/sge_rsa')}
  code <<-EOC
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/sge_rsa #{node['gridengine']['master']}:/var/lib/gridengine/default/common/act_qmaster /var/lib/gridengine/default/common/
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/sge_rsa  #{node['gridengine']['master']} qconf -ah "#{node[:fqdn]}" > /dev/null 2>&1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/sge_rsa  #{node['gridengine']['master']} qconf -as "#{node[:fqdn]}" > /dev/null 2>&1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/sge_rsa  #{node['gridengine']['master']}  qconf -mattr hostgroup hostlist #{node[:fqdn]} #{node[:gridengine][:hostgroup]} > /dev/null 2>&1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/sge_rsa #{node['gridengine']['master']} qconf -aattr queue slots "[#{node[:fqdn]}=#{node[:cpu][:total]}]" #{node[:gridengine][:execqueue]} > /dev/null 2>&1 

  EOC
end

service "gridengine-exec start" do
  service_name "gridengine-exec"
  action :start
end

