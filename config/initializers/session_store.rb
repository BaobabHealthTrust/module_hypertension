# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_module_hypertension_session',
  :secret      => 'df642dee1e743e34da892dabe63560dd3422a3cbddeb8747c395e0ce170eb7f5ab98fdb9a4b9bfe189b855df74c9ef0a10b21c363a1ff877a2098d9fb46fe1c9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
