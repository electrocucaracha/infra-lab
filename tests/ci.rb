require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'shellwords'
require 'tmpdir'
require 'yaml'

class CiInfrastructureTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  APPS = %w[topolvm kubevirt cdi tekton kubevirt-tekton-tasks arc].freeze

  def manifest(path)
    YAML.load_file(File.join(ROOT, path))
  end

  def test_only_ci_platform_applications_are_declared
    applications = Dir[File.join(ROOT, 'scripts/resources/in-cluster/*.yaml')].map do |path|
      YAML.load_file(path)
    end
    assert_equal (APPS + ['kubean']).sort, applications.map { |app| app.dig('metadata', 'name') }.sort
    applications.reject { |app| app.dig('metadata', 'name') == 'kubean' }.each do |app|
      assert_equal 'infra-lab', app.dig('spec', 'destination', 'name')
      assert_equal true, app.dig('spec', 'syncPolicy', 'automated', 'selfHeal')
    end
    parent = manifest('scripts/resources/bootstrap.yaml')
    assert_equal 'scripts/resources/in-cluster', parent.dig('spec', 'source', 'path')
  end

  def test_inventory_contains_each_nodes_roles
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'scripts/resources/overcloud'))
      FileUtils.cp_r(File.join(ROOT, 'config'), directory)
      FileUtils.cp(File.join(ROOT, 'distros_supported.yml'), directory)
      source = File.read(File.join(ROOT, 'Vagrantfile')).split("unless File.exist?", 2).first
      Object.new.instance_eval(source, File.join(directory, 'Vagrantfile'))
      configmap = YAML.load_file(File.join(directory, 'scripts/resources/overcloud/hosts.yaml'))
      inventory = YAML.safe_load(configmap.dig('data', 'hosts.yml'))
      nodes = manifest('config/default.yml')
      assert_equal nodes.map { |node| node['name'] }.sort, inventory.dig('all', 'hosts').keys.sort
      %w[kube_control_plane kube_node etcd].each do |role|
        expected = nodes.select { |node| node['roles'].include?(role) }.map { |node| node['name'] }
        assert_equal expected.sort, inventory.dig('all', 'children', role, 'hosts').keys.sort
      end
    end
  end

  def test_workers_supply_topolvm_storage_without_lab_hardware
    values = manifest('scripts/resources/in-cluster/topolvm.yaml').dig('spec', 'source', 'helm', 'valuesObject')
    volume_group = values.dig('lvmd', 'deviceClasses', 0, 'volume-group')
    manifest('config/default.yml').each do |node|
      assert_empty node.keys & %w[pmem qat_dev sriov_dev sriov_numvfs numa_nodes]
      next unless node['roles'].include?('kube_node')

      assert node.fetch('volumes').any? { |volume| volume['volume_group'] == volume_group }
    end
    storage = values.dig('storageClasses', 0, 'storageClass')
    assert_equal 'WaitForFirstConsumer', storage['volumeBindingMode']
    assert_equal true, storage['allowVolumeExpansion']
    kubevirt = manifest('scripts/resources/in-cluster/kubevirt.yaml').dig('spec', 'source', 'helm', 'valuesObject', 'kubevirt', 'configuration')
    assert_includes kubevirt.dig('developerConfiguration', 'featureGates'), 'EnableVirtioFsConfigVolumes'
    assert_equal true, kubevirt.dig('network', 'permitBridgeInterfaceOnPodNetwork')
  end

  def test_kuttl_cases_cover_each_component
    test_cases = Dir[File.join(ROOT, 'ci/kuttl/tests/*')].to_h do |directory|
      component = File.basename(directory)
      test_case = YAML.load_file(File.join(directory, '00-test-case.yaml'))
      assert_equal component, test_case.dig('testRunSelector', 'matchLabels', 'component')
      assert File.file?(File.join(directory, '00-assert.yaml'))
      [component, test_case]
    end
    assert_equal APPS.sort, test_cases.keys.sort
  end

  def test_kuttl_smoke_resources_and_timeouts
    resources = YAML.load_stream(File.read(File.join(ROOT, 'ci/kuttl/tests/topolvm/00-smoke.yaml')))
    assert_equal %w[PersistentVolumeClaim Pod], resources.map { |resource| resource['kind'] }
    assert_equal 'storage-smoke', resources.last.dig('spec', 'volumes', 0, 'persistentVolumeClaim', 'claimName')
    assert_equal 'Never', resources.last.dig('spec', 'restartPolicy')
    assert_includes resources.last.dig('spec', 'containers', 0, 'command').last, 'test "$(cat /data/check)" = infra-lab'
    %w[00 01].each do |step|
      documents = YAML.load_stream(File.read(File.join(ROOT, "ci/kuttl/tests/topolvm/#{step}-assert.yaml")))
      assert_equal 300, documents.first['timeout']
      assert_equal(step == '00' ? 'Bound' : 'Succeeded', documents.last.dig('status', 'phase'))
    end
  end

  def test_kuttl_arc_checks_every_rollout_and_propagates_failures
    command = manifest('ci/kuttl/tests/arc/00-smoke.yaml').fetch('commands').first
    assert_equal(-1, command['timeout'])
    %w[success empty list-failure rollout-failure].each do |scenario|
      script = <<~BASH
        function kubectl {
          if [[ "$*" == "-n arc-system get deployments -o name" ]]; then
            case "#{scenario}" in
              empty) return 0 ;;
              list-failure) return 1 ;;
              *) printf 'deployment.apps/first\\ndeployment.apps/second\\n' ;;
            esac
          else
            printf '%s\\n' "$*"
            [[ "#{scenario}" != rollout-failure || "$*" != *second* ]]
          fi
        }
        export -f kubectl
        bash -c #{Shellwords.escape(command.fetch('script'))}
      BASH
      output, errors, result = Open3.capture3('bash', '-c', script)
      if scenario == 'success'
        assert result.success?, errors
        assert_equal [
          '-n arc-system rollout status deployment.apps/first --timeout=5m',
          '-n arc-system rollout status deployment.apps/second --timeout=5m'
        ], output.lines.map(&:strip)
      else
        refute result.success?, scenario
      end
    end
  end

  def test_bootstrap_orders_dependencies_without_running_provisioning
    script = <<~BASH
      export __name__=ci_check DEBUG=false
      source ./configure.sh
      function kubectl { printf 'kubectl %s\\n' "$*"; }
      function argocd { printf 'argocd %s\\n' "$*"; }
      _deploy_infra_apps
    BASH
    output, errors, result = Open3.capture3('bash', '-c', script, chdir: File.join(ROOT, 'scripts'))
    assert result.success?, errors
    assert_equal APPS, output.scan(/^argocd app sync (.+)$/).flatten
    assert_operator output.index('kubevirt/kubevirt'), :<, output.index('argocd app sync cdi')
    assert_operator output.index('cdi/cdi'), :<, output.index('argocd app sync tekton')
    assert_operator output.index('tektonconfig/config'), :<, output.index('argocd app sync kubevirt-tekton-tasks')
    refute_includes output, 'argocd app set'
  end

  def test_version_updater_bootstraps_uv_and_propagates_installation_failures
    %w[installed missing download-failure install-failure].each do |scenario|
      Dir.mktmpdir do |directory|
        bin = File.join(directory, 'bin')
        stubs = File.join(directory, 'stubs')
        home = File.join(directory, 'home with spaces')
        install_dir = File.join(home, '.local/bin')
        FileUtils.mkdir_p([bin, stubs, install_dir, File.join(directory, 'ci')])
        FileUtils.cp(File.join(ROOT, 'ci/update_versions.py'), File.join(directory, 'ci'))
        %w[ci/tekton ci/cdi ci/kubevirt-tekton-tasks management/argocd].each do |path|
          target = File.join(directory, 'scripts/resources', path, 'kustomization.yaml')
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.touch(target)
        end
        FileUtils.touch(File.join(directory, 'scripts/resources/management/kind.yaml'))
        { 'sh' => '/bin/sh', 'cp' => '/bin/cp', 'env' => '/usr/bin/env' }.each do |name, source|
          FileUtils.ln_s(source, File.join(bin, name))
        end
        %w[uv uvx].each do |tool|
          path = File.join(stubs, tool)
          File.write(path, "#!/bin/sh\nprintf '#{tool} %s\\n' \"$*\"\n")
          FileUtils.chmod(0o755, path)
          FileUtils.cp(path, bin) if scenario == 'installed'
        end
        installer = if scenario == 'install-failure'
                      'exit 1'
                    else
                      'cp "$STUBS/uv" "$STUBS/uvx" "$UV_INSTALL_DIR/"'
                    end
        curl = <<~BASH
          #!/bin/bash
          printf 'curl %s\\n' "$*" >&2
          [[ #{Shellwords.escape(scenario)} != download-failure ]] || exit 22
          printf '%s\\n' #{Shellwords.escape(installer)}
        BASH
        File.write(File.join(bin, 'curl'), curl)
        File.write(File.join(bin, 'make'), "#!/bin/sh\nprintf 'make %s\\n' \"$*\"\n")
        FileUtils.chmod(0o755, [File.join(bin, 'curl'), File.join(bin, 'make')])
        output, errors, result = Open3.capture3(
          { 'PATH' => bin, 'HOME' => home, 'STUBS' => stubs },
          '/bin/bash', File.join(ROOT, 'ci/update_versions.sh'), chdir: directory
        )
        if scenario.end_with?('failure')
          refute result.success?, scenario
          refute_includes output, 'uv '
          refute_includes output, 'uvx '
        else
          assert result.success?, errors
          assert_equal [
            'uv --quiet run --script ./ci/update_versions.py',
            'uvx pre-commit autoupdate',
            'uv run --no-project --with git+https://github.com/electrocucaracha/gh-updater.git gh-updater .',
            'make fmt'
          ], output.lines.map(&:strip)
        end
        if scenario == 'installed'
          refute_includes errors, 'curl'
        else
          assert_includes errors, 'curl -fsSL https://astral.sh/uv/install.sh'
        end
      end
    end
  end
end