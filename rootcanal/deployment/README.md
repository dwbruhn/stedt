To deploy the STEDT database interface:

* Install MySQL
* Load a STEDT database dump.
* Install this code (see below)
* Resolve all PERL module dependencies

Installing and Updating the database interface code:

```
git clone https://github.com/stedt-project/sss.git
cd sss/rootcanal/deployment
# assuming your target web directory is ~/Sites/rootcanal, on your Mac...
./gitdeploy.sh ~/Sites/rootcanal
cp ../rootcanal.* ~/Sites/rootcanal
# need to configure the app just a little bit...
vi ~/Sites/rootcanal.conf  # edit in your stedt database login/password
vi ~/Sites/rootcanal.pl    # edit @INC ???
```

When you need to update the code:

* Test your changes on your local machine
* Commit them
* Sign in to your production server
* Deploy the changes

```
./gitdeploy.sh ~/Sites/rootcanal
```
