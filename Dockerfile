##########################################
#         构建可执行二进制文件             #
##########################################
# 指定构建的基础镜像
FROM golang:alpine AS builder

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/v2ray
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=golang
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=alpine
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

ARG BUILD_DEPS="\
      tzdata \
      curl \
      git \
      wget \
      bash"
ENV BUILD_DEPS=$BUILD_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $BUILD_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone

# 运行工作目录
WORKDIR /build
# 克隆源码运行安装
RUN git clone --progress https://github.com/v2fly/v2ray-core.git . && \
    bash ./release/user-package.sh nosource noconf codename=$(git describe --abbrev=0 --tags) buildname=docker-fly abpathtgz=/tmp/v2ray.tgz
# ##############################################################################


##########################################
#         构建基础镜像                    #
##########################################
# 
# 指定创建的基础镜像
FROM alpine:latest

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

ARG PKG_DEPS="\
      zsh \
      iproute2 \
      git \
      vim \
      tzdata \
      curl \
      ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# dumb-init
# https://github.com/Yelp/dumb-init
ARG DUMBINIT_VERSION=1.2.5
ENV DUMBINIT_VERSION=$DUMBINIT_VERSION

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $PKG_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   /bin/zsh
   
	
# 拷贝v2ray二进制文件至临时目录
COPY --from=builder /tmp/v2ray.tgz /tmp

# 授予文件权限
RUN set -eux && \
    mkdir -p /usr/bin/v2ray /etc/v2ray && \
    tar xvfz /tmp/v2ray.tgz -C /usr/bin/v2ray && \
    rm -rf /tmp/v2ray.tgz /usr/bin/v2ray/*.sig /usr/bin/v2ray/doc /usr/bin/v2ray/*.json /usr/bin/v2ray/*.dat /usr/bin/v2ray/sys* && \
    chmod +x /usr/bin/v2ray/v2ray

# 安装dumb-init
RUN set -eux && \
    wget --no-check-certificate https://github.com/Yelp/dumb-init/releases/download/v${DUMBINIT_VERSION}/dumb-init_${DUMBINIT_VERSION}_x86_64 -O /usr/bin/dumb-init && \
    chmod +x /usr/bin/dumb-init

# 拷贝配置文件
COPY conf/v2ray/config.json /etc/v2ray/config.json

# 容器信号处理
STOPSIGNAL SIGQUIT

# 入口
ENTRYPOINT ["dumb-init"]

# 运行v2ray
CMD ["/usr/bin/v2ray/v2ray", "-config=/etc/v2ray/config.json"]
