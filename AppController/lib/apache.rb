#!/usr/bin/ruby -w


require 'fileutils'


$:.unshift File.join(File.dirname(__FILE__))
require 'helperfunctions'
require 'monit_interface'

$:.unshift File.join(File.dirname(__FILE__), "..")
require 'djinn'

# A module to wrap all the interactions with the apache web server
module Apache

  # The service name for apache.
  APACHE_SERVICE = "apache2"

  # The path where apache configurations can be found.
  APACHE_PATH = "/etc/apache2/"

  # The dir where we can find sites enabled/available for apache.
  SITES_ENABLED = "sites-enabled"
  SITES_AVAILABLE = "sites-available"

  # Location of the ports configuration for apache.
  PORT_CONFIG_FILE = File.join(APACHE_PATH, "ports.conf")

  def self.start()
    start_cmd = "service #{APACHE_SERVICE} start"
    stop_cmd = "service #{APACHE_SERVICE} stop"
    match_cmd = "/usr/sbin/#{APACHE_SERVICE}"
    MonitInterface.start(:apache2, start_cmd, stop_cmd, ports=9999, env_vars=nil,
      remote_ip=nil, remote_key=nil, match_cmd=match_cmd)
  end

  def self.stop()
    MonitInterface.stop(:apache2)
  end

  # Reload apache if it is already running. If apache is not running, start it.
  def self.reload()
    if Apache.is_running?
      HelperFunctions.shell("service #{APACHE_SERVICE} reload")
      if $?.to_i != 0
        Djinn.log_error("Error when trying to reload Apache configurations!")
        Apache.start()
      end
    else
      Apache.start()
    end
  end

  def self.is_running?
    processes = `ps ax | grep apache2 | grep worker | grep -v grep | wc -l`.chomp
    if processes == "0"
      return false
    else
      return true
    end
  end

  # Return true if the configuration is good, false o.w.
  def self.check_config()
    HelperFunctions.shell("service #{APACHE_SERVICE} status")
    return ($?.to_i == 0)
  end

  def self.reload_apache()
    if Apache.check_config()
      Apache.reload()
      return true
    else
      Djinn.log_error("Unable to load Nginx config for #{app_name}")
      return false
    end
  end 

  # Installs apache2.
  def install_apache()
    Djinn.log_run("apt-get install -y apache2")
  end


  # Set up the folder structure and creates the configuration files necessary for
  # apache.
  def initialize_config(virtual_host, private_ip)
    ports = <<CONFIG
    NameVirtualHost *:1080
Listen 1080
<IfModule mod_ssl.c>
    Listen 1443
</IfModule>
<IfModule mod_gnutls.c>
    Listen 1443
</IfModule>
CONFIG

    # Write the port configuration.
    File.open(ports, "w+") { |dest_file| dest_file.write("#{APACHE_PATH}#{PORT_CONFIG_FILE}") }

    default = <<CONFIG
<VirtualHost *:1080>
	ServerAdmin webmaster@localhost
        ServerName #{virtual_host}:1443
	ErrorLog ${APACHE_LOG_DIR}/error.log
	LogLevel warn
	CustomLog ${APACHE_LOG_DIR}/access.log combined
        Redirect / https://#{virtual_host}:1443
</VirtualHost>
CONFIG


    default_ssl = <<CONFIG
<IfModule mod_ssl.c>
<VirtualHost _default_:1443>
        ServerAdmin webmaster@localhost
        ServerName #{virtual_host}:1443
        UseCanonicalName On
        SSLProxyEngine On

        ProxyPass /shibboleth/ !
        ProxyPassReverse /shibboleth/ !
        ProxyPass /shibboleth !
        ProxyPassReverse /shibboleth !
        ProxyPass /Shibboleth.sso/ !
        ProxyPassReverse /Shibboleth.sso/ !

        ProxyPass / http://#{private_ip}:8060/ retry=0 timeout=5
        ProxyPassReverse / http://#{private_ip}:8060/

        ErrorLog ${APACHE_LOG_DIR}/error.log
        LogLevel warn
        CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined
        SSLEngine on
        SSLCertificateFile    /etc/nginx/mycert.pem
        SSLCertificateKeyFile /etc/nginx/mykey.pem
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch "MSIE [2-6]" \
                nokeepalive ssl-unclean-shutdown \
                downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

        <Location />
          AuthType shibboleth
          Require shibboleth
          ShibUseHeaders On
        </Location>

        <Location /Shibboleth.sso>
           SetHandler shib
        </Location>

        <Location /shibboleth>
           SetHandler shib
        </Location>

</VirtualHost>
</IfModule>
CONFIG

    # Remove the old sites enabled files first if they exist.
    Djinn.log_run("rm -rfv #{APACHE_PATH}#{SITES_AVAILABLE}/*")
    File.open("#{APACHE_PATH}#{SITES_AVAILABLE}/default", "w+") { |dest_file| dest_file.write(default) }
    File.open("#{APACHE_PATH}#{SITES_AVAILABLE}/default-ssl", "w+") { |dest_file| dest_file.write(default_ssl) }

    # Remove old soft links.
    Djinn.log_run("rm -rfv #{APACHE_PATH}#{SITES_ENABLED}/*")

    # Create soft links for enabled sites.
    Djinn.log_run("ln -s #{APACHE_PATH}#{SITES_AVAILABLE}/default #{APACHE_PATH}#{SITES_ENABLED}/default")
    Djinn.log_run("ln -s #{APACHE_PATH}#{SITES_AVAILABLE}/default-ssl #{APACHE_PATH}#{SITES_ENABLED}/default-ssl")
  end
end
