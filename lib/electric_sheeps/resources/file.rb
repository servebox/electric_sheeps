module ElectricSheeps
  module Resources
    class File
      include FileSystem

      def file?
        true
      end

      def directory?
        false
      end

    end
  end
end
