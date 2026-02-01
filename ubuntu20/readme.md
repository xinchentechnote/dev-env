build image
```shell
docker build --no-cache \
  -f Dockerfile \ssh
  -t fin-proto-cpp-dev \
  --build-arg USERNAME=xinchen \
  --build-arg PASSWORD=xinchen \
  .
```

run container
```shell
docker run -d --name fin-proto-cpp -p 2222:22 -v ~/workspace/fin-proto-cpp:/workspace/fin-proto-cpp --restart unless-stopped fin-proto-cpp-dev
```


