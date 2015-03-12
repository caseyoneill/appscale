#!/usr/bin/ruby -w


require 'fileutils'


$:.unshift File.join(File.dirname(__FILE__))
require 'helperfunctions'
require 'monit_interface'

$:.unshift File.join(File.dirname(__FILE__), "..")
require 'djinn'

# A module to wrap all the interactions with shibboleth.
module Shibboleth

  # The service name for shibboleth.
  SHIB_SERVICE = "shibd"

  # The location for shibboleth configuration.
  SHIB_PATH = "/etc/shibboleth/"

  # Main configuration file.
  SHIB_CONFIG = "#{SHIB_PATH}shibboleth2.xml"

  def self.start()
    start_cmd = "service #{SHIB_SERVICE} start"
    stop_cmd = "service #{SHIB_SERVICE} stop"
    match_cmd = "/usr/sbin/shibd"
    MonitInterface.start(:shib, start_cmd, stop_cmd, ports=9999, env_vars=nil,
      remote_ip=nil, remote_key=nil, match_cmd=match_cmd)
  end

  def self.stop()
    MonitInterface.stop(:shib)
  end

  # Reload shibboleth if it is already running. If shibboleth is not running, start it.
  def self.reload()
    if Shibboleth.is_running?
      HelperFunctions.shell("service #{SHIB_SERVICE} reload")
      if $?.to_i != 0
        Djinn.log_error("Error when trying to reload shibboleth configurations!")
        Shibboleth.start()
      end
    else
      Shibboleth.start()
    end
  end

  def self.is_running?
    processes = `ps ax | grep shibd | grep worker | grep -v grep | wc -l`.chomp
    if processes == "0"
      return false
    else
      return true
    end
  end

  # Return true if the configuration is good, false o.w.
  def self.check_config()
    HelperFunctions.shell("service #{SHIB_SERVICE} status")
    return ($?.to_i == 0)
  end

  def self.reload_shibboleth()
    if Shibboleth.check_config()
      Shibboleth.reload()
      return true
    else
      Djinn.log_error("Unable to load shibboleth configuration.")
      return false
    end
  end 

  # Installs shibboleth, assumes that apache is already installed.
  def install_shibboleth()
    Djinn.log_run("apt-get install -y shibboleth")

    # Enable the module in apache.
    Djinn.log_run("a2enmod shib2")
  end


  # Set up the folder structure and creates the configuration files necessary for
  # apache.
  def initialize_config(virtual_host, sp_provider, private_ip)
    shib = <<CONFIG
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"    
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">
    <ApplicationDefaults entityID="https://#{virtual_host}:1443/shibboleth"
            REMOTE_USEsions lifetime="28800" timeout="3600" 
            checkAddress="false" relayState="ss:mem" handlerSSL="true" >

            <SSO entityID="https://#{sp_provider}">
              SAML2 SAML1
            </SSO>

            <Logout>SAML2 Local</Logout>

            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>

            <Handler type="Status" Location="/Status" acl="#{private_ip}"/>

            <Handler type="Session" Location="/Session" showAttributeValues="true"/>

            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>
        <Errors supportContact="root@localhost"
            logoLocation="/shibboleth-sp/logo.jpg"
            styleSheet="/shibboleth-sp/main.css"/>

        <MetadataProvider type="XML" uri="https://#{sp_provider}"
              backingFilePath="panda-metadata.xml" reloadInterval="7200">
        </MetadataProvider>
        <AttributeExtractor type="XML" validate="true" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <CredentialResolver type="File" key="/etc/nginx/mykey.pem" certificate="/etc/nginx/mycert.pem"/>
      </ApplicationDefaults>

    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>

    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>

</SPConfig>
CONFIG

    # Write the port configuration.
    File.open(shib, "w+") { |dest_file| dest_file.write("#{SHIB_CONFIG}") }
  end
end
