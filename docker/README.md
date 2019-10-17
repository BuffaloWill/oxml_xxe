# Docker Build

This docker build is authored by 0xdevalias (https://github.com/0xdevalias/docker-oxml_xxe), maintained as part of oxml_xxe.

To build the image locally, run the following command:
```
docker build . -t buffalowill/oxml_xxe
```

Once this is done, you can stand up a running instance with this command:
```
docker run --rm -p 4567:4567 buffalowill/oxml_xxe
```

The running instance of the tool can be found at [http://localhost:4567](http://localhost:4567)


## To-do
- add docker-compose
