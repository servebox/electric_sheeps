module ElectricSheep
  module Commands
    module Compression
      class TarGz
        include ElectricSheep::Command
        include ElectricSheep::Helpers::Named

        register as: "tar_gz"

        option :delete_source

        def perform
          logger.info "Compressing #{resource.path} to #{resource.basename}.tar.gz"
          archive = with_named_file work_dir, "#{resource.basename}.tar.gz" do |file|
            shell.exec "tar -cvzf \"#{file}\" \"#{resource.path}\" &> /dev/null"
          end
          done! shell.file_resource(path: archive)
        end

      end
    end
  end
end
