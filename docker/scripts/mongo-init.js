// MongoDB Initialization Script for DreamScape Services
// DR-334: INFRA-010.2 - Database initialization for Auth and User services

// Switch to the dreamscape database
db = db.getSiblingDB('dreamscape');

// Create collections for auth service
db.createCollection('users');
db.createCollection('auth_tokens');
db.createCollection('refresh_tokens');

// Create collections for user service
db.createCollection('user_profiles');
db.createCollection('user_preferences');
db.createCollection('user_activities');

// Create indexes for auth service
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ id: 1 }, { unique: true });
db.auth_tokens.createIndex({ token: 1 }, { unique: true });
db.auth_tokens.createIndex({ userId: 1 });
db.auth_tokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
db.refresh_tokens.createIndex({ token: 1 }, { unique: true });
db.refresh_tokens.createIndex({ userId: 1 });
db.refresh_tokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Create indexes for user service
db.user_profiles.createIndex({ userId: 1 }, { unique: true });
db.user_profiles.createIndex({ email: 1 }, { unique: true });
db.user_preferences.createIndex({ userId: 1 }, { unique: true });
db.user_activities.createIndex({ userId: 1 });
db.user_activities.createIndex({ createdAt: 1 });

// Create application user with limited permissions
db.createUser({
  user: 'dreamscape_app',
  pwd: 'app_password_123',
  roles: [
    {
      role: 'readWrite',
      db: 'dreamscape'
    }
  ]
});

print('DreamScape database initialized successfully');
print('Collections created: users, auth_tokens, refresh_tokens, user_profiles, user_preferences, user_activities');
print('Indexes created for optimal performance');
print('Application user "dreamscape_app" created with readWrite permissions');