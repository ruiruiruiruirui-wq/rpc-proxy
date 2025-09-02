FROM openresty/openresty:1.21.4.1-0-bullseye-fat

# 设置工作目录
WORKDIR /etc/nginx

RUN mkdir -p /etc/nginx/logs && \
    chmod 755 /etc/nginx/logs

# 安装运维工具和调试工具
RUN apt-get update && \
    apt-get install -y \
    curl \
    tcpdump \
    iputils-ping \
    telnet \
    net-tools \
    tree \
    vim \
    procps \
    htop \
    lsof \
    nano \
    wget \
    dnsutils \
    luarocks \
    apache2-utils \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 拷贝配置文件到容器内
COPY conf.d /etc/nginx/conf.d
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY rpc-proxy /usr/local/openresty/lualib/rpc-proxy
COPY proxy_scripts /usr/local/openresty/lualib/proxy_scripts

RUN ln -s /usr/local/openresty/nginx/conf/nginx.conf /etc/nginx/nginx.conf && \
    ln -s /usr/local/openresty/lualib /etc/nginx/lualib
RUN luarocks install nginx-lua-prometheus && \
    luarocks install lua-resty-http && \
    luarocks install luasocket && \
    luarocks install lua-resty-openssl

CMD /usr/local/openresty/nginx/sbin/nginx -g 'daemon off;' -c /usr/local/openresty/nginx/conf/nginx.conf
