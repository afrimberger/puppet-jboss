# A class for JBoss deploy
module Puppet_X::Coi::Jboss::Provider::Deploy
  def create
    deploy unless @resource[:remove_on_refresh]
  end

  def destroy
    undeploy
  end

  def redeploy_on_refresh
    Puppet.debug('-----------------------> Refresh event from deploy')
    if @resource[:remove_on_refresh]
      if exists?
        Puppet.info("Refresh event triggered undeploy of #{@resource[:jndi]}")
        undeploy
      end
      return
    end

    Puppet.info("Refresh event triggered deploy of #{@resource[:jndi]}")
    undeploy if @resource[:redeploy_on_refresh] and exists?
    deploy
  end

  def is_exact_deployment?
    true
  end

  def exists?
    if name_exists?
      is_exact_deployment?
    else
      false
    end
  end

  def servergroups
    if not @resource[:runasdomain]
      return @resource[:servergroups]
    end
    servergroups = @resource[:servergroups]
    res = execute("deployment-info --name=#{@resource[:jndi]}")
    if not res[:result]
      return []
    end
    groups = []
    for line in res[:lines]
        line.strip!
        depinf = line.split
        if(depinf[1] == "enabled" || depinf[1] == "added")
            groups.push(depinf[0])
        end
    end
    if servergroups.nil? or servergroups.empty? or servergroups == ['']
      return servergroups
    end
    return groups
  end

  def servergroups=(value)
    if not @resource[:runasdomain]
      return nil
    end
    current = servergroups()
    Puppet.debug(current.inspect())
    Puppet.debug(value.inspect())

    toset = value - current
    cmd = "deploy --name=#{@resource[:jndi]} --server-groups=#{toset.join(',')}#{runtime_name_param_with_space_or_empty_string}"
    res = bringUp('Deployment', cmd)
  end

  private

  def runtime_name_param
    if @resource[:runtime_name].nil?
      ''
    else
      "--runtime-name=#{@resource[:runtime_name]}"
    end
  end

  def runtime_name_param_with_space_or_empty_string
      if @resource[:runtime_name].nil?
          ''
      else
          " #{runtime_name_param}"
      end
  end

  def deploy

    Puppet.debug("------------------------------------------> DEPLOY #{@resource[:jndi]}")
    cmd = "deploy #{@resource[:source]} --name=#{@resource[:jndi]}#{runtime_name_param_with_space_or_empty_string}"
    if @resource[:runasdomain]
      servergroups = @resource[:servergroups]
      if servergroups.nil? or servergroups.empty? or servergroups == ['']
        cmd = "#{cmd} --all-server-groups"
      else
        cmd = "#{cmd} --server-groups=#{servergroups.join(',')}"
      end
    end
    if @resource[:redeploy_on_refresh]
      cmd = "#{cmd} --force"
    end
    isprintinglog = 100
    bringUp 'Deployment', cmd
  end

  def undeploy
    Puppet.debug("------------------------------------------> UN-DEPLOY #{@resource[:jndi]}")
    cmd = "undeploy #{@resource[:jndi]}"
    if @resource[:runasdomain]
      servergroups = @resource[:servergroups]
      if servergroups.nil? or servergroups.empty? or servergroups == ['']
        cmd = "#{cmd} --all-relevant-server-groups"
      else
        cmd = "#{cmd} --server-groups=#{servergroups.join(',')}"
      end
    end
    isprintinglog = 0
    bringDown 'Deployment', cmd
  end

  def name_exists?
    res = executeAndGet "/deployment=#{@resource[:jndi]}:read-resource()"

    if not res[:result]
        return false
    end

    data = res[:data]
    unless data['name'].nil?
      Puppet.debug "Deployment found: #{data['name']}"
      return true
    end
    Puppet.debug "No deployment matching #{@resource[:jndi]} found."
    return false
  end
end
