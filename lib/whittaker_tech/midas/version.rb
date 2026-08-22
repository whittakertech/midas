# rubocop:disable Style/OneClassPerFile -- .rubocop.yml enforces compact
# module style (Style/ClassAndModuleChildren: compact), which requires the
# parent module to be opened separately. The two cops are mutually exclusive
# here; compact style wins because it is the repo-wide convention.
module WhittakerTech; end

module WhittakerTech::Midas
  VERSION = '0.5.0'.freeze
end
# rubocop:enable Style/OneClassPerFile
