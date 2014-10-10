This is an example of user authentication/authorization and session management in Rails.

# User

A User has an email, and has a password. However, we **never** store the password in the database as plaintext. It is a huge security vulnerability.

Instead, what we need to do is to store the password *hash* in the database, which is generated from the user-supplied password and a common app-specific hash secret. You additionally need a *salt* in order to prevent rainbow attacks, a type of exploit. Our hash should also be slow, and one-way. The basic idea is that the user inputs their password twice, the second being a confirmation of the password, and that password is passed through a hash algorithm along with a salt, and that result is compared to the matching digest in the database. If it matches, the user is logged in.

Rails includes a gem called `bcrypt` by default that solves some of these problems for us. It will set various attributes on the User model when `has_secure_password` is set on the model, and will handle password hashing and salting. The use of `bcrypt` requires the User schema to have the attribute `password_digest`, so that is **required**. So, in the schema, the User will have a `username` or `email` attribute, and a `password_digest` attribute. That means our migration will look something like this:

`rails generate migration CreateUsers email:string password_digest:string`

Our model, on the other hand, will only require the `has_secure_password` method called within it in order to be compatible with our `bcrypt` setup. The User model will have a password and a password_confirmation field when a User is instantiated.

So, our basic, very initial workflow will look like this:

    rails g migration CreateUsers email:string password_digest:string

    # here create user.rb with these contents:

    class User < ActiveRecord::Base
      has_secure_password
    end

Let's try this out real quick.

    rails g migration CreateUsers email:string password_digest:string

    # app/models/user.rb
    class User < ActiveRecord::Base
      has_secure_password
    end

    # db/seeds.rb
    user1 = User.create(email: "email@example.com", password: "password", password_confirmation: "password")
    user2 = User.create(email: "another_email@example.com", password: "another_password", password_confirmation: "another_password")

    rake db:create db:migrate db:seed

    rails c

    [2] pry(main)> User.all
      User Load (0.6ms)  SELECT "users".* FROM "users"
    => [#<User:0x007fe5d89d3dc8
      id: 1,
      email: "email@example.com",
      password_digest: "$2a$10$t6M2ZtmemcJxsHQcTv2FYOBste5saPPd.z36/zvd14vW/cgMDsh72">,
     #<User:0x007fe5d89d37b0
      id: 2,
      email: "another_email@example.com",
      password_digest: "$2a$10$ek.8BWzBcQ7lWfgD3PdpVOJFgEEokDoGPbtmpzMqCbreeO8Av1pCa">]

As you can see, when we create a User with a password, the password itself is not stored in the database. A digest of it (given some hash and salt) is stored instead.

# Authentication

Cool. So now we can make new Users, and their passwords are some level of secure. Now, how can we tell if someone puts in a password, and they really are that person?

It's pretty basic. Once the user inputs their password, we need to compare that password to the one in the database - except that the database doesn't have the password in it...just the digest.

Luckily, ActiveRecord models have a method that makes *authenticating* easy. You just have to call `authenticate` on the user object and pass in the password they supplied. Like so:

  user.authenticate('password')

Try that out in your Rails console. If authentication is unsuccessful, then that line will return `false`. If it *is* successful, then the user object will be returned.

    [8] pry(main)> user1.authenticate('password')
    => #<User:0x007fe5da58ad50
     id: 1,
     email: "email@example.com",
     password_digest: "$2a$10$t6M2ZtmemcJxsHQcTv2FYOBste5saPPd.z36/zvd14vW/cgMDsh72">

    [9] pry(main)> user1.authenticate('passw')
    => false

# Sessions

It will be kind of a pain in the ass to have to constantly submit your email and password every time you want to change something in the app. We also want the server to know who we are, so we can see our own stuff.

Here's the thing: HTTP is a *stateless protocol*. It does not keep track of the state that any user is in at any time. The server by default does not know what you did in your last request, and it will immediately forget everything once it's done with your request. You can't keep track of your state as-is.

That means we need a workaround. What we typically do is have the client pass around a variable in its headers, in each request that it sends to the server. This variable will basically say "*this* client is *this* user", so that when the server receives the request, it knows who sent it.

However, passing around the user's credentials around in a header is a really really really fucking stupid idea. It's relatively trivial to capture a user's headers from their request - a black hat can intercept your network when you're blogging from Starbucks and pick out your username, email, password, etc. So don't do that. Instead, we want to pass around a *session*.

A session is a unique ID that:

  * Is passed around in the client's headers
  * Is received by the server
  * Is associated with a specific user in the server's database
  * Is matched up by the server with a user
  * If that works, causes the server to assume that the incoming client request is that of the matching user
  * Tells the server what to render and show to the client
  * Allows for statefulness in the stateless HTTP

Basically, we pass a session variable around in the client's header parameters, look that session up in the server's database by the variable parameter, find the user associated with that session, and then assume that we're now working with that specific user.

In a CRUD/RESTful context, we basically need a Session model. A Session has a unique id (usually a salted hash), and belongs to a User. That allows us to do something like:

    session = Session.create(hash: "sd80f80q3g08fbu0", user: user.authenticate('password'))  # assuming the authentication succeeds
    session_variable = params[:session]  # variable passed around in the request parameters, in this case it'll prolly be 'sd80f80q3g08fbu0'
    found_session = Session.where(session_id: session_variable)  # look up a Session by the id we assigned to session_variable
    logged_in_user = found_session.user  # when we find that Session, assume the client is the User that Session belongs to.
    logged_in_user.posts.create(title: 'etc etc')  # and now we can do stuff with the user, like create new posts, edit comments, etc.