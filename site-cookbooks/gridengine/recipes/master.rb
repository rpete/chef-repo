#
# Load gridengine packages
#
#right now only Debian Ubuntu
case node['platform_family']

when "debian"
 if node['platform_version'].to_f  == 12.04
  node['gridengine']['packages'] = %w{ gridengine-common gridengine-client gridengine-master gridengine-exec libdrmaa1.0 software-properties-common g++ make python }
 else
  node['gridengine']['packages'] = %w{ gridengine-common gridengine-client gridengine-master gridengine-exec gridengine-drmaa1.0 software-properties-common g++ make python }
 end
end

node['gridengine']['packages'].each do |sgepkg|
  package sgepkg
end
#
# This host as to be defined as an execution host before it can
# be added to a hostgroup
#
template "#{Chef::Config[:file_cache_path]}/exechost" do
  source "exechost.erb"
  variables({
    :host => node[:fqdn]
  })
end

template "#{Chef::Config[:file_cache_path]}/hostgroup" do
  source "hostgroup.erb"
  variables({
    :hostgroup  => node[:gridengine][:hostgroup],
    :hosts      => node[:fqdn]
  })
end

template "#{Chef::Config[:file_cache_path]}/execqueue" do
  source "execqueue.erb"
  variables({
    :queue      => node[:gridengine][:execqueue],
    :hostgroup  => node[:gridengine][:hostgroup],
    :nslots     => node[:cpu][:total]
  })
end

template "#{Chef::Config[:file_cache_path]}/execuser" do
  source "execuser.erb"
  variables({
    :user => node[:gridengine][:execuser]
  })
end

template "#{Chef::Config[:file_cache_path]}/smp_pe" do
  source "smp_pe.erb"
end

template "#{Chef::Config[:file_cache_path]}/global" do
  source "global.erb"
end

template "#{Chef::Config[:file_cache_path]}/ssl.cnf" do
  source "cert.erb"
  variables({
    :host => node[:fqdn]
  })
end

template "/usr/local/sbin/sge_listener" do
   source "sge_listener.erb"
   variables({
     :token_key  => node['gridengine']['token_key']
   })
end


bash "doconfig" do
  flags '-x'
  code <<-EOC
    echo "begin bash doconfig"

    qconf -se "#{node[:fqdn]}" > /dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]
    then
      qconf -Me "#{Chef::Config[:file_cache_path]}/exechost" 
    else
      qconf -Ae "#{Chef::Config[:file_cache_path]}/exechost" 
    fi

    qconf -shgrp "#{node[:gridengine][:hostgroup]}" > /dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]
    then
      qconf -Mhgrp "#{Chef::Config[:file_cache_path]}/hostgroup"
    else
      qconf -Ahgrp "#{Chef::Config[:file_cache_path]}/hostgroup"
    fi

    qconf -sp smp_pe > /dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]
    then
      qconf -Mp "#{Chef::Config[:file_cache_path]}/smp_pe"
    else
      qconf -Ap "#{Chef::Config[:file_cache_path]}/smp_pe"
    fi

    qconf -sq "#{node[:gridengine][:execqueue]}"
    rc=$?
    if [ $rc -eq 0 ]
    then
      echo qconf -Mq "#{Chef::Config[:file_cache_path]}/execqueue"
      qconf -Mq "#{Chef::Config[:file_cache_path]}/execqueue"
    else
      echo qconf -Aq "#{Chef::Config[:file_cache_path]}/execqueue"
      qconf -Aq "#{Chef::Config[:file_cache_path]}/execqueue"
    fi

    qconf -suser "#{node[:gridengine][:execuser]}" | grep name > /dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]
    then
      qconf -Muser "#{Chef::Config[:file_cache_path]}/execuser"
    else
      qconf -Auser "#{Chef::Config[:file_cache_path]}/execuser"
    fi

    qconf -sconf global > /dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]
    then
      qconf -Mconf "#{Chef::Config[:file_cache_path]}/global"
    else
      qconf -Aconf "#{Chef::Config[:file_cache_path]}/global"
    fi

    qconf -as "#{node[:fqdn]}" 
    echo "end bash doconfig"
  EOC
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

file "/usr/share/gridengine/default/common/act_qmaster" do
  owner "root"
  group "root"
  mode  "0644"
  action :create
  content "#{node[:fqdn]}"
end

#
#Disable the master as being an execution host
#
bash "noexechost" do
  only_if {"#{node['gridengine']['noexec_master']}" == 'true'}
  code <<-EOC
    qmod -d \*@"#{node[:fqdn]}"
  EOC
end

#
# Queue apparently expects libdrmaa to be in non-versioned dynamic library, but 
# this is not how the package installs
#
bash "lndrmaa" do
  not_if {File.symlink?('/usr/lib/libdrmaa.so')}
  code <<-EOC
    ln -s /usr/lib/libdrmaa.so.1.0 /usr/lib/libdrmaa.so
  EOC
end

bash "lnbootstrap" do
  not_if {File.symlink?('/usr/share/gridengine/default/common/bootstrap')}
  code <<-EOC
    ln -s /usr/share/gridengine/default-bootstrap /usr/share/gridengine/default/common/bootstrap
  EOC
end

bash "start_node.js" do
  code <<-EOC
   apt-get -y install python-software-properties
   cd /tmp
   curl http://nodejs.org/dist/node-latest.tar.gz | tar xz --strip-components=1
   ./configure
   make install
   rm -Rf *
   curl https://npmjs.org/install.sh | sh
   npm install http-server
   npm install querystring
   openssl genrsa -out /root/masternode.key 2048
   openssl req -new -x509 -config #{Chef::Config[:file_cache_path]}/ssl.cnf -key /root/masternode.key -out /root/masternode.crt
   node /usr/local/sbin/sge_listener &
  EOC
end
