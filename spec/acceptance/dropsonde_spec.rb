# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'dropsonde'
require 'json'

RSpec.describe 'Dropsonde Acceptance: Basic' do
  context 'when dropsonde is installed and has correct version' do
    let(:version) { run_local_command('dropsonde').stdout }
    let(:is_installed) { true if run_local_command('gem list | grep dropsonde').exit_code == 0 }

    it 'is installed' do
      expect(is_installed).to be true
    end

    it 'has correct version' do
      expect(version).to match(%r{#{Dropsonde::VERSION}})
    end
  end

  context 'when update' do
    it 'works' do
      Dropsonde::Cache.new('foo', 7, true)
    end
  end

  context 'when report is generated' do
    let(:puppetdb_session) { Dropsonde.new }

    it 'ignores private modules, private dependencies and private classes' do
      Dropsonde.settings = { enable: %w[dependencies modules] }
      allow(puppetdb_session.puppet_db).to receive(:request).with('', 'resources[type, title] { type = "Class" }').and_return(
        OpenStruct.new(data: [
                         { 'type' => 'Class', 'title' => 'Mysql::Params' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Account_security' },
                         { 'type' => 'Class', 'title' => 'Role::Database_server' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Install' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Providers' },
                         { 'type' => 'Class', 'title' => 'My_private_module' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Managed_dirs' },
                         { 'type' => 'Class', 'title' => 'Profile::Scr_mysql' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server' },
                         { 'type' => 'Class', 'title' => 'Profile::Base' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Config' },
                         { 'type' => 'Class', 'title' => 'Mysql::Server::Service' },
                       ]),
      )
      plugins = Dropsonde::Metrics.new.report(puppetdb_session)[:'self-service-analytics'][:snapshots]
      modules = plugins[:modules]['value'].map { |mod| mod[:name] }.sort
      classes = plugins[:classes]['value'].map { |mod| mod[:name] }.sort
      dependencies = plugins[:dependencies]['value'].map { |mod| mod[:name] }.sort
      expect(modules).not_to include('my_private_module')
      expect(modules).to eq(%w[apache concat mysql stdlib])
      expect(dependencies).not_to include('private_module_1')
      expect(dependencies).not_to include('private_module_2')
      expect(classes).not_to include('My_private_module')
    end
  end
end
