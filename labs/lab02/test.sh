#!/usr/local/bin/bash

if getent group "wheel" >/dev/null; then
	echo good
fi
echo "$?"
