Wagon-Erpify
============

The power of OpenERP Liquid drops via erpify https://github.com/akretion/erpify in your local LocomotiveCMS site developed with Wagon.

Make sure you understand Wagon first:

* http://doc.locomotivecms.com/get-started/install-wagon
* http://doc.locomotivecms.com/get-started/create-your-first-site
* http://doc.locomotivecms.com/get-started/deployment


example usage:

in the website you develop locally with Wagon, edit your Gemfile to add the wagon-erpify gem and also possibly its dependencies that aren't released yet (grab them with git locally first):

```ruby
group :misc do
  gem 'faraday', git: 'https://github.com/lostisland/faraday.git' #you may need last version to avoid a dependency conflict
  gem 'ooor', path: '../../ooor'
  gem 'erpify', path: '../../erpify'
  gem 'wagon-erpify', path: '../../wagon-erpify'
  # Add your extra gems here
  # gem 'susy', require: 'susy'
  # gem 'redcarpet', require: 'redcarpet'
end
```

Now, create an OOOR configuration for public objects that will be proxied to some running OpenERP instance.
Warning! use some specific portal user, never admin user in production!
But here it's just for a local demo, so yoru config could be inside your website folder: config/ooor.yml with the following content for instance:

```
development:
  url: http://localhost:8069
  database: test
  username: admin
  password: admin
```

Then just serve your website locally:

```
bundle exec wagon serve
```

Now, inside a page template, you can use erpify tags and drops, such as:

```
          {% with_domain type:'service' %}
          {% for product in ooor_public_model['product.product'] %}
          {{product.name}} - {{product.categ_id.name}}
          {% endfor %}
          {% endwith_domain %}
```


