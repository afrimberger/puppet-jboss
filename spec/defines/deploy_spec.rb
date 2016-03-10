require 'spec_helper_puppet'

describe 'jboss::deploy', :type => :define do

  shared_examples 'containing class structure' do
    it { is_expected.to contain_class('jboss') }
    it { is_expected.to contain_class('jboss::internal::runtime::node') }
    it { is_expected.to contain_jboss_deploy(title).with({
      :ensure => 'present',
      :source => '/tmp/jboss.war'
      }) }
  end

  shared_examples 'containing self' do
    it { is_expected.to contain_jboss__deploy(title).with({
        :ensure => 'present',
        :jndi   => title
    }) }
  end

  context 'On RedHat os family' do
    extend Testing::RspecPuppet::SharedExamples
    let(:title) { 'test-deploy' }
    let(:params) { { :path => '/tmp/jboss.war', } }
    let(:facts) do
      {
        :operatingsystem => 'OracleLinux',
        :osfamily        => 'RedHat',
        :ipaddress       => '192.168.0.1',
        :concat_basedir  => '/root/concat',
        :puppetversion   => Puppet.version
      }
    end
    it_behaves_like 'containing class structure'
    it_behaves_like 'containing self'
  end

  context 'On Debian os family' do
    extend Testing::RspecPuppet::SharedExamples
    let(:title) { 'test-deploy' }
    let(:params) { { :path => '/tmp/jboss.war', } }
    let(:facts) do
      {
        :operatingsystem => 'Ubuntu',
        :osfamily        => 'Debian',
        :ipaddress       => '192.168.0.1',
        :concat_basedir  => '/root/concat',
        :lsbdistcodename => 'trusty',
        :puppetversion   => Puppet.version
      }
    end
    it_behaves_like 'containing class structure'
    it_behaves_like 'containing self'
  end
end
