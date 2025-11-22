
realm: dev-realm
client-id:app-client

- Client authentication on
- Authorization on

home url: http://localhost:8080
valid redirect-url: 
http://localhost:8080/login/oauth2/code/*
http://localhost:8080/*
http://localhost:8080

post-logout-url: http://localhost:8080

Create roles
`ROLE_USER`
`ROLE_ADMIN`

Create user -> credential -> role mapping
john@test.com
12345
- role mapping
  Assign client role Role User

admin@admin.com
admin


Progress

Summary of what you've configured:
  - ✅ Keycloak running on http://localhost:3081
  - ✅ Realm: dev-realm
  - ✅ Client: app-client (with client secret saved)
  - ✅ Roles: ROLE_USER, ROLE_ADMIN
  - ✅ Users: john (USER) , admin (USER + ADMIN) admin
  john@test.com / 12345
  admin@test.com / admin