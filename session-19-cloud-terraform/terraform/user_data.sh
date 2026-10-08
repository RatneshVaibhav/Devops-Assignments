#!/bin/bash
# Runs once at first boot: install nginx and publish the page stored in S3.
dnf install -y nginx
aws s3 cp "s3://${bucket}/site/index.html" /usr/share/nginx/html/index.html
systemctl enable --now nginx
