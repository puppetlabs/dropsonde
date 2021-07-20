# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'json'

describe 'dropsonde' do
  context 'when update' do
    let(:shell_result) { run_shell('dropsonde update') }

    it 'works' do
      expect(shell_result.exit_code).to eq(0)
    end
  end

  context 'when list' do
    let(:shell_result) { run_shell('dropsonde list') }

    it 'works' do
      expect(shell_result.exit_code).to eq(0)
    end

    it 'has platforms plugin in the list' do
      expect(shell_result.stdout).to match(%r{platforms\n--------})
    end

    it 'has dependencies plugin in the list' do
      expect(shell_result.stdout).to match(%r{dependencies\n--------})
    end

    it 'has puppetfiles plugin in the list' do
      expect(shell_result.stdout).to match(%r{puppetfiles\n--------})
    end

    it 'has modules plugin in the list' do
      expect(shell_result.stdout).to match(%r{modules\n--------})
    end

    it 'has environments plugin in the list' do
      expect(shell_result.stdout).to match(%r{environments\n--------})
    end
  end

  context 'when preview' do
    let(:shell_result) { run_shell('dropsonde preview --format json') }
    let(:plugins) { JSON.parse(shell_result.stdout)['self-service-analytics']['snapshots'] }

    it 'works' do
      expect(shell_result.exit_code).to eq(0)
    end

    it 'has not include private dependencies' do
      dependencies = plugins['dependencies']['value'].map { |dep| dep['name'] }.sort
      expect(dependencies).not_to include('private_module_1')
      expect(dependencies).not_to include('private_module_2')
      expect(dependencies).to eq(['puppetlabs/powershell', 'puppetlabs/reboot'])
    end

    it 'has not include private modules on the modules list' do
      modules = plugins['modules']['value'].map { |mod| mod['name'] }.sort
      expect(modules).not_to include('my_private_module')
      expect(modules).to eq(%w[apache concat mysql stdlib])
    end
  end

  context 'when dev' do
    it 'schema is executed' do
      shell_result = run_shell('dropsonde dev schema')
      expect(shell_result.exit_code).to eq(0)
    end

    it 'example is executed' do
      shell_result = run_shell('dropsonde dev example')
      expect(shell_result.exit_code).to eq(0)
    end
  end
end
