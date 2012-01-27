test_name "should create a user, and the default matching group"

name = "pl#{rand(999999).to_i}"

step "ensure that the user and group #{name} do not exist"
on(agents, puppet_resource('user', name, 'ensure=absent'))
on(agents, puppet_resource('group', name, 'ensure=absent'))

step "ask puppet to create the user"
on(agents, puppet_resource('user', name, 'ensure=present'))

step "verify that the user and group now exist"
agents.each do |agent|
  on(agent, puppet_resource('user', name)) do
    fail_test "user #{name} should exist" unless stdout.include? 'present'
  end
  case agent['platform']
  when /sles/, /solaris/, /windows/
    # no private user groups by default
  else
    on(agent, puppet_resource('group', name)) do
      fail_test "group #{name} should exist" unless stdout.include? 'present'
    end
  end
end

step "ensure that the user and group #{name} do not exist"
on(agents, puppet_resource('user', name, 'ensure=absent'))
on(agents, puppet_resource('group', name, 'ensure=absent'))
