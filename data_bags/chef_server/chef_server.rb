require 'json'
require 'open-uri'
require 'chef/version_constraint'
require 'chef/mixin/checksum'
require 'chef/exceptions'
require 'net/https'
require 'uri'


# This generates data bags to be used by an artifact repository
# of some type power by chef

chef_client_json_url = 'http://www.opscode.com/chef/full_server_list'
base_url='https://opscode-omnitruck-release.s3.amazonaws.com'

class TheFile
  include Chef::Mixin::Checksum
end

# cross platform SSL cert stuff on ruby gives me gas
RootCA = '/etc/ssl/certs' # On ubuntu anyhow
url = URI.parse base_url
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = (url.scheme == 'https')
if (File.directory?(RootCA) && http.use_ssl?)
  http.ca_path = RootCA
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.verify_depth = 5
else
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
end

j=JSON.parse(open(chef_client_json_url).read)

artifacts = Hash.new

j.each do |os,val|
  val.each do |os_ver,val|
    val.each do |arch, val|
      val.each do |chef_ver, chef_url|
        # We could do this for all versions, but I only want newer stuff
        # We only want full release versions, not -rc,-alpha,-beta 
        next if chef_ver.include? '-'
        next if chef_ver.include? '+' #git versions?
        next if not Chef::VersionConstraint.new(">= 11.0.6").include? chef_ver
        filename=File.basename(chef_url)
        # I'm not interested in 32bit or sparc
        if not File.exists? filename
          puts "Downloading #{filename}"
          open(filename,'wb') do |f|
            req = http.request_get(chef_url)
            if req.code != '200'
              puts "Error downloading file: #{req.code} #{req.body}"
              exit 1
            end
                
            f.write(req.body)
            f.close
          end
        end
        (fos,fosver,farch) = chef_url.split('/')[1..3]
        chef_dbver = chef_ver.gsub(/(\.|-)/,'_') 
        os_dbver = fosver.gsub(/(\.|-)/,'_') 
        dbi_name = "#{fos}_#{os_dbver}_#{farch}_#{chef_dbver}"
        artifacts[dbi_name] ||= Hash.new
        artifacts[dbi_name][:source] ||= base_url + chef_url
        artifacts[dbi_name][:filename] ||= filename
        artifacts[dbi_name][:arch] ||= arch
        artifacts[dbi_name][:checksum] ||= TheFile.new.checksum(filename)
        artifacts[dbi_name][:version] ||= chef_ver
        artifacts[dbi_name][:os] ||= {os => [os_ver]}
        if not artifacts[dbi_name][:os].include? os
          artifacts[dbi_name][:os][os] = [os_ver]
        end
        if not artifacts[dbi_name][:os][os].include? os_ver
          artifacts[dbi_name][:os][os] << os_ver
        end
      end
    end
  end
end

#puts JSON.pretty_generate(artifacts)
# Write out all data bag json
artifacts.each do |dbi,data|
  open(dbi+'.json','w') do |f|
    f.write JSON.pretty_generate({id: dbi}.merge(data))
    f.close
  end
end
