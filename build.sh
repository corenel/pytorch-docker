#!/bin/bash
docker build -t corenel/pytorch:cu90-pytorch1.0.0  -f Dockerfile .
docker build -t corenel/pytorch:cu90-pytorch-nightly -f Dockerfile --build-arg BUILD_NIGHTLY=true .
