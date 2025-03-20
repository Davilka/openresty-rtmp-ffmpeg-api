# ----------------------------------------------------------------------------------
# MIT License
#
# Copyright 2023 Shivajee.R.Sharma
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ----------------------------------------------------------------------------------

################
# 1. build API #
################

# Builder image
FROM golang:1.24.1-alpine3.21 AS builder
WORKDIR /work

# enable gin gonic relase mode
ENV GIN_MODE=release

# install required packages
RUN apk add --no-cache git

# add files
ADD api/ .

# Get go modules
RUN \ 
  go get github.com/gin-contrib/sse \
  && go get github.com/golang/protobuf/proto \
  && go get github.com/ugorji/go/codec \
  && go get gopkg.in/go-playground/validator.v8 \
  && go get gopkg.in/yaml.v2 \
  && go get github.com/mattn/go-isatty
# update all modules
RUN go get -u

# compile app static
RUN \
  CGO_ENABLED=0 \
  GOOS=linux \
  GOARCH=amd64 \
  go build -a -installsuffix cgo -ldflags="-w -s" -o go-rtmp-api .

#FROM openresty/openresty:alpine
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04 AS cuda-builder
LABEL maintainer="Davilka: davilka1@gmail.com"

#######################
# Environment variables
ENV HLS_DIR="/tmp/data/hls"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Prepare data directory
RUN mkdir -p /tmp/data/{hls,dash} \
    && mkdir -p /www

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

########################
# Docker Build Arguments
ARG BUILD_DATE
ARG NGINX_RTMP_VERSION="1.2.2"

ARG RESTY_VERSION="1.27.1.1"
ARG RESTY_OPENSSL_VERSION="3.0.16"
ARG RESTY_PCRE_VERSION="8.45"
ARG RESTY_LUAROCKS_VERSION="3.11.1"
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG RESTY_J=16
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-mail \
    --with-mail_ssl_module \
    --with-pcre-jit \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    --with-debug \
    "
    
# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} --with-pcre"

ARG FFMPEG_VERSION="7.1.1"
ARG FFMPEG_CONFIG_OPTIONS="\
    --disable-debug \
    --disable-doc \ 
    --disable-ffplay \ 
    --enable-cuda-nvcc \
    --enable-gnutls \
    --enable-gpl \
    --enable-libass \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libnpp \
    --enable-libopus \
    #--enable-librtmp \
    --enable-libtheora \
    --enable-libfdk-aac \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-nonfree \
    --enable-postproc \
    --enable-small \
    --enable-version3 \
    --enable-avfilter \
    --enable-libxvid \
    #--enable-libv4l2 \
    --enable-pic \
    --enable-shared \
    --enable-vaapi \
    --enable-pthreads \
    --disable-stripping \
    --disable-static \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 \
    "
    
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.name="openresty-rtmp-ffmpeg-api"
LABEL org.label-schema.description="nginx-rtmp for streaming, including ffmpeg and videojs for playback."

#####################################################
# Build steps
# 1) Install dependencies
# 2) Download and untar OpenSSL, LuaRocks, ffmpeg, nginx-rtmp, PCRE, and OpenResty
# 3) Build OpenResty with nginx-rtmp-module
# 4) Build LuaRocks
# 5) Build ffmpeg
# 6) Cleanup
RUN apt-get update && apt-get full-upgrade -y \
    && apt-get install  -y --no-install-recommends \
    bash \
    build-essential \
    cmake \
    curl \
    gettext-base \
    git \
    gstreamer1.0-vaapi \
    libnvidia-encode-570-server \
    libass-dev \
    libc6 \
    libc6-dev \
    libfdk-aac-dev \
    libfreetype6-dev \
    libgd-dev \
    libgeoip-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libnuma-dev \
    libnuma1 \
    libogg-dev \
    libopus-dev \
    libpcre3-dev \
    librtmp-dev \
    libssh2-1-dev \
    libtheora-dev \
    libtool \
    libva-dev \
    libvorbis-dev \
    libvpx-dev \
    libwebp-dev \
    libx264-dev \
    libx265-dev \
    libxslt1-dev \
    libxvidcore-dev \
    perl \
    supervisor \
    unzip \
    #v4l-utils \
    wget \
    nasm \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \    
    #&& curl -fSL https://luarocks.org/releases/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && curl -fSL http://172.17.0.1:8081/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && curl -fSL https://github.com/arut/nginx-rtmp-module/archive/v$NGINX_RTMP_VERSION.tar.gz -o nginx-rtmp-module.tar.gz \
    && tar xzf nginx-rtmp-module.tar.gz \
    && curl -fSL https://sourceforge.net/projects/pcre/files/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    #&& curl -sL https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz -o ffmpeg.tar.gz \
    #&& curl -sL http://172.17.0.1:8081/ffmpeg-${FFMPEG_VERSION}.tar.gz -o ffmpeg.tar.gz \
    #&& tar xzf ffmpeg.tar.gz \
    && git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg \
    && curl -fSL http://172.17.0.1:8081/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install 
RUN cd /tmp/luarocks-${RESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
#        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build \
    && make install
# Clone and install ffnvcodec
RUN cd /tmp \
    && git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git \
    && cd nv-codec-headers \
    && make install
RUN cd /tmp/ffmpeg \
          && PATH="/usr/bin:$PATH" \
	  && ./configure --prefix=/usr --bindir="/usr/bin" ${FFMPEG_CONFIG_OPTIONS} \
	  && make -j$(getconf _NPROCESSORS_ONLN) \
	  && make install \
	  && make distclean \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
        nginx-rtmp-module-${NGINX_RTMP_VERSION} \
        nginx-rtmp-module.tar.gz \
        FFmpeg-n${FFMPEG_VERSION} ffmpeg.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre2-${RESTY_PCRE_VERSION} \
	nv-codec-headers
#RUN cd /
#    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
#    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log 
# Add LuaRocks paths
# If OpenResty changes, these may need updating:
#    /usr/local/openresty/bin/resty -e 'print(package.path)'
#    /usr/local/openresty/bin/resty -e 'print(package.cpath)'
ENV LUA_PATH="/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua"
ENV LUA_CPATH="/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so"

# Copy nginx configuration files and sample page
ADD etc/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
ADD html /www/html
ADD static /www/static

EXPOSE 8080 1935
STOPSIGNAL SIGTERM

# Copy api and config
COPY --from=builder /work/go-rtmp-api /

# setup cron; see clean-hls-dir.sh for more information
# COPY clean-hls-dir.sh /clean-hls-dir.sh
# RUN chmod +x /clean-hls-dir.sh

# COPY etc/cron.d/clean-hls-dir /etc/cron.d/clean-hls-dir
# Give execution rights on the cron job
# RUN chmod 0644 /etc/cron.d/clean-hls-dir
# Apply cron job
# RUN crontab /etc/cron.d/clean-hls-dir

ADD etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
#CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]

