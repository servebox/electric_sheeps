module ElectricSheeps
  module Resources
    module Resource
      extend ActiveSupport::Concern
      include Metadata::Options

      included do
        optionize :name
      end
    end
  end
end
