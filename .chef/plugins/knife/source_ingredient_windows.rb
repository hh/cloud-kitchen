require 'chef/knife'

module KnifePlugins
  class SourceIngredientWindows < Chef::Knife
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

    banner "knife source ingredient windows"

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

2008r2: http://technet.microsoft.com/en-us/evalcenter/dd459137.aspx
windows7: http://technet.microsoft.com/en-us/evalcenter/cc442495.aspx

The urls we download from come from those articles.
Please read them to clarify any licensing issues.
EOS
      sources = {
        win2008r2: {
          url: "http://care.dlservice.microsoft.com//dl/download/7/5/E/75EC4E54-5B02-42D6-8879-D8D3A25FBEF7/7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD.iso",
          checksum: "30832ad76ccfa4ce48ccb936edefe02079d42fb1da32201bf9e3a880c8ed6312"
        },
        win7: {
          url: "http://wb.dlservice.microsoft.com/dl/download/release/Win7/3/b/a/3bac7d87-8ad2-4b7a-87b3-def36aee35fa/7600.16385.090713-1255_x64fre_enterprise_en-us_EVAL_Eval_Enterprise-GRMCENXEVAL_EN_DVD.iso",
          checksum: "2c16c73388a5c02a0ec4cd8b9e5c14ba28b7b45d13d0c9c7d44459feecc0385f"
        }
      }
      
      
      data_bag_name = 'windows' # maybe set this via cmdline later
      artifacts = Hash.new
      sources.each do |osver,info|
        iso_url = info[:url]
        iso_filename = ::File.basename iso_url
        cached_isofile = ::File.join(
          Chef::Config[:file_cache_path],iso_filename)
        download_file(iso_url,cached_isofile)
        arch = case iso_filename
               when /x64/
                 'x86_64'
               when /./
                 'i686'
               end
        flavor = iso_filename.split('-').last.split('.').first
        semantic_ver = iso_filename.split('-')[0]
        dbi_name = "windows_#{osver.to_s[3..-1]}_#{arch}_#{semantic_ver.gsub('.','_')}"
        # New we have all the artifact details
        artifacts[dbi_name] ||= Hash.new
        artifacts[dbi_name][:source] ||= iso_url
        artifacts[dbi_name][:filename] ||= iso_filename
        artifacts[dbi_name][:arch] ||= arch
        artifacts[dbi_name][:checksum] ||= checksum(cached_isofile)
        artifacts[dbi_name][:version] ||= iso_filename[0..3]
        artifacts[dbi_name][:semantic_version] ||= semantic_ver
        artifacts[dbi_name][:os] ||= { 'windows' => [osver.to_s[3..-1]]}
        artifacts[dbi_name][:desc] ||= "Windows #{flavor} ISO"
        artifacts[dbi_name][:flavor] ||= "Windows #{flavor} ISO"
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
