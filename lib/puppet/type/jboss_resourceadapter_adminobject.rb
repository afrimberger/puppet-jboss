Puppet::Type.newtype(:jboss_resourceadapter_adminobject) do
  @doc = "Manages resource adapter's adminobject on JBoss Application Server"
  ensurable

  newparam(:name) do
    desc "The name/ID of the resource adapter's admin object."
    isnamevar
    isrequired
  end

  newproperty(:resourceadapter) do
    desc "The name of the resource adapter to which this admin object corresponds to."
    isrequired
  end

  newproperty(:jndiname) do
    desc "The admin objects jndi name."
    isrequired
  end

  newproperty(:classname) do
    desc "The admin objects class name."
    isrequired
  end

  newproperty(:usejavacontext, :boolean => true) do
    desc "use java context?"
    defaultto true
  end

  newproperty(:configproperties) do
    desc "The admin objects config-properties"
    defaultto {}
  end

  newparam(:profile) do
    desc "The JBoss profile name"
    defaultto "full"
  end

  newparam(:runasdomain, :boolean => true) do
    desc "Indicate that server is in domain mode"
    defaultto true
  end

  newparam(:controller) do
    desc "Domain controller host:port address"
    validate do |value|
      if value == nil or value.to_s == 'undef'
        raise ArgumentError, "Domain controller must be provided"
      end
    end
  end

  newparam :ctrluser do
    desc 'A user name to connect to controller'
  end

  newparam :ctrlpasswd do
    desc 'A password to be used to connect to controller'
  end

  newparam :retry do
    desc "Number of retries."
    defaultto 3
  end

  newparam :retry_timeout do
    desc "Retry timeout in seconds"
    defaultto 1
  end

end
