test_name "should create a user"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the user does not exist"
  agent.user_absent(name)

  step "create the user"
  on agent, puppet_resource('user', name, 'ensure=present')

  step "verify the user exists"
  agent.user_get(name)

  step "delete the user"
  agent.user_absent(name)
  agent.group_absent(name)
end
