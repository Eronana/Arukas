fs=require 'fs'
yaml=require 'yamljs'
marked=require 'marked'
highlight=require './lib/highlight.js'
moment=require 'moment'
rimraf=require 'rimraf'
copyDir=require 'copy-dir'
coffee=require 'coffee-script'
UglifyJS=require 'uglify-js'
http=require 'http'
url=require 'url'
path=require 'path'
spawn=require('child_process').spawnSync
unless fs.existsSync 'config.yml' then copyDir.sync 'template/init','.'
config=yaml.load('config.yml')
lang_map={
    'C#':'cs'
    'C++11':'cpp'
    'text':'json'
}
renderer=new marked.Renderer
renderer.code=(code,lang)->
    if lang?
        html=highlight.highlight(lang_map[lang] ? lang,code).value
        return "<pre class=\"hljs\"><code class=\"hljs #{lang}\">#{html}</code></pre>"
    else
        html=code.replace(/</g, '&lt;').replace(/>/g, '&gt;')
        return "<pre><code>#{html}</code></pre>"

marked.setOptions {
    breaks:true
    renderer
}
getnow=->moment().format 'YYYY-MM-DD HH:ss:mm'
sanitize=(s)->s.replace(/[\~\!\@\#\$\%\^\&\*\(\)\_\+\=\-\`\[\]\\\|\}\{\;\'\:\"\,\.\/\?\>\<\s]/mg,' ').trim().replace(/\s+/mg,'-')
posts_dir='source/_posts/'
parse_post=(filename)->
    s=/([^]*?)---([^]*)$/mg.exec fs.readFileSync(posts_dir+filename)
    if s?.length!=3 then return false
    {1:post_config,2:content}=s
    ret=yaml.parse post_config
    for x in ['categories','tags'] then if ret[x]? and not (ret[x] instanceof Array) then ret[x]=[ret[x]]
    ret.content=marked content
    ret.url=filename[0...-3]
    excerpts=ret.content.split(/<!--\s*more\s*-->/)
    if excerpts.length>1 then ret.excerpt=excerpts[0]
    return ret
xpush=(o,p,d)->
    unless o[p]? then o[p]=[]
    o[p].push d

write_page=(data,name,per_page,fn)->
    for i in [0..parseInt(data.length/config.per_page)]
        datas=data[i*per_page...(i+1)*per_page].map (x)->fn(x)
        fs.writeFileSync "#{name}#{i+1}.json",JSON.stringify datas
get_excerpt=(post)->{
    title:post.title
    date:post.date
    url:post.url
    isexcerpt:post.excerpt?
    content:post.excerpt ? post.content
}
String.prototype.capitalize=->this[0].toUpperCase()+this[1..]
git=(cmd...)->
    ret=spawn("git",cmd,{cwd:'deploy'})
    stdout=ret.stdout.toString()
    unless stdout is '' then console.log stdout
    ret.status is 0

deploy=->
    git('add','-A') and
    git('commit','-am',"\"Update on:#{getnow()}\"") and
    git('push','-u',config.deploy.repo,"HEAD:#{config.deploy.branch}",'--force')

clear_dir=->
    if fs.existsSync 'deploy'
        for f in fs.readdirSync 'deploy'
            unless f is '.git' then rimraf.sync "deploy/#{f}"
    else
        fs.mkdirSync 'deploy'
        git 'init'
    copyDir.sync 'frontend','deploy'
    copyDir.sync 'source','deploy',(s,p,f)->f!='_posts' and f!='.git'
    fs.mkdirSync 'deploy/data'
    fs.mkdirSync 'deploy/data/post'
    fs.mkdirSync 'deploy/data/page'
    fs.mkdirSync 'deploy/data/categories'
    fs.mkdirSync 'deploy/data/tags'
gen_js=(StaticData)->
    cs=fs.readFileSync('template/arukas.coffee').toString()
    cs=cs.replace('{{StaticData}}',JSON.stringify(StaticData)).replace('{{config}}',JSON.stringify(config.site))
    UglifyJS.minify(coffee.compile(cs),{fromString:true}).code
gen_html=()->
    html=fs.readFileSync('template/index.html').toString()
    head_script=''
    if config.site.duoshuo_short_name? then head_script+="var duoshuoQuery={short_name:'#{config.site.duoshuo_short_name}'};"
    html.replace '{{head_script}}',head_script
gen=->
    posts=[]
    xstatics={
        categories:{}
        tags:{}
        categories_url:{}
        tags_url:{}
        url_categories:{}
        url_tags:{}
    }
    for f in fs.readdirSync posts_dir
        p=parse_post f
        unless p
            console.log "Error on file:#{f}"
            continue
        console.log "Process post:#{f}"
        posts.push p
        for x in ['categories','tags'] then p[x]?.map (y)->
            xpush xstatics[x],y,p
            xurl=sanitize y
            if xurl in xstatics[x]
                id=1
                while "#{xurl}-#{id}" in x[2] then id++
                xurl="#{xurl}-#{id}"
            xstatics["#{x}_url"][y]=xurl
            xstatics["url_#{x}"][xurl]=y
    console.log "Process StaticData..."
    posts.sort (a,b)->if a.date>b.date then -1 else 1
    for i in [0...posts.length-1] then posts[i].next=posts[i+1].url
    for i in [1...posts.length] then posts[i].prev=posts[i-1].url
    StaticData={Recents:posts[0...config.recents].map (post)->{title:post.title,url:post.url}}
    for x in ['categories','tags']
        StaticData["url_#{x}"]=xstatics["url_#{x}"]
        StaticData["#{x}_url"]=xstatics["#{x}_url"]
        StaticData[x.capitalize()]=(for k,v of xstatics[x] then {name:k,count:v.length}).sort (a,b)->if a.name<b.name then -1 else 1
    console.log "Clear directory"
    clear_dir()
    console.log "write arukas.js"
    fs.writeFileSync 'deploy/js/arukas.js',gen_js StaticData
    console.log "write index.html"
    fs.writeFileSync 'deploy/index.html',gen_html()
    console.log "write pages"
    write_page posts,'deploy/data/page/',config.per_page,get_excerpt
    console.log "write posts"
    for p in posts then fs.writeFileSync "deploy/data/post/#{p.url}.json",JSON.stringify(p)
    for name in ['categories','tags']
        console.log "write #{name}"
        data=xstatics[name]
        for k,v of data
            xurl=xstatics["#{name}_url"][k]
            dir="deploy/data/#{name}/#{xurl}/"
            unless fs.existsSync dir then fs.mkdirSync dir
            v.sort (a,b)->if a.date>b.date then -1 else 1
            write_page v,dir,config.per_page,get_excerpt

get_filename=(title)->
    file="#{posts_dir}#{title}.md"
    unless fs.existsSync file then return file
    tno=title.match /-\d+$/
    tno=if tno then parseInt(tno)-1 else '-1'
    get_filename title+tno

newpost=(title)->
    filename=get_filename(sanitize title)
    fs.writeFileSync filename,fs.readFileSync('template/post.md').toString().replace('{{title}}',title).replace('{{date}}',getnow())
    filename

server=->
    mine={
      "css":"text/css"
      "gif":"image/gif"
      "html":"text/html"
      "ico":"image/x-icon"
      "jpeg":"image/jpeg"
      "jpg":"image/jpeg"
      "js":"text/javascript"
      "coffee":"text/javascript"
      "json":"application/json"
      "pdf":"application/pdf"
      "png":"image/png"
      "svg":"image/svg+xml"
      "swf":"application/x-shockwave-flash"
      "tiff":"image/tiff"
      "txt":"text/plain"
      "wav":"audio/x-wav"
      "wma":"audio/x-ms-wma"
      "wmv":"video/x-ms-wmv"
      "xml":"text/xml"
    }
    server=http.createServer (req,res)->
        pathname=decodeURI(url.parse(req.url).pathname)
        console.log "Request:#{pathname}"
        if pathname is '/' then pathname='index.html'
        pathname='deploy/'+pathname
        ext=path.extname(pathname)[1..]
        fs.exists pathname,(exists)->
            unless exists then pathname='deploy/index.html'
            fs.readFile pathname, "binary",(err,file)->
                if err
                    res.writeHead 500,{'Content-Type':'text/plain'}
                    res.end err.toString()
                else 
                    contentType=mine[ext] ? "text/html"
                    res.writeHead 200,{'Content-Type':contentType}
                    try
                        res.write file,'binary'
                        res.end()
                    catch err
                        res.writeHead 500, {'Content-Type':'text/plain'}
                        res.end err.toString()
    PORT=3000
    server.listen PORT
    console.log "Server runing at port: #{PORT}."
switch process.argv[2]
    when 'new' then console.log newpost(process.argv[3])
    when 'gen' then gen()
    when 'server' then server()
    when 'deploy' then deploy()
    when 'gs'
        gen()
        server()
    when 'gd'
        gen()
        deploy()
    else
        console.log "No this option: #{process.argv[2]}"
        console.log '''Usage:
        coffee arukas.coffee new title
        \tCreate a new post
        coffee arukas.coffee gen
        \tGenerate website in ./deploy
        coffee arukas.coffee server
        \tStart a server on port 3000
        coffee arukas.coffee deploy
        \tdeploy website
        coffee arukas.coffee gs
        \tDo gen and server
        coffee arukas.coffee gs
        \tDo gen and deploy
        '''
