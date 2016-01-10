# Arukas
A static blog build on mithril.js
# WTF?
The difference of other static blog is all data is json and render in frontend by mithril.js
I used to be an Hexo user,so somethings such as theme [Light](https://github.com/hexojs/hexo-theme-light) are from [Hexo](https://github.com/hexojs/hexo)
# Installation
```
$ git clone git@github.com:Eronana/Arukas.git
$ cd Arukas
$ npm install
```
# How to use
## Create new post
```
$ coffee arukas.coffee new "Hello Arukas!"
```
## Generate blog
```
$ coffee arukas.coffee gen
```
## Start server to preview
```
$ coffee arukas.coffee server
```
## Deploy
Upload all file in deploy to your web server by yourself
# License
MIT