FROM debian:buster-20211011

RUN apt-get update && apt-get -y install build-essential \
                                 git \
                                 wget \
                                 libdrm-dev \
                                 python3 \
                                 python3-pip \
                                 python3-setuptools \
                                 python3-wheel \
                                 ninja-build \
                                 libopenal-dev \
                                 premake4 \
                                 autoconf \
                                 libevdev-dev \
                                 ffmpeg \
                                 libsnappy-dev \
                                 libboost-tools-dev \
                                 magics++ \
                                 libboost-thread-dev \
                                 libboost-all-dev \
                                 pkg-config \
                                 zlib1g-dev \
                                 libpng-dev \
                                 libsdl2-dev \
                                 clang \
                                 cmake \
                                 cmake-data \
                                 libarchive13 \
                                 libcurl4 \
                                 libfreetype6-dev \
                                 libjsoncpp1 \
                                 librhash0 \
                                 libuv1 \
                                 mercurial \
                                 mercurial-common \
                                 libgbm-dev \
                                 libsdl2-ttf-2.0-0 \
                                 libsdl2-ttf-dev \
                                 ccache \
                                 libpsl5 \
                                 libpcre2-8-0 \
                                 zip 

# Copy the build scripts so they can be run in the container if desired
COPY build ../
COPY portmaster/ ../portmaster/
WORKDIR ../
RUN USE_DOCKER=false ./build portmaster