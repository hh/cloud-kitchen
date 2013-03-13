require 'chef/knife'

module KnifePlugins
  class SourceIngredientVisualStudio < Chef::Knife
    include Chef::Mixin::Checksum

    deps do
      require 'chef/version_constraint'
      require 'chef/exceptions'
      require 'chef/search/query'
      require 'chef/shef/ext'
      require 'chef/mixin/checksum'
      require 'json'
      require 'open-uri'
      require 'net/https'
      require 'uri'
      require 'nokogiri'
      require 'fileutils'
    end

    banner "knife source ingredient visual studio"

    def download_file(source,destination)
      uri = URI.parse source
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        
        puts "Downloading #{source} to #{destination}"
        http.request request do |response|
          open destination, 'wb' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end if not File.exists? destination
    end


    def run
      begin
        FileUtils.touch(File.join(Chef::Config[:data_bag_path],'.writeable'))
        FileUtils.touch(File.join(Chef::Config[:file_cache_path],'.writeable'))
      rescue
        puts "Set data_bag_path and file_cache_path in knife.rb to somewhere writable"
        exit 1
      end
      puts <<-EOS
Microsoft makes many of there enterprise products available for a full featured trial:

vs2012: http://www.microsoft.com/en-us/download/details.aspx?id=30678

The urls we download from come from those articles.
Please read them to clarify any licensing issues.
EOS
      sources = {
        vs2012: {
          url: "http://download.microsoft.com/download/D/B/0/DB03922C-FF91-4845-B7F2-FC68595AB730/VS2012_ULT_enu.iso",
          checksum: "df57225332c820f3fae2ea13cb710afca04f1b79566c85f714628268a3d52bdb",
          ver: "2012"
        }
      }
      
      
      data_bag_name = 'visual_studio' # maybe set this via cmdline later
      artifacts = Hash.new
      sources.each do |osver,info|
        iso_url = info[:url]
        iso_filename = ::File.basename iso_url
        cached_isofile = ::File.join(
          Chef::Config[:file_cache_path],iso_filename)
        download_file(iso_url,cached_isofile)
        arch = 
        ver = info[:ver]
        semantic_ver = '0.0.' + ver
        dbi_name = "visual_studio_#{arch}_#{semantic_ver.gsub('.','_')}"
        # New we have all the artifact details
        artifacts[dbi_name] ||= Hash.new
        artifacts[dbi_name][:source] ||= iso_url
        artifacts[dbi_name][:filename] ||= iso_filename
        artifacts[dbi_name][:arch] ||= 'x86_64'
        artifacts[dbi_name][:checksum] ||= checksum(cached_isofile)
        artifacts[dbi_name][:version] ||= iso_filename[0..3]
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= { 'windows' => ['7','2008r2','2012','8']}
        artifacts[dbi_name][:desc] ||= "Visual Studio #{ver} ISO"
      end

      #puts JSON.pretty_generate(artifacts)
      # Write out all data bag json
      data_bag_item_dir = ::File.join(Chef::Config[:data_bag_path],data_bag_name)
      Dir.mkdir data_bag_item_dir  unless File.exists? data_bag_item_dir
      artifacts.each do |dbi,data|
        open(::File.join(data_bag_item_dir,dbi+'.json'),'w') do |f|
            f.write JSON.pretty_generate({id: dbi}.merge(data))
            f.close
        end
      end
    end
  end
end
