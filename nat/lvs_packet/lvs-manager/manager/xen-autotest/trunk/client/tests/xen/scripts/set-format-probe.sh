#!/bin/sh

val=$1

if [ "$val" != yes -a "$val" != no ]; then
  echo "usage: $0 yes|no"
  exit 1
fi

sed -i '/^.*(enable-image-format-probing .*$/s/.*/(enable-image-format-probing '$val')/' /etc/xen/xend-config.sxp

/etc/init.d/xend restart
