require 'chef/knife'

module KnifePlugins
  class Lab < Chef::Knife
    deps do
      require 'chef/search/query'
      require 'chef/shef/ext'
    end

    banner "knife lab"

    def run
      Shef::Extensions.extend_context_object(self)
      workstations = search(:node, "ohai_time:* AND role:workstation")
      targets = search(:node, "ohai_time:* AND role:target")
      ui.output "https://opscode-chef-training.s3.amazonaws.com/ChefWorkshop-CheatSheet.pdf"
      ui.output "\n# Workstations (SSH or VNC display :1)"
      workstations.each_with_index do |n,i|
        ui.output "#{n['cloud']['public_ipv4']} opstrain#{i+1} # workstation"
      end
      ui.output "\n# Target nodes (SSH)"
      targets.each_with_index do |n,i|
        ui.output "#{n['cloud']['public_ipv4']} opstrain#{i+1} # target node"
      end
    end
  end
end
