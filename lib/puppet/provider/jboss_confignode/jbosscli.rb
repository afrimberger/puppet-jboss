require 'puppet/provider/jbosscli'
Puppet::Type.type(:jboss_confignode).provide(:jbosscli, :parent => Puppet::Provider::Jbosscli) do
  desc "JBoss CLI configuration node provider"
  
  def create
    bringUp 'Configuration node', "#{compiledpath}:add(#{compileprops})"
  end

  def destroy
    bringDown 'Configuration node', "#{compiledpath}:remove()"
  end
  
  def exists?
    if @resource[:path].nil?
      @resource[:path] = @resource[:name]
    end
    @resource[:properties].each do |key, value|
      if value == "undef"
        @resource[:properties][key] = nil
      end
    end
    
    res = execute_datasource "#{compiledpath}:read-resource()"
    if res[:result]
      $data = {}
      res[:data].each do |key, value|
        props = @resource[:properties]
        if props.key? key
          $data[key] = value
        end
      end
      return true
    end
    $data = nil
    return false
  end
  
  def properties
    $data
  end
  
  def properties= newprops
    newprops.each do |key, value|
      if not $data.key? key or $data[key] != value
        writekey key, value
        Puppet.notice "JBoss::Property: Key `#{key}` with value `#{value.inspect}` for path `#{compiledpath}` has been set."
      end 
    end
  end
  
  private
  
  def writekey key, value
    if value.nil?
      bringDown 'Configuration node property', "#{compiledpath}:undefine-attribute(name=#{key})"
    else
      preparedval = escape value
      bringUp 'Configuration node property', "#{compiledpath}:write-attribute(name=#{key}, value=#{preparedval})"
    end
  end
  
  def compiledpath
    path = @resource[:path]
    cmd = compilecmd path
  end
  
  def compileprops
    props = @resource[:properties]
    arr = []
    props.each do |key, value|
      preparedval = escape value
      arr.push "#{key}=#{preparedval}"
    end
    arr.join ', '
  end
end