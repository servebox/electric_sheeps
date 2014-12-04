require 'fog'

module ElectricSheep
  module Transports
    class S3
      include Transport

      register as: "s3"

      option :access_key_id, required: true
      option :secret_key, required: true
      option :region

      def remote_interactor
        @remote_interactor ||= S3Interactor.new(
          option(:access_key_id), option(:secret_key), option(:region)
        )
      end

      def remote_resource
        with_directory do |bucket, prefix|
          Resources::S3Object.new({
            bucket: bucket,
            parent: prefix,
            basename: input.basename,
            extension: input.extension
          }).tap do |resource|
            resource.timestamp!(input)
          end
        end
      end

      protected

      def with_directory(&block)
        paths=option(:to).split('/')
        bucket = paths.shift
        yield bucket, paths.length > 0 ? paths.join('/') : nil
      end

      class S3Interactor

        def initialize(access_key_id, secret_key, region)
          @access_key_id = access_key_id
          @secret_key = secret_key
          @region = region || 'us-east-1'
        end

        def in_session(&block)
          # S3 is stateless
          yield
        end

        def download!(from, to, local)
          path = local.expand_path(to.path)
          # TODO Handle large files ?
          File.open(path, "w") do |f|
            file = remote_file(from) do |chunk, remaining, total|
              f.write(chunk)
            end
          end
        end

        def upload!(from, to, local)
          source=File.new( local.expand_path(from.path) )
          remote_files(to).create(
            {
              key: to.path,
              body: source
            }.merge(upload_options(source))
          )
        end

        def delete!(resource)
          remote_file(resource).destroy
        end

        def stat(resource)
          file=remote_files(resource).get(key(resource))
          file.content_length
        end

        private
        def connection
          Fog::Storage.new conn_options
        end

        def conn_options
          # TODO Move somewhere else ?
          if ENV['ELECTRIC_SHEEP_ENV']=='test'
            {
              provider: 'local',
              local_root: File.basename(Dir.pwd) == 'tmp' ? './s3' : './tmp/s3',
              endpoint: 'http://s3.amazonaws.com'
            }
          else
            {
              provider: 'AWS',
              aws_access_key_id: @access_key_id,
              aws_secret_access_key: @secret_key,
              region: @region
            }
          end
        end

        def remote_directory(bucket)
          connection.directories.get(bucket)
        end

        def remote_files(resource)
          remote_directory(resource.bucket).files
        end

        def remote_file(resource, &block)
          remote_files(resource).get(key(resource), &block)
        end

        def key(resource)
          resource.path
        end

        def upload_options(file)
          {}.tap do |opts|
            if file.size > 10.megabytes
              # Try to use small chunks to reduce memory consumption
              chunk=[5, 10, 20, 30, 40, 50, 100, 200, 300, 500].find do |size|
                # S3 hard-limit: 10000 chunks
                size.megabytes * 10000 >= file.size
              end
              opts[:multipart_chunk_size]=chunk.megabytes
            end
          end
        end

      end

    end
  end
end
