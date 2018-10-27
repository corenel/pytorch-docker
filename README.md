# PyTorch-docker
## Build

```shell
docker build -t corenel/pytorch:cu90 /path/to/build
```

## Usage

1. Pull the image:
```
docker pull corenel/pytorch:cu90
```

2. Run commands
```
docker run --rm -it --init \
  --runtime=nvidia \
  --ipc=host \
  --user="$(id -u):$(id -g)" \
  --volume=$PWD:/app/code \
  -e LC_ALL=C.UTF-8 \
  -e LANG=C.UTF-8 \
  corenel/pytorch:cu90 [command to run]
```

> - Replace `corenel/pytorch:cu90` with image you want to run
> - Use `--volume/-v` to map directories from hsot to docker container

## Acknowledgement

- [docker-pytorch](https://github.com/anibali/docker-pytorch)
- [uber/horovod](https://github.com/uber/horovod)
