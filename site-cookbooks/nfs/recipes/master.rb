# Install NFS packages
package("nfs-common")
package("nfs-kernel-server")

# Make sure the directory to be exported exists
node.nfs['shared_dirs'].each do |exports|
 exports.each_pair do |d, dir|
    directory d do
        mode "0777"
        if !Dir.exists?("#{d}")
        action :create
        end
    end
## Create symlink on server for client mount point
    if !File.symlink?("#{dir}")
      File.symlink(d, dir)
    end
 end
end

# Create the exports file and refresh the NFS exports
template "/etc/exports" do
    source "exports.erb"
    owner "root"
    group "root"
    mode "0644"
end

# Start the NFS server
service "nfs-kernel-server" do
    action [:enable,:start,:restart]
end

execute "exportfs" do
    command "exportfs -a"
    action :run
end
