require File.expand_path(File.join(File.dirname(__FILE__), '../../../puppet_x/coi/jboss'))

Puppet::Type.type(:jboss_resourceadapter).provide(:jbosscli,
    :parent => Puppet_X::Coi::Jboss::Provider::AbstractJbossCli) do

  def create
    name = @resource[:name]
    jndiname = @resource[:jndiname]
    params = prepareconfig()
    basicsParams = makejbprops params[:basics]
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{name}:add(#{basicsParams})"
    bringUp "Resource adapter", cmd
    createConnections
    createconfprops
  end

  def destroy
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}:remove()"
    bringDown "Resource adapter", cmd
  end

  def exists?
    $data = nil
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}:read-resource(recursive=true)"
    res = executeAndGet(cmd)
    if not res[:result]
      Puppet.debug "Resource Adapter is not set"
      return false
    end
    $data = res[:data]
    return true
  end

  def archive
    $data['archive']
  end

  def archive= value
    setbasicattr 'archive', value
  end

  def transactionsupport
    $data['transaction-support']
  end

  def transactionsupport= value
    setbasicattr 'transaction-support', value
  end

  def jndiname
    jndis = []
    if $data['connection-definitions'].nil?
      $data['connection-definitions'] = {}
    end
    $data['connection-definitions'].each do |jndi, config|
      jndis.push jndi
    end
    given = @resource[:jndiname]
    if jndis - given == [] and given - jndis == []
      # Returning in apopriate order to prevent changes
      jndis = given
    end
    Puppet.debug "JNDI getter -------- POST! => #{jndis.inspect}"
    return jndis
  end

  def jndiname= value
    Puppet.debug "JNDI setter -------- PRE!"
    names = jndiname
    toremove = names - value # Existing array minus new provides array to be removed
    trace 'jndiname=(%s) :: toremove=%s' % [value.inspect, toremove.inspect]
    toadd = value - names    # New array minus existing provides array to be added
    trace 'jndiname=(%s) :: toadd=%s' % [value.inspect, toadd.inspect]
    toremove.each do |jndi|
      destroyconn jndi
    end
    toadd.each do |jndi|
      config = prepareconfig()
      createconn jndi, config[:connections][jndi]
    end
    exists? # Re read configuration
  end

  def configproperties
    getconfigprops
  end

  def configproperties= value
    setconfigprops value
  end

  def classname
    getconnectionattr 'class-name'
  end

  def classname= value
    setconnectionattr 'class-name', value
  end

  def backgroundvalidation
    getconnectionattr 'background-validation'
  end

  def backgroundvalidation= value
    setconnectionattr 'background-validation', value
  end

  def security
    if Puppet_X::Coi::Jboss::Functions.jboss_to_bool(getconnectionattr 'security-application')
      return 'application'
    end
    if Puppet_X::Coi::Jboss::Functions.jboss_to_bool(getconnectionattr 'security-domain-and-application')
      return 'domain-and-application'
    end
    if Puppet_X::Coi::Jboss::Functions.jboss_to_bool(getconnectionattr 'security-domain')
      return 'domain'
    end
    return nil
  end

  def security= value
    if value == 'application'
      setconnectionattr 'security-application', true
      setconnectionattr 'security-domain-and-application', nil
      setconnectionattr 'security-domain', nil
    elsif value == 'domain-and-application'
      setconnectionattr 'security-application', nil
      setconnectionattr 'security-domain-and-application', true
      setconnectionattr 'security-domain', nil
    elsif value == 'domain'
      setconnectionattr 'security-application', nil
      setconnectionattr 'security-domain-and-application', nil
      setconnectionattr 'security-domain', true
    else
      raise "Invalid value for security: #{value}. Supported values are: application, domain-and-application, domain"
    end
  end

  protected

  def createConnections
    if $data.nil?
      exists? # Re read configuration
    end
    prepareconfig()[:connections].each do |jndi, config|
      if not connExists? jndi
        createconn jndi, config
      end
    end
  end

  def connExists? jndi
    if $data['connection-definitions'].nil?
      $data['connection-definitions'] = {}
    end
    if not $data['connection-definitions'][jndi].nil?
      return true
    end
    name = @resource[:name]
    connectionName = escapeforjbname jndi
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{name}/connection-definitions=#{connectionName}:read-resource()"
    res = executeAndGet cmd
    if res[:result]
      $data['connection-definitions'][jndi] = res[:data]
    end
    return res[:result]
  end

  def createconn jndi, config
    name = @resource[:name]
    connectionParams = makejbprops config
    connectionName = escapeforjbname jndi
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{name}/connection-definitions=#{connectionName}:add(#{connectionParams})"
    bringUp "Resource adapter connection-definition", cmd
  end

  def destroyconn jndi
    name = @resource[:name]
    connectionName = escapeforjbname jndi
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{name}/connection-definitions=#{connectionName}:remove()"
    bringDown "Resource adapter connection-definition", cmd
  end

  def prepareconfig
    params = {
      :basics => {
        'archive'             => @resource[:archive],
        'transaction-support' => @resource[:transactionsupport],
      },
      :connections => {},
    }
    if @resource[:jndiname].nil?
      @resource[:jndiname] = []
    end
    @resource[:jndiname].each do |jndiname|
      params[:connections][jndiname] = {
        'jndi-name'             => jndiname,
        'class-name'            => @resource[:classname],
        'background-validation' => @resource[:backgroundvalidation],
      }
      case @resource[:security]
      when 'application'
          params[:connections][jndiname]['security-application'] = true
          params[:connections][jndiname]['security-domain-and-application'] = nil
          params[:connections][jndiname]['security-domain'] = nil
      when 'domain-and-application'
          params[:connections][jndiname]['security-application'] = nil
          params[:connections][jndiname]['security-domain-and-application'] = true
          params[:connections][jndiname]['security-domain'] = nil
      when 'domain'
          params[:connections][jndiname]['security-application'] = nil
          params[:connections][jndiname]['security-domain-and-application'] = nil
          params[:connections][jndiname]['security-domain'] = true
      end
    end
    return params
  end

  def escapeforjbname input
    input.gsub(/([^\\])\//, '\1\\/').gsub(/([^\\]):/, '\1\\:')
  end

  def unescapeforjbname input
    input.gsub(/\\\//, '/').gsub(/\\:/, ':')
  end

  def makejbprops input
    inp = {}
    input.each do |k, v|
      if not v.nil?
        inp[k] = v
      end
    end
    inp.inspect.gsub('=>', '=').gsub(/[\{\}]/, '').gsub(/\"([^\"]+)\"=/,'\1=')
  end

  def setbasicattr name, value
    setattribute "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}", name, value
    $data[name] = value
  end

  def setconnectionattr name, value
    prepareconfig()[:connections].each do |jndi, config|
      if not connExists? jndi
        createconn jndi, config
        next
      end
      connectionName = escapeforjbname jndi
      if value.nil?
        cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}/connection-definitions=#{connectionName}:undefine-attribute(name=#{name})"
        bringDown "Resource adapter connection definition attribute #{name}", cmd
      else
        setattribute "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}/connection-definitions=#{connectionName}", name, value
      end
      $data['connection-definitions'][jndi][name] = value
    end
  end

  def getconnectionattr name
    prepareconfig()[:connections].each do |jndi, config|
      if not connExists? jndi
        return nil
      end
      if $data['connection-definitions'][jndi].nil?
        return nil
      end
      return $data['connection-definitions'][jndi][name]
    end
  end


  def reload
    cmd = compilecmd "/:reload"
    executeWithFail("Reload ", cmd, '')
  end


  def createconfprops
    if $data.nil?
      exists? # Reread configuration
    end

    @resource[:configproperties].each do |k, v|
      createconfprop k, v
    end

  end

  def getconfigprops
    ret = {}

    if $data['config-properties'].nil?
      $data['config-properties'] = {}
    end

    $data['config-properties'].each do |prop_key, val_hash|
      ret[prop_key] = val_hash['value']
    end

    return ret
  end

  def basecmdconfigprop prop_name
    "/subsystem=resource-adapters/resource-adapter=#{@resource[:name]}/config-properties=#{prop_name}"
  end

  def getconfprop prop_name
    $data['config-properties'][prop_name]
  end

  def createconfprop prop_name, prop_val
     cmd = compilecmd "#{basecmdconfigprop prop_name}:add(value=\"#{prop_val}\")"
     executeWithFail("Config Property", cmd, 'to create')
  end

  def destroyconfprop prop_name
    cmd = compilecmd "#{basecmdconfigprop prop_name}:remove()"
    executeWithFail("Config Property", cmd, 'to destroy')
  end

  def updateconfprop prop_name, new_val
    curr_val = getconfprop prop_name

    if new_val.nil?
      destroyconfprop prop_name
    else
      # Writing the value is due to a JBoss restriction not possible:
      #  Warning: JBoss CLI command failed, try 1/3, last status: 1, message: {
      #   "outcome" => "failed",
      #   "failure-description" => "JBAS014639: Attribute value is not writable",
      #   "rolled-back" => true
      #  }
      destroyconfprop prop_name
      reload
      createconfprop prop_name, new_val
    end
  end

  def setconfigprops new_props
    existing_props = getconfigprops
    toremove = existing_props.reject { |k| new_props.key?(k)} # existing_props - new_props
    toadd    = new_props.reject {|k| existing_props.key?(k)}  # new_props - existing_props
    toupdate = existing_props.reject {|k| toremove.key?(k) or toadd.key?(k)} # existing_props - toremove - toadd

    trace 'configprops :: toremove=%s' % [toremove.inspect]
    trace 'configprops :: toadd=%s' % [toadd.inspect]
    trace 'configprops :: toupdate=%s' % [toupdate.inspect]

    toremove.each do |prop_name, prop_val|
      destroyconfprop prop_name
    end

    toadd.each do |prop_name, prop_val|
      createconfprop prop_name, prop_val
    end

    toupdate.each do |prop_name, prop_val|
      updateconfprop prop_name, prop_val
    end

  end

end
