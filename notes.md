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