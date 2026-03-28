#!/usr/bin/env nu

use ./lib.nu *


def main [] {
    ensure-layout

    let root = (webdav-root)
    let addr = if ('NOTABILITY_WEBDAV_ADDR' in ($env | columns)) {
        $env.NOTABILITY_WEBDAV_ADDR
    } else {
        '127.0.0.1:9980'
    }
    let user = if ('NOTABILITY_WEBDAV_USER' in ($env | columns)) {
        $env.NOTABILITY_WEBDAV_USER
    } else {
        'notability'
    }
    let baseurl = if ('NOTABILITY_WEBDAV_BASEURL' in ($env | columns)) {
        $env.NOTABILITY_WEBDAV_BASEURL
    } else {
        '/'
    }
    let password_file = if ('NOTABILITY_WEBDAV_PASSWORD_FILE' in ($env | columns)) {
        $env.NOTABILITY_WEBDAV_PASSWORD_FILE
    } else {
        error make {
            msg: 'NOTABILITY_WEBDAV_PASSWORD_FILE is required'
        }
    }
    let password = (open --raw $password_file | str trim)

    print $"Starting WebDAV on ($addr), serving ($root), base URL ($baseurl)"
    run-external rclone 'serve' 'webdav' $root '--addr' $addr '--baseurl' $baseurl '--user' $user '--pass' $password
}
