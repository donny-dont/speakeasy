![Logo](speakeasy.png "Speakeasy")
> A private pub server for Dart

[![Build Status](http://beta.drone.io/api/badges/donny-dont/speakeasy/status.svg)](http://beta.drone.io/donny-dont/speakeasy)

## Installing
TODO

## Use cases
1. Use private packages.
   
    Allows you to use the pub package system in your company without exposing code to the public, and use your private packages just as easily as public ones.

2. Cache pub.dartlang.org.
   
    Reduces latency to users. Packages are cached from pub.dartlang.org and are available as long as the server is running ensuring reliability for CI systems.

## Inspiration
Speakeasy was inspired by [Sinopia](https://github.com/rlidwka/sinopia) a private npm server and contains a similar configuration process.
