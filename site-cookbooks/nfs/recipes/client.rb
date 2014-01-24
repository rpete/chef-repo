package("nfs-common")

# Make sure the diretory to be exported exists
node.nfs['shared_dirs'].each do |exports|
  exports.each_pair do |d,dir|
    if dir != nil
     directory dir do
        mode "0777"
        action :create
     end
    end
 end
end

file "/etc/fstab" do

    sourceip = node.nfs['headnode_addr']
    dirs = node.nfs['shared_dirs']

    # Generate the new fstab lines
    new_lines = ""
    dirs.each do |exports|
    exports.each_pair do |d,da|
      if da != nil
        new_lines = new_lines + "#{sourceip}:#{d}  #{da}  nfs4  rw,soft,lookupcache=none 0 0\n"
      else
        new_lines = new_lines + "#{sourceip}:#{d}  #{d}  nfs4  rw,soft,lookupcache=none 0 0\n"
      end
     end
    end
    print "*** Mount line: #{new_lines}\n"

    # Get current content, check for duplication
    only_if do
        current_content = File.read('/etc/fstab')
        current_content.index(new_lines).nil?
    end

    print "*** Passed the conditional for current content\n"

    # Set up the file and content
    owner "root"
    group "root"
    mode  "0644"
    current_content = File.read('/etc/fstab')
    new_content = current_content + new_lines
    content new_content

end

execute "mount" do
    command "mount -a"
    action :run
end
