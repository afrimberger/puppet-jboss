require File.expand_path(File.join(File.dirname(__FILE__), '../../../puppet_x/coi/jboss'))

Puppet::Type.type(:jboss_resourceadapter_adminobject).provide(:jbosscli,
    :parent => Puppet_X::Coi::Jboss::Provider::AbstractJbossCli) do

  def create
    params = prepareconfig[:basics]
    basicsParams = makejbprops params
    cmd = compilecmd "#{basepath}:add(#{basicsParams})"
    bringUp "Resource adapter Admin Object ", cmd
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
    getconfigprops $data
  end

  def configproperties= value
    setconfigprops basepath, configproperties, value
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

  def getconfprop prop_name
    $data['config-properties'][prop_name]
  end




end
