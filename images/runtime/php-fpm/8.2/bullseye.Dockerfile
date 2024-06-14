ARG BASE_IMAGE

# Startup script generator
FROM mcr.microsoft.com/oss/go/microsoft/golang:1.20-bullseye as startupCmdGen

# GOPATH is set to "/go" in the base image
WORKDIR /go/src
COPY src/startupscriptgenerator/src .
ARG GIT_COMMIT=unspecified
ARG BUILD_NUMBER=unspecified
ARG RELEASE_TAG_NAME=unspecified
ENV RELEASE_TAG_NAME=${RELEASE_TAG_NAME}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV BUILD_NUMBER=${BUILD_NUMBER}
RUN chmod +x build.sh && ./build.sh php /opt/startupcmdgen/startupcmdgen

# From https://github.com/docker-library/php.git
FROM ${BASE_IMAGE}
ARG IMAGES_DIR=/tmp/oryx/images

# do NOT merge this content with above line because the 
# above line is shared across all php images
# Install the Microsoft SQL Server PDO driver on supported versions only.
#  - https://docs.microsoft.com/en-us/sql/connect/php/installation-tutorial-linux-mac
#  - https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server
RUN set -eux \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		gnupg2 \
		apt-transport-https \
	&& curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
	&& curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
	&& apt-get update \
	&& ACCEPT_EULA=Y apt-get install -y msodbcsql17 msodbcsql18=18.1.2.1-1 odbcinst1debian2=2.3.7 odbcinst=2.3.7 unixodbc=2.3.7 unixodbc-dev=2.3.7

ENV PHP_INI_DIR /usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html

##<autogenerated>##
ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --disable-cgi ac_cv_func_mmap=no
##</autogenerated>##

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS 1198C0117593497A5EC5C199286AF1F9897469DC 39B641343D8C104B2B146DC3F9C39DC0B9698544 E60913E4DF209907D8E30D96659A97C9CF2A795A

ENV PHP_VERSION 8.2.20
ENV PHP_URL="https://www.php.net/get/php-8.2.20.tar.xz/from/this/mirror" PHP_ASC_URL="https://www.php.net/get/php-8.2.20.tar.xz.asc/from/this/mirror"
ENV PHP_SHA256="4474cc430febef6de7be958f2c37253e5524d5c5331a7e1765cd2d2234881e50" PHP_MD5=""

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends gnupg dirmngr; \
	rm -rf /var/lib/apt/lists/*; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	if [ -n "$PHP_SHA256" ]; then \
		echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	fi; \
	if [ -n "$PHP_MD5" ]; then \
		echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
	fi; \
	\
	if [ -n "$PHP_ASC_URL" ]; then \
		curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
		export GNUPGHOME="$(mktemp -d)"; \
		${IMAGES_DIR}/receiveGpgKeys.sh $GPG_KEYS; \
		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
		gpgconf --kill all; \
		rm -rf "$GNUPGHOME"; \
	fi; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

COPY images/runtime/php-fpm/8.2/docker-php-source /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-source

RUN set -eux; \
	\
	
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libargon2-dev \
		libcurl4-openssl-dev \
		libedit-dev \
		libonig-dev \
		libsodium-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		zlib1g-dev \
		${PHP_EXTRA_BUILD_DEPS:-} \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
	; \
	#which docker-php-source; \
	awk '{ sub("\r$", ""); print }' /usr/local/bin/docker-php-source > /usr/local/bin/docker-php-source_new; \
	cat /usr/local/bin/docker-php-source_new; \
	chmod +x /usr/local/bin/docker-php-source_new ; \
	docker-php-source_new extract; \
	ls -l /usr/src/; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
# https://bugs.php.net/bug.php?id=74125
	if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi; \
	./configure \
		--build="$gnuArch" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		\
# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear") and will be removed in PHP 8+; see also https://github.com/docker-library/php/issues/846#issuecomment-505638494
		--with-pear \
		\
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
		$(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
		--with-libdir="lib/$debMultiarch" \
		\
		${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
	make clean; \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source_new delete; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
# smoke test
	php --version

COPY images/runtime/php-fpm/8.2/docker-php-ext-* images/runtime/php-fpm/8.2/docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-ext-*
RUN chmod +x /usr/local/bin/docker-php-entrypoint

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
RUN docker-php-ext-enable sodium

ENTRYPOINT ["docker-php-entrypoint"]
##<autogenerated>##
WORKDIR /var/www/html

RUN set -eux; \
	cd /usr/local/etc; \
	if [ -d php-fpm.d ]; then \
		# for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
		sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
		cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
	else \
		# PHP 5.x doesn't use "include=" by default, so we'll create our own simple config that mimics PHP 7+ for consistency
		mkdir php-fpm.d; \
		cp php-fpm.conf.default php-fpm.d/www.conf; \
		{ \
			echo '[global]'; \
			echo 'include=etc/php-fpm.d/*.conf'; \
		} | tee php-fpm.conf; \
	fi; \
	{ \
		echo '[global]'; \
		echo 'error_log = /proc/self/fd/2'; \
		echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
		echo; \
		echo '[www]'; \
		echo '; if we send this to /proc/self/fd/1, it never appears'; \
		echo 'access.log = /proc/self/fd/2'; \
		echo; \
		echo 'clear_env = no'; \
		echo; \
		echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
		echo 'catch_workers_output = yes'; \
		echo 'decorate_workers_output = no'; \
	} | tee php-fpm.d/docker.conf; \
	{ \
		echo '[global]'; \
		echo 'daemonize = no'; \
		echo; \
		echo '[www]'; \
		echo 'listen = 9000'; \
	} | tee php-fpm.d/zz-docker.conf

RUN rm -rf /var/lib/apt/lists/*

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]
##</autogenerated>##

## base dockerfile
SHELL ["/bin/bash", "-c"]

ARG PHP_VERSION
ENV PHP_VERSION ${PHP_VERSION}

# An environment variable for oryx run-script to know the origin of php image so that
# start-up command can be determined while creating run script
ENV PHP_ORIGIN php-fpm
ENV NGINX_RUN_USER www-data
# Edit the default DocumentRoot setting
ENV NGINX_DOCUMENT_ROOT /home/site/wwwroot
# Install NGINX latest stable version using APT Method with Nginx Repository instead of distribution-provided one:
# - https://www.linuxcapable.com/how-to-install-latest-nginx-mainline-or-stable-on-debian-11/
RUN apt-get update
RUN apt install curl nano -y
RUN curl -sSL https://packages.sury.org/nginx/README.txt | bash -x
RUN apt-get update
RUN yes '' | apt-get install nginx-core nginx-common nginx nginx-full -y
RUN ls -l /etc/nginx
COPY images/runtime/php-fpm/nginx_conf/default.conf /etc/nginx/sites-available/default
COPY images/runtime/php-fpm/nginx_conf/default.conf /etc/nginx/sites-enabled/default
RUN sed -ri -e 's!worker_connections 768!worker_connections 10068!g' /etc/nginx/nginx.conf
RUN sed -ri -e 's!# multi_accept on!multi_accept on!g' /etc/nginx/nginx.conf
RUN ls -l /etc/nginx
RUN nginx -t
# Edit the default port setting
ENV NGINX_PORT 8080

# Install common PHP extensions
# TEMPORARY: Holding odbc related packages from upgrading.
RUN apt-mark hold msodbcsql18 odbcinst1debian2 odbcinst unixodbc unixodbc-dev \
    && apt-get update \
    && apt-get upgrade -y \
    && ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so \
    && ln -s /usr/lib/x86_64-linux-gnu/liblber.so /usr/lib/liblber.so \
    && ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

RUN set -eux; \
    if [[ $PHP_VERSION == 7.4.* || $PHP_VERSION == 8.0.* || $PHP_VERSION == 8.1.*  || $PHP_VERSION == 8.2.* || $PHP_VERSION == 8.3.* ]]; then \
		apt-get update \
        && apt-get upgrade -y \
        && apt-get install -y --no-install-recommends apache2-dev \
        && docker-php-ext-configure gd --with-freetype --with-jpeg \
        && PHP_OPENSSL=yes docker-php-ext-configure imap --with-kerberos --with-imap-ssl ; \
    else \
		docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
        && docker-php-ext-configure imap --with-kerberos --with-imap-ssl ; \
    fi

RUN docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr \
    && docker-php-ext-install gd \
        mysqli \
        opcache \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        ldap \
        intl \
        gmp \
        zip \
        bcmath \
        mbstring \
        pcntl \
        calendar \
        exif \
        gettext \
        imap \
        tidy \
        shmop \
        soap \
        sockets \
        sysvmsg \
        sysvsem \
        sysvshm \
        pdo_odbc \
# deprecated from 7.4, so should be avoided in general template for all php versions
#        xmlrpc \
        xsl
RUN pecl install redis && docker-php-ext-enable redis

# https://github.com/Imagick/imagick/issues/331
# https://github.com/ihneo/php/pull/24/files
RUN set -eux; \	
    if [[ $PHP_VERSION != 8.3.* ]]; then \
        pecl install imagick && docker-php-ext-enable imagick; \
    fi
        
# deprecated from 5.*, so should be avoided 	
RUN set -eux; \	
    if [[ $PHP_VERSION != 5.* && $PHP_VERSION != 7.0.* ]]; then \	
        pecl install mongodb && docker-php-ext-enable mongodb; \	
    fi	

# https://github.com/microsoft/mysqlnd_azure, Supports  7.2*, 7.3* and 7.4*
RUN set -eux; \
    if [[ $PHP_VERSION == 7.2.* || $PHP_VERSION == 7.3.* || $PHP_VERSION == 7.4.* ]]; then \
        echo "pecl/mysqlnd_azure requires PHP (version >= 7.2.*, version <= 7.99.99)"; \
        pecl install mysqlnd_azure \
        && docker-php-ext-enable mysqlnd_azure; \
    fi

# Install the Microsoft SQL Server PDO driver on supported versions only.
#  - https://docs.microsoft.com/en-us/sql/connect/php/installation-tutorial-linux-mac
#  - https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server
# For php|8.0, latest stable version of pecl/sqlsrv, pecl/pdo_sqlsrv is 5.11.0
RUN set -eux; \
    if [[ $PHP_VERSION == 8.0.* ]]; then \
        pecl install sqlsrv-5.11.0 pdo_sqlsrv-5.11.0 \
        && echo extension=pdo_sqlsrv.so >> $(php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||")/30-pdo_sqlsrv.ini \
        && echo extension=sqlsrv.so >> $(php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||")/20-sqlsrv.ini; \
    fi

# Latest pecl/sqlsrv, pecl/pdo_sqlsrv requires PHP (version >= 8.1.0)
RUN set -eux; \
    if [[ $PHP_VERSION == 8.1.* || $PHP_VERSION == 8.2.* || $PHP_VERSION == 8.3.* ]]; then \
        pecl install sqlsrv pdo_sqlsrv \
        && echo extension=pdo_sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/30-pdo_sqlsrv.ini \
        && echo extension=sqlsrv.so >> `php --ini | grep "Scan for additional .ini files" | sed -e "s|.*:\s*||"`/20-sqlsrv.ini; \
    fi


RUN { \
                echo 'opcache.memory_consumption=128'; \
                echo 'opcache.interned_strings_buffer=8'; \
                echo 'opcache.max_accelerated_files=4000'; \
                echo 'opcache.revalidate_freq=60'; \
                echo 'opcache.fast_shutdown=1'; \
                echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# NOTE: zend_extension=opcache is already configured via docker-php-ext-install, above
RUN { \
                echo 'error_log=/var/log/apache2/php-error.log'; \
                echo 'display_errors=Off'; \
                echo 'log_errors=On'; \
                echo 'display_startup_errors=Off'; \
                echo 'date.timezone=UTC'; \
    } > /usr/local/etc/php/conf.d/php.ini

RUN set -x \
    && docker-php-source extract \
    && cd /usr/src/php/ext/odbc \
    && phpize \
    && sed -ri 's@^ *test +"\$PHP_.*" *= *"no" *&& *PHP_.*=yes *$@#&@g' configure \
    && chmod +x ./configure \
    && ./configure --with-unixODBC=shared,/usr \
    && docker-php-ext-install odbc \
    && rm -rf /var/lib/apt/lists/*

ENV LANG="C.UTF-8" \
    LANGUAGE="C.UTF-8" \
    LC_ALL="C.UTF-8"

# Bake Application Insights key from pipeline variable into final image
ARG AI_CONNECTION_STRING
ENV ORYX_AI_CONNECTION_STRING=${AI_CONNECTION_STRING}

# Oryx++ Builder variables
ENV CNB_STACK_ID="oryx.stacks.skeleton"
LABEL io.buildpacks.stack.id="oryx.stacks.skeleton"

COPY --from=startupCmdGen /opt/startupcmdgen/startupcmdgen /opt/startupcmdgen/startupcmdgen
RUN ln -s /opt/startupcmdgen/startupcmdgen /usr/local/bin/oryx

ENV LANG="C.UTF-8" \
    LANGUAGE="C.UTF-8" \
    LC_ALL="C.UTF-8"