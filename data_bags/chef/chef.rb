require 'json'
require 'open-uri'
require 'chef/version_constraint'
require 'chef/mixin/checksum'
require 'chef/exceptions'
require 'net/https'
require 'uri'

chef_client_json_url = 'http://www.opscode.com/chef/full_list'
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
        dotted_ver=chef_ver.split('-').first.split('.')
        next if dotted_ver[3] =~ /alpha/
        semantic_ver = dotted_ver[0..2].join('.')
        filename=File.basename(chef_url)
        if semantic_ver.start_with? '11'
          next if not Chef::VersionConstraint.new(">= 11.4.0").include? semantic_ver
        else
          next if not Chef::VersionConstraint.new(">= 10.24.0").include? semantic_ver
        end
        # I'm not interested in 32bit or sparc
        next if ['i686','i386','sparc'].include? arch
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
        #next if chef_ver !~ /(^11\.4)(^10\.24)/
        #fX from filename/
        (fos,fosver,farch) = chef_url.split('/')[1..3]
        chef_dbver = chef_ver.gsub(/(\.|-)/,'_') 
        os_dbver = fosver.gsub(/(\.|-)/,'_') 
        # case source
        # when /windows/
        #   "windows_#{chef_dbver}"
        # when %r{
        #          (?<file_chef_ver> [\d+\.-]+ ){0}
        #          (?<file_os> \w+ ){0}
        #          (?<file_os_ver> [\d.]+ ){0}
        #          (?<file_arch> \w+ ){0}
        #          \g<file_chef_ver>\.\g<file_os>\.\g<file_os_ver>_\g<file_arch>\.deb
        #        }x

        #   #r.match('chef_10.24.0-1.debian.6.0.5_amd64.deb')
        #   # => #<MatchData "10.24.0-1.debian.6.0.5_amd64.deb"
        #   # file_chef_ver:"10.24.0-1" file_os:"debian" file_os_ver:"6.0.5" file_arch:"amd64">
        #   "#{file_os}_#{file_os_ver.gsub(/(\.|-)/,'_')}_#{chef_dbver}"
        # when /rpm$/
        #   "#{os}_#{os_dbver}_#{chef_dbver}"
        # when /mac_os/
        # else
        # end
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
artifacts.each do |dbi,data|
  open(dbi+'.json','w') do |f|
    f.write JSON.pretty_generate({id: dbi}.merge(data))
    f.close
  end
end
# require 'pp'
# pp artifacts.keys


# j.map {|k,v| puts "#{k}: #{v.keys.join ', '} #{v.keys.map{|kk|v[kk].keys}.flatten.uniq}"} 
# debian: 6 ["x86_64", "i686"]
# el: 5, 6 ["x86_64", "i686"]
# mac_os_x: 10.6, 10.7 ["x86_64"]
# ubuntu: 10.04, 10.10, 11.04, 11.10, 12.04, 12.10 ["x86_64", "i686"]
# solaris2: 5.9, 5.11, 5.10 ["sparc", "i386"]
# sles: 11.2 ["x86_64", "i686"]
# suse: 12.1 ["x86_64", "i686"]
# windows: 2008, 2003r2, 2008r2, 2012 ["i686", "x86_64"]

# j.map {|k,v| v.keys.map{|kk|v[kk].values[0].keys}}.flatten.uniq.sort
# => ["10.12.0-1", "10.14.0-1", "10.14.0.rc.0-1", "10.14.0.rc.1-1", "10.14.2-1", "10.14.4-1", "10.14.4-2", "10.16.0-1", "10.16.0.rc.0-1", "10.16.0.rc.1-1", "10.16.2-1", "10.16.2-49-g21353f0-1", "10.16.4-1", "10.16.4-2", "10.16.6-1", "10.18.0-1", "10.18.0.rc.2-1", "10.18.2-1", "10.18.2-2", "10.20.0-1", "10.22.0-1", "10.24.0-1", "11.0.0-1", "11.0.0.beta.1-1", "11.0.0.beta.2-1", "11.0.0.rc.0-1", "11.2.0-1", "11.4.0-1"]
