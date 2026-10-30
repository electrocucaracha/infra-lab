require 'fileutils'
require 'minitest/autorun'
require 'open3'
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
end