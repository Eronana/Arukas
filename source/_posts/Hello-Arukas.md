title: Hello Arukas!
categories: Arukas
date: 2016-01-10 02:20:17
tags: Arukas
---
# Arukas
A static blog build on mithril.js
# WTF?
The difference of other static blog is all data is json and render in frontend by mithril.js
I used to be an Hexo user,so somethings such as theme [Light](https://github.com/hexojs/hexo-theme-light) are from [Hexo](https://github.com/hexojs/hexo)
# Installation
```bash
$ git clone git@github.com:Eronana/Arukas.git
$ cd Arukas
$ npm install
```
# How to use
## Create new post
```bash
$ coffee arukas.coffee new "Hello Arukas!"
```
## Generate blog
```bash
$ coffee arukas.coffee gen
```
## Start server to preview
```bash
$ coffee arukas.coffee server
```
## Deploy
```bash
$ coffee arukas.coffee deploy
```
## Shortcut
```bash
#$ coffee arukas.coffee gen
#$ coffee arukas.coffee server
$ coffee arukas.coffee gs
```
```bash
#$ coffee arukas.coffee gen
#$ coffee arukas.coffee deploy
$ coffee arukas.coffee gd
```
# License
MIT