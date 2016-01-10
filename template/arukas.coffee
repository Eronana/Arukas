StaticData={{StaticData}}
config={{config}}

Array.prototype.xjoin=(x)->
    a=[this[0]]
    for i in [1...this.length]
        a.push x
        a.push this[i]
    return a

m.get=(url)->m.request({method:'GET',url})
m.a=(a,href,title)->m a,{config:m.route,href},title
WidgetSearch={
    controller:->
        return {text:m.prop('')}
    view:(ctrl)->
        m '.search',
            m 'form',
                m 'input#search-input[type=search][name=q][results=0][placeholder=Search]',{onchange: m.withAttr('value',ctrl.text),value:ctrl.text()}
}

WidgetRecent={
    controller:->
    view:()->
        m '.widget.tag',[
            m 'h3.title','Recents'
            m 'ul.entry',StaticData.Recents.map (post)->
                m 'li',m.a 'a',"/post/#{post.url}/",post.title
        ]
}

[WidgetCate,WidgetTags]=((do (x)->{
    controller:->
    view:()->
        m '.widget.tag',[
            m 'h3.title',x
            m 'ul.entry',StaticData[x].map (o)->
                lx=x.toLowerCase()
                url=StaticData["#{lx}_url"][o.name]
                m 'li',[
                    m.a 'a',"/#{lx}/#{url}/",o.name
                    m 'small',o.count
                ]
        ]
})for x in ['Categories','Tags'])
widgets=[WidgetSearch,WidgetCate,WidgetRecent,WidgetTags]
BaseView=(v,page)->
    (ctrl)->
        [
            m 'header#header.inner',[
                m '.alignleft',[
                    m 'h1',m.a 'a','/',config.title
                    m 'h2',m.a 'a','/',config.description
                ]
                m 'nav#main-nav.alignright',[
                    m 'ul',[
                        m 'li',m.a 'a','/','Home'
                        m 'li',m.a 'a','/archives','Archives'
                        m 'li',m 'a[href=/atom.xml]','RSS'
                    ]
                    m '.clearfix'
                ]
                m '.clearfix'
            ]
            m '.inner',[
                m '#main-col.alignleft',m '#wrapper',v(ctrl)
                m 'aside#sidebar.alignright',widgets
                m '.clearfix'
            ]
            m 'footer#footer.inner',[
                m '.alignleft',config.copyright
                m '.clearfix'
            ]
        ]
PostView=(post)->
    post.date=new Date(post.date)
    [
        m 'article.post',m '.post-content',[
            m 'header',[
                m '.icon'
                m "time[datetime=#{post.date.toISOString()}]",m.a 'a',"/post/#{post.url}/","#{post.date.toDateString().split(' ')[1..].join(' ')}"
                m 'h1.title',m.a 'a',"/post/#{post.url}/","#{post.title}"
            ]
            m '.entry',{config:->MathJax.Hub.Queue ["Typeset",MathJax.Hub]},m.trust post.content
            m 'footer',[
                for x in ['categories','tags'] then if post[x]?
                    m ".#{x}",(post[x].map (item)->
                        itemurl=StaticData["#{x}_url"][item]
                        m.a 'a',"/#{x}/#{itemurl}/",item
                    ).xjoin ' , '
                if post.isexcerpt then m '.alignleft',m.a 'a.more-link',"/post/#{post.url}/##more",'Read More'
                m '.clearfix'
            ]
        ]
        if post.prev? or post.next?
            m 'nav#pagination',[
                if post.prev? then m.a 'a.alignleft.prev',"/post/#{post.prev}/",'PREV'
                if post.next? then m.a 'a.alignright.next',"/post/#{post.next}/",'NEXT'
            ]
    ]


Home={
    controller:->
        m.redraw.strategy 'diff'
        page=parseInt(m.route.param('page') ? 1)
        posts=m.request({
            method:'GET'
            url:"/data/page/#{page}.json"
        })
        if page>1
            document.title="Page #{page} | #{config.title}"
        else
            document.title=config.title
        return {posts,page}
    view:BaseView (ctrl)->
        posts=ctrl.posts()
        if posts?
            [
                posts.map (post)->PostView(post)
                m 'nav#pagination',[
                    if ctrl.page>1 then m.a 'a.alignleft.prev',"/page/#{ctrl.page-1}/",'PREV'
                    m.a 'a.alignright.next',"/page/#{ctrl.page+1}/",'NEXT'
                ]
            ]
        else
            ['No this page! ',m.a 'a',"/#{x}/#{ctrl.name}/#{ctrl.page-1}/",'BACK']
}
Post={
    controller:->
        m.redraw.strategy 'diff'
        url=m.route.param 'url'
        post=m.request({
            method:'GET'
            url:"/data/post/#{url}.json"
        })
        return {post,url}
    view:BaseView (ctrl)->
        post=ctrl.post()
        if post?
            document.title="#{post.title} | #{config.title}"
            PostView post
        else
            'No this post!'
}
[Categories,Tags]=((do (x)->{
    controller:->
        m.redraw.strategy 'diff'
        nameurl=m.route.param 'name'
        name=StaticData["url_#{x[0]}"][nameurl]
        page=parseInt(m.route.param('page') ? 1)
        posts=m.request({
            method:'GET'
            url:"/data/#{x[0]}/#{nameurl}/#{page}.json"
        })
        if page>1
            document.title="Page #{page} | #{name} | #{config.title}"
        else
            document.title="#{name} | #{config.title}"
        return {posts,name,nameurl,page}
    view:BaseView (ctrl)->
        posts=ctrl.posts()
        if posts?
            [
                m "h2.archive-title.#{x[1]}",ctrl.name
                posts.map (post)->PostView(post)
                m 'nav#pagination',[
                    if ctrl.page>1 then m.a 'a.alignleft.prev',"/#{x[0]}/#{ctrl.nameurl}/#{ctrl.page-1}/",'PREV'
                    m.a 'a.alignright.next',"/#{x[0]}/#{ctrl.nameurl}/#{ctrl.page+1}/",'NEXT'
                ]
            ]
        else
            ['No this page! ',m.a 'a',"/#{x[0]}/#{ctrl.nameurl}/#{ctrl.page-1}/",'BACK']
})for x in [['categories','category'],['tags','tag']])


m.route.mode=config.route_mode
m.route document.body, '/', {
    '/':Home
    '/page/:page':Home
    '/post/:url':Post
    '/categories/:name/':Categories
    '/categories/:name/:page':Categories
    '/tags/:name/':Tags
    '/tags/:name/:page':Tags
}
