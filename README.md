PostgreSQL BuildFarm Test Server Recipes
========================================

The first recipe here is for a Vagrant test machine. The server works and
answers queries on port 80. Sample data from the master server is loaded,
but shared secrets and personal information have been removed.

To assign an IP address to the machine, call with BFIP set, like this:

```
BFIP=192.168.10.50 vagrant up
```

If not, a default address is used, which might not be appropriate to your
network.

TODOS:

* add a Docker recipe

