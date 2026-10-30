# Run with gitlab-rails runner. Gives root a
# personal access token with the known value in ADMIN_TOKEN.
value = ENV.fetch('ADMIN_TOKEN')
user = User.find_by_username!('root')
user.personal_access_tokens.where(name: 'bootstrap').each(&:revoke!)
token = user.personal_access_tokens.build(
  name: 'bootstrap',
  scopes: %w[api admin_mode sudo],
  expires_at: 30.days.from_now,
  organization_id: user.organization_id
)
token.set_token(value)
token.save!
puts "ok #{token.id}"
