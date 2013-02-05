cloud-kitchen
=============

A chef-repo for forming clouds to produce snow-flakes.

Easing creation of Openstack, Virtualbox, and Linux Container model/base images.

model-images can then be created and cloned locally for testing and eventually uploaded to various cloud providers.

```
git clone git@github.com:hh/cloud-kitchen.git
bundle install
bundle exec chef-solo -c .chef/create-usb-solo.rb