require 'yaml'
require 'uri'

Dir.chdir(File.expand_path('..', __dir__))

release = /\Av?\d+\.\d+\.\d+\z/
Dir.glob('{.github/workflows,scripts/resources,ci/resources}/**/*.{yml,yaml}').each do |path|
  YAML.load_stream(File.read(path)).each do |document|
    next unless document.is_a?(Hash) && path.start_with?('scripts/resources/')

    case document['kind']
    when 'Application'
      source = document.dig('spec', 'source') || {}
      if source.key?('chart') && !release.match?(source['targetRevision'].to_s)
        abort "#{path}: chart targetRevision must pin a release"
      end
      if source['path'].to_s.start_with?('scripts/resources/ci/')
        manifest = File.join(source['path'], 'kustomization.yaml')
        abort "Missing pinned resource file: #{manifest}" unless File.file?(manifest)
      end
    when 'Kustomization'
      document.fetch('resources', []).grep(/\A\w+:\/\//).each do |resource|
        url = URI.parse(resource)
        segments = url.path.split('/').reject(&:empty?)
        version = if url.host == 'github.com' && segments[2, 2] == ['releases', 'download']
                    segments[4]
                  elsif url.host == 'raw.githubusercontent.com'
                    segments[2]
                  end
        unless url.scheme == 'https' && release.match?(version.to_s)
          abort "#{path}: resource must pin an HTTPS release URL: #{resource}"
        end
      end
    when 'Cluster'
      next unless document['apiVersion'] == 'kind.x-k8s.io/v1alpha4'

      nodes = document.fetch('nodes')
      unless !nodes.empty? && nodes.all? { |node| /\Akindest\/node:v\d+\.\d+\.\d+\z/.match?(node['image'].to_s) }
        abort "#{path}: every kind node must pin a release image"
      end
    end
  end
end