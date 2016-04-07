require File.expand_path(File.join(File.dirname(__FILE__), '../../../puppet_x/coi/jboss'))

Puppet::Type.type(:jboss_resourceadapter_adminobject).provide(:jbosscli,
    :parent => Puppet_X::Coi::Jboss::Provider::AbstractJbossCli) do

  def create
    params = prepareconfig[:basics]
    basicsParams = makejbprops params[:basics]
    cmd = compilecmd "#{basepath}:add(#{basicsParams})"
    bringUp "Resource adapter Admin Object ", cmd
    # createConnections
    # createconfprops
  end

  def destroy
    cmd = compilecmd "#{basepath}:remove()"
    bringDown "Resource adapter Admin Object", cmd
  end

  def exists?
    $data = nil
    raadapter = @resource[:resourceadapter]
    name      = @resource[:name]
    cmd = compilecmd "/subsystem=resource-adapters/resource-adapter=#{raadapter}/admin-objects=#{name}:read-resource(recursive=true)"
    res = executeAndGet(cmd)
    if not res[:result]
      Puppet.debug "Resource Adapter adminobject is not set"
      return false
    end
    $data = res[:data]
    return true
  end

  def jndiname
    getattribute 'jndi-name'
  end

  def jndiname= newval
    setattribute basepath, newval
  end

  def usejavacontext
    getattribute 'use-java-context'
  end

  def usejavacontext= newval
    setattribute 'use-java-context', newval
  end

  def classname
    getattribute 'class-name'
  end

  def classname= newval
    setattribute basepath, 'class-name', newval
  end

  def resourceadapter
    @resource[:resourceadapter]
  end

  def resourceadapter= raname
    $data['resourceadapter'] = raname
  end

  def configproperties
    getconfigprops
  end

  def configproperties= value
    setconfigprops value
  end


  protected


  def prepareconfig
    params = {
        :basics => {
            'class-name'       => @resource[:classname],
            'jndi-name'        => @resource[:jndiname],
            'use-java-context' => @resource[:usejavacontext],
        },
        :config_properties => {},
    }
    return params
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

  def getattribute attribname
    $data[attribname]
  end

  def basepath
    name   = @resource[:name]
    raname = @resource[:resourceadapter]
    "/subsystem=resource-adapters/resource-adapter=#{raname}/admin-objects=#{name}"
  end


  def reload
    cmd = compilecmd "/:reload"
    executeWithFail("Reload ", cmd, '')
  end






  # TODO: Can this be generalized? I suppose code looks pretty the same as the one in jboss_resourceadapter.
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
    "#{basepath}/config-properties=#{prop_name}"
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
